// Pre-flight checks. Run BEFORE any module starts. If any blocker fails,
// abort with a clear message rather than failing 30 seconds in with a
// confusing error from `apt-get` or `pnpm install`.
//
// Categories of check:
//   - sudo available (or running as root)
//   - network reachable (DNS resolves, deb.nodesource.com pingable)
//   - disk space sufficient (>500MB free on / and /tmp)
//   - PATH sanity (no aliases shadowing standard tools)
//
// Returns a list of failures; caller decides whether to abort.

import * as fs from "node:fs/promises";

import type { Logger } from "./log.ts";
import type { Runner } from "./runner.ts";

export interface PreflightResult {
  readonly id: string;
  readonly description: string;
  readonly ok: boolean;
  readonly message: string;
  readonly severity: "blocker" | "warning";
}

export interface PreflightOptions {
  readonly runner: Runner;
  readonly logger: Logger;
  /** Skip network checks (offline install). */
  readonly offline?: boolean;
  /** Don't actually need sudo — running modules that don't need root. */
  readonly skipSudo?: boolean;
}

export async function runPreflight(opts: PreflightOptions): Promise<readonly PreflightResult[]> {
  const checks: Array<Promise<PreflightResult>> = [
    checkPlatform(),
    checkDiskSpace(opts.runner, "/", 500),
    checkDiskSpace(opts.runner, "/tmp", 100),
    checkBashSanity(opts.runner),
  ];
  if (opts.skipSudo !== true) checks.push(checkSudo(opts.runner));
  if (opts.offline !== true) checks.push(checkNetwork(opts.runner));

  return Promise.all(checks);
}

/** Print results; return blocker count. */
export function reportPreflight(results: readonly PreflightResult[], logger: Logger): number {
  let blockers = 0;
  for (const r of results) {
    if (r.ok) {
      logger.ok(`preflight: ${r.description} — ${r.message}`);
    } else if (r.severity === "warning") {
      logger.warn(`preflight: ${r.description} — ${r.message}`);
    } else {
      logger.fail(`preflight: ${r.description} — ${r.message}`);
      blockers++;
    }
  }
  return blockers;
}

// -- individual checks --

async function checkPlatform(): Promise<PreflightResult> {
  if (process.platform === "linux") {
    return {
      id: "platform",
      description: "platform is Linux",
      ok: true,
      message: process.platform,
      severity: "blocker",
    };
  }
  return {
    id: "platform",
    description: "platform is Linux",
    ok: false,
    message: `running on ${process.platform}; many modules will be SKIP gated`,
    severity: "warning",
  };
}

async function checkSudo(runner: Runner): Promise<PreflightResult> {
  // Running as root? Then no sudo needed.
  if (process.getuid?.() === 0) {
    return {
      id: "sudo",
      description: "sudo / root access available",
      ok: true,
      message: "running as root",
      severity: "blocker",
    };
  }
  // sudo -nv = non-interactive validate. Returns 0 if cached, non-zero if a password would be needed.
  const result = await runner.run("sudo -nv 2>&1", { allowFailure: true });
  if (result.code === 0) {
    return {
      id: "sudo",
      description: "sudo / root access available",
      ok: true,
      message: "sudo cached or NOPASSWD",
      severity: "blocker",
    };
  }
  return {
    id: "sudo",
    description: "sudo / root access available",
    ok: false,
    message:
      "sudo will prompt for password during install. " +
      "Consider running `sudo -v` first, OR run the bootstrap as root.",
    severity: "warning", // NOT a blocker — apt-get will prompt and might still succeed
  };
}

async function checkDiskSpace(
  runner: Runner,
  mountpoint: string,
  minMb: number,
): Promise<PreflightResult> {
  const id = `disk-${mountpoint}`;
  const desc = `at least ${minMb} MB free on ${mountpoint}`;
  const result = await runner.run(`df -m --output=avail ${mountpoint} | tail -1`, {
    allowFailure: true,
  });
  if (result.code !== 0) {
    return {
      id,
      description: desc,
      ok: false,
      message: `df failed: ${result.stderr.trim()}`,
      severity: "warning",
    };
  }
  const avail = Number.parseInt(result.stdout.trim(), 10);
  if (!Number.isFinite(avail)) {
    return {
      id,
      description: desc,
      ok: false,
      message: `unparseable df output: ${result.stdout.trim()}`,
      severity: "warning",
    };
  }
  if (avail < minMb) {
    return {
      id,
      description: desc,
      ok: false,
      message: `only ${avail} MB free`,
      severity: "blocker",
    };
  }
  return {
    id,
    description: desc,
    ok: true,
    message: `${avail} MB free`,
    severity: "blocker",
  };
}

async function checkNetwork(runner: Runner): Promise<PreflightResult> {
  // We need: DNS resolution + outbound HTTPS to deb.nodesource.com (apt repo)
  // and registry.npmjs.org (pnpm). Use one ping-equivalent that exercises DNS
  // + TCP-handshake.
  const result = await runner.run(
    "curl -fsSL --max-time 5 -o /dev/null -w '%{http_code}' https://registry.npmjs.org/-/ping",
    { allowFailure: true },
  );
  if (result.code === 0 && result.stdout.startsWith("2")) {
    return {
      id: "network",
      description: "outbound HTTPS to npm registry",
      ok: true,
      message: `HTTP ${result.stdout}`,
      severity: "blocker",
    };
  }
  return {
    id: "network",
    description: "outbound HTTPS to npm registry",
    ok: false,
    message: "registry.npmjs.org unreachable. Use --offline if you've pre-cached deps.",
    severity: "blocker",
  };
}

async function checkBashSanity(runner: Runner): Promise<PreflightResult> {
  // Standard tools resolve to real binaries. Use `command -v` per-binary
  // (POSIX, works in dash) instead of `type -P ...` (bash-only — fails on
  // /bin/sh which Node's exec uses). The legacy version produced false
  // 5/4 failures on Debian/Ubuntu derivatives where /bin/sh is dash.
  const required = ["grep", "sed", "awk", "curl"];
  const missing: string[] = [];
  for (const bin of required) {
    if (!(await runner.commandExists(bin))) missing.push(bin);
  }
  if (missing.length === 0) {
    return {
      id: "bash-sanity",
      description: `standard tools (${required.join("/")}) on PATH`,
      ok: true,
      message: `${required.length}/${required.length} resolved`,
      severity: "blocker",
    };
  }
  return {
    id: "bash-sanity",
    description: `standard tools (${required.join("/")}) on PATH`,
    ok: false,
    message: `missing: ${missing.join(", ")} — install will fail without these`,
    severity: "blocker",
  };
}

// silence unused-import lint noise
void fs;
