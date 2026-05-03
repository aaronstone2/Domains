import * as p from "@clack/prompts";
import { spawn, spawnSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import { openDb, DOMAINS } from "../db.ts";

const here: string = dirname(fileURLToPath(import.meta.url));
const BUNDLES_DIR: string = join(here, "..", "..", "bundles");

interface BundleCommand {
  description: string;
  command: string;
  timeout_ms?: number;
  allow_failure?: boolean;
  redact?: string[];
}

interface Bundle {
  name: string;
  description: string;
  platform_hint: string;
  commands: BundleCommand[];
}

interface CommandResult {
  description: string;
  command: string;
  exit_code: number;
  duration_ms: number;
  output: string;
  timed_out: boolean;
  not_available: boolean;
}

const DEFAULT_REDACTIONS: ReadonlyArray<RegExp> = [
  /AKIA[0-9A-Z]{16}/g,
  /ghp_[A-Za-z0-9]{36}/g,
  /eyJ[A-Za-z0-9_=-]+\.eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+/g,
  /(?<=password[\"'\s:=]+)[A-Za-z0-9!@#$%^&*+/=._-]{8,}/gi,
  /(?<=token[\"'\s:=]+)[A-Za-z0-9._-]{20,}/gi,
  /(?<=api[_-]?key[\"'\s:=]+)[A-Za-z0-9._-]{20,}/gi,
];

function redact(text: string, extra: readonly string[] = []): string {
  let out = text;
  for (const pattern of DEFAULT_REDACTIONS) {
    out = out.replace(pattern, "<REDACTED>");
  }
  for (const userPattern of extra) {
    try {
      const re = new RegExp(userPattern, "g");
      out = out.replace(re, "<REDACTED>");
    } catch {
      // bad user pattern, skip
    }
  }
  return out;
}

function listBundles(): Array<{ id: string; bundle: Bundle }> {
  const files = readdirSync(BUNDLES_DIR).filter((f) => f.endsWith(".json"));
  return files.map((f) => {
    const content = readFileSync(join(BUNDLES_DIR, f), "utf8");
    const bundle = JSON.parse(content) as Bundle;
    return { id: basename(f, ".json"), bundle };
  });
}

function loadBundle(id: string): Bundle | null {
  try {
    const content = readFileSync(join(BUNDLES_DIR, `${id}.json`), "utf8");
    return JSON.parse(content) as Bundle;
  } catch {
    return null;
  }
}

const isWindows: boolean = process.platform === "win32";

interface ShellChoice {
  cmd: string;
  args: (script: string) => string[];
  label: string;
}

let cachedShell: ShellChoice | null = null;

function detectShell(): ShellChoice {
  if (cachedShell) return cachedShell;
  if (!isWindows) {
    cachedShell = { cmd: "/bin/sh", args: (s) => ["-c", s], label: "sh" };
    return cachedShell;
  }
  // On Windows, prefer (in order): WSL bash, Git Bash, fallback to cmd.exe
  const candidates: Array<[string, string[], string]> = [
    ["wsl.exe", ["bash", "-c"], "wsl"],
    ["bash.exe", ["-c"], "bash"],
    ["cmd.exe", ["/c"], "cmd"],
  ];
  for (const [bin, prefix, label] of candidates) {
    try {
      const which = spawnSync(isWindows ? "where" : "which", [bin], {
        encoding: "utf8",
      });
      if (which.status === 0) {
        cachedShell = {
          cmd: bin,
          args: (s) => [...prefix, s],
          label,
        };
        return cachedShell;
      }
    } catch {
      // try next
    }
  }
  cachedShell = { cmd: "cmd.exe", args: (s) => ["/c", s], label: "cmd" };
  return cachedShell;
}

async function runCommand(cmd: BundleCommand): Promise<CommandResult> {
  const timeoutMs = cmd.timeout_ms ?? 5000;
  const start = Date.now();
  const shell = detectShell();

  return new Promise((resolve) => {
    const child = spawn(shell.cmd, shell.args(cmd.command), {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let settled = false;

    const timer = setTimeout(() => {
      timedOut = true;
      try {
        child.kill("SIGKILL");
      } catch {
        // child may have already exited
      }
    }, timeoutMs);

    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString("utf8");
    });

    const finish = (exitCode: number, notAvailable: boolean): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      const combined = stdout + (stderr ? `\n[stderr]\n${stderr}` : "");
      const truncated =
        combined.length > 8000
          ? combined.slice(0, 8000) + "\n... (output truncated)"
          : combined;
      resolve({
        description: cmd.description,
        command: cmd.command,
        exit_code: exitCode,
        duration_ms: Date.now() - start,
        output: redact(truncated, cmd.redact ?? []),
        timed_out: timedOut,
        not_available: notAvailable,
      });
    };

    child.on("error", (err: NodeJS.ErrnoException) => {
      finish(127, err.code === "ENOENT");
    });
    child.on("exit", (code) => {
      finish(code ?? -1, false);
    });
  });
}

function formatResult(r: CommandResult): string {
  const lines: string[] = [];
  lines.push(`### ${r.description}`);
  lines.push("");
  lines.push("```");
  lines.push(r.command);
  lines.push("```");
  if (r.timed_out) {
    lines.push(`_(timed out after ${r.duration_ms}ms)_`);
  } else if (r.not_available) {
    lines.push(`_(command not available on this system)_`);
  } else {
    lines.push(`_exit=${r.exit_code} took=${r.duration_ms}ms_`);
  }
  lines.push("");
  if (!r.timed_out && !r.not_available) {
    const out = r.output.trim();
    if (out.length > 0) {
      lines.push("```");
      lines.push(out);
      lines.push("```");
    } else {
      lines.push("_(no output)_");
    }
  }
  lines.push("");
  return lines.join("\n");
}

function platformHintMatches(hint: string): boolean {
  if (hint === "cross-platform") return true;
  if (hint === "windows-only") return isWindows;
  if (hint === "linux-or-wsl") return !isWindows; // WSL detection skipped for simplicity
  if (hint === "kubectl-only" || hint === "docker-only") return true;
  return true;
}

async function fmToBundle(fmId: string): Promise<Bundle | null> {
  const escaped = fmId.replace(/'/g, "''");
  const db = await openDb();
  try {
    const sql = DOMAINS.map(
      (d) => `SELECT '${d}' AS domain, * FROM ${d}.failure_modes WHERE id = '${escaped}'`,
    ).join("\nUNION ALL\n");
    interface Row {
      domain: string;
      id: string;
      symptom: string;
      diagnostic_steps:
        | Array<{ step: number; action: string; command: string | null }>
        | null;
    }
    const rows = (await db.all(sql)) as unknown as Row[];
    if (rows.length === 0) return null;
    const fm = rows[0]!;
    const commands: BundleCommand[] = (fm.diagnostic_steps ?? [])
      .filter((s): s is { step: number; action: string; command: string } =>
        typeof s.command === "string" && s.command.trim().length > 0 && !s.command.trim().startsWith("#"),
      )
      .map((s) => ({
        description: `Step ${s.step}: ${s.action}`,
        command: s.command,
        timeout_ms: 8000,
        allow_failure: true,
      }));
    return {
      name: `from-fm:${fm.id}`,
      description: `Diagnostic steps synthesized from ${fm.id} (${fm.symptom})`,
      platform_hint: "cross-platform",
      commands,
    };
  } finally {
    await db.close();
  }
}

interface ParsedArgs {
  list: boolean;
  bundleId: string | null;
  fromFm: string | null;
  outputFile: string | null;
}

function parseArgs(args: string[]): ParsedArgs {
  let list = false;
  let bundleId: string | null = null;
  let fromFm: string | null = null;
  let outputFile: string | null = null;
  for (let i = 0; i < args.length; i++) {
    const a = args[i]!;
    if (a === "--list") list = true;
    else if (a === "--from-fm") fromFm = args[++i] ?? null;
    else if (a === "--output" || a === "-o") outputFile = args[++i] ?? null;
    else if (!a.startsWith("--")) bundleId = a;
  }
  return { list, bundleId, fromFm, outputFile };
}

export async function captureCmd(args: string[]): Promise<void> {
  const { list, bundleId, fromFm, outputFile } = parseArgs(args);

  if (list) {
    const all = listBundles();
    p.log.info("Available capture bundles:");
    for (const { id, bundle } of all) {
      console.log(`  ${id.padEnd(20)} [${bundle.platform_hint.padEnd(14)}] ${bundle.description}`);
    }
    console.log("\nUsage:");
    console.log("  pnpm harness capture <bundle>");
    console.log("  pnpm harness capture --from-fm <failure-mode-id>");
    console.log("  pnpm harness capture <bundle> --output snapshot.md");
    return;
  }

  let bundle: Bundle | null = null;
  if (fromFm) {
    bundle = await fmToBundle(fromFm);
    if (!bundle) {
      p.log.error(`failure mode not found: ${fromFm}`);
      process.exit(2);
    }
    if (bundle.commands.length === 0) {
      p.log.warn(`fm ${fromFm} has no runnable diagnostic_steps (only commented placeholders)`);
      return;
    }
  } else if (bundleId) {
    bundle = loadBundle(bundleId);
    if (!bundle) {
      p.log.error(`bundle not found: ${bundleId}`);
      p.log.info("Run `pnpm harness capture --list` to see available bundles.");
      process.exit(2);
    }
  } else {
    p.log.error("usage: harness capture <bundle> | --from-fm <id> | --list");
    process.exit(1);
  }

  const platformOk = platformHintMatches(bundle.platform_hint);
  const sections: string[] = [];
  sections.push(`# Capture: ${bundle.name}`);
  sections.push("");
  sections.push(`> ${bundle.description}`);
  sections.push("");
  const shell = detectShell();
  sections.push(
    `_Captured at ${new Date().toISOString()} on ${process.platform}/${process.arch} via ${shell.label}._`,
  );
  if (!platformOk) {
    sections.push("");
    sections.push(
      `⚠️ This bundle hints platform=\`${bundle.platform_hint}\` but host is \`${process.platform}\`. Some commands will likely fail or be unavailable.`,
    );
  }
  sections.push("");

  p.log.info(`Running ${bundle.commands.length} commands from "${bundle.name}"...`);

  for (let i = 0; i < bundle.commands.length; i++) {
    const cmd = bundle.commands[i]!;
    process.stdout.write(`  [${i + 1}/${bundle.commands.length}] ${cmd.description}... `);
    const result = await runCommand(cmd);
    if (result.timed_out) {
      console.log("TIMEOUT");
    } else if (result.not_available) {
      console.log("N/A");
    } else {
      console.log(`exit=${result.exit_code} (${result.duration_ms}ms)`);
    }
    sections.push(formatResult(result));
  }

  const blob = sections.join("\n");

  if (outputFile) {
    writeFileSync(outputFile, blob, "utf8");
    p.log.success(`Wrote ${blob.length} bytes to ${outputFile}`);
  } else {
    console.log("\n" + "=".repeat(60));
    console.log(blob);
  }
}
