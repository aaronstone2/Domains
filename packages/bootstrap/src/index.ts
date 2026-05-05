#!/usr/bin/env -S npx tsx
// CLI orchestrator. Subcommands: install / verify / list / landmines / key.
//
// ACID enforcement:
//   - Atomicity: per-module try/catch + optional rollback hook restores
//                pre-install state on failure.
//   - Consistency: pre-flight checks before any module runs; verify() after
//                  each install confirms invariants.
//   - Isolation: lock file at /tmp/domains-bootstrap.lock prevents
//                concurrent installs from interleaving.
//   - Durability: file writes use atomic write-to-tmp + rename + fsync
//                 (lib/atomic-write.ts).
//
// DevBox modes:
//   - --snapshot-build: every required module MUST succeed; non-zero exit
//                       on any failure (for blueprint initialize: phase).
//   - --session-mode:   verify-only, no installs (for blueprint maintenance:).

import * as os from "node:os";

import { acquireLock, LockHeldError, type LockHandle } from "./lib/lock.ts";
import { HELP_TEXT, parseArgs } from "./lib/flags.ts";
import { Logger } from "./lib/log.ts";
import { findWorkspaceRoot } from "./lib/repo.ts";
import {
  configFilePath,
  loadAnthropicKey,
  mask,
  NoAnthropicKeyError,
  persistKey,
} from "./lib/secrets.ts";
import { reportPreflight, runPreflight } from "./lib/preflight.ts";
import { Runner } from "./lib/runner.ts";
import type {
  BootstrapConfig,
  InstallContext,
  InstallerModule,
  ModuleStatus,
} from "./lib/types.ts";
import { ALL_MODULES } from "./modules/registry.ts";

const logger = new Logger();

/** Global safety timeout — prevents the bootstrap from hanging forever
 * (e.g. waiting on an interactive prompt with no TTY, a stalled download,
 * or a network partition). 3 minutes is generous; a full cold install
 * typically finishes in ~90s. */
const GLOBAL_TIMEOUT_MS = 180_000;

async function main(): Promise<number> {
  const timer = setTimeout(() => {
    logger.fail(
      `TIMEOUT: bootstrap exceeded ${GLOBAL_TIMEOUT_MS / 1000}s. Aborting. ` +
        `If a module is stalled, retry it individually with --module=<id>.`,
    );
    process.exit(1);
  }, GLOBAL_TIMEOUT_MS);
  timer.unref(); // don't prevent clean exit

  const argv = process.argv.slice(2);
  let parsed;
  try {
    // Walk up to the workspace root rather than trusting process.cwd() —
    // pnpm --filter changes cwd to the package dir, breaking every path
    // check. findWorkspaceRoot() looks for pnpm-workspace.yaml.
    parsed = parseArgs(argv, { cwd: findWorkspaceRoot() });
  } catch (err) {
    logger.fail((err as Error).message);
    process.stderr.write(`\n${HELP_TEXT}`);
    return 2;
  }

  if (parsed.help || parsed.subcommand === "help") {
    process.stdout.write(HELP_TEXT);
    return 0;
  }

  // Mutually-exclusive mode flags
  if (parsed.config.snapshotBuild && parsed.config.sessionMode) {
    logger.fail("--snapshot-build and --session-mode are mutually exclusive");
    return 2;
  }

  const ctx: InstallContext = {
    config: parsed.config,
    logger,
    runner: new Runner({ dryRun: parsed.config.dryRun, logger }),
    home: os.homedir(),
  };

  switch (parsed.subcommand) {
    case "install":
      return runInstallWithLock(ctx);
    case "verify":
      return runVerify(ctx);
    case "list":
      return runList(ctx);
    case "landmines":
      return runLandmines(ctx);
    case "key":
      return runKey(ctx, argv);
  }
}

// -------------------- install (with concurrent-run lock) --------------------

async function runInstallWithLock(ctx: InstallContext): Promise<number> {
  // Session-mode short-circuits to verify (no install).
  if (ctx.config.sessionMode) {
    logger.step("--session-mode: skipping install, running verify only");
    return runVerify(ctx);
  }

  let lock: LockHandle | undefined;
  try {
    lock = await acquireLock();
    logger.info(`acquired bootstrap lock (pid ${lock.pid}, ${lock.path})`);
  } catch (err) {
    if (err instanceof LockHeldError) {
      logger.fail(err.message);
      return 1;
    }
    throw err;
  }

  try {
    return await runInstall(ctx);
  } finally {
    if (lock !== undefined) {
      await lock.release();
      logger.info("released bootstrap lock");
    }
  }
}

async function runInstall(ctx: InstallContext): Promise<number> {
  if (ctx.config.dryRun) {
    logger.step("DRY RUN — printing commands; no mutations");
  }

  // Pre-flight: do this BEFORE selecting modules so the user gets blockers
  // before waiting through 18 module gates. Skip entirely in dry-run because
  // every shell command returns synthetic empty output and the parsers see
  // garbage. Also skip if --skip-preflight (escape hatch for buggy checks).
  if (!ctx.config.dryRun && !ctx.config.skipPreflight) {
    logger.step("pre-flight checks");
    const preflightResults = await runPreflight({
      runner: ctx.runner,
      logger: ctx.logger,
      offline: ctx.config.offline,
    });
    const blockers = reportPreflight(preflightResults, logger);
    if (blockers > 0) {
      logger.fail(
        `pre-flight: ${blockers} blocker(s); aborting before modules run. ` +
          `Override with --skip-preflight if you believe this is a false positive.`,
      );
      return 2;
    }
  }

  const modules = selectModules(ctx.config);
  if (modules.length === 0) {
    logger.warn("no modules selected (check --module / --skip-module / --skip-tag)");
    return 0;
  }

  // Estimate total time: rough seconds-per-module from observed cold installs.
  const etaSec = estimateEtaSec(modules);
  logger.step(
    `installing ${modules.length} module(s) — ETA ~${formatDuration(etaSec)}` +
      (ctx.config.snapshotBuild ? " [snapshot-build: strict mode]" : "") +
      (ctx.config.onlyModules !== undefined
        ? ` (filtered: ${[...ctx.config.onlyModules].join(",")})`
        : ""),
  );

  const results: ModuleStatus[] = [];
  const startTotal = Date.now();
  let i = 0;
  for (const mod of modules) {
    i++;
    const t0 = Date.now();
    const result = await runOne(mod, ctx, i, modules.length);
    const dt = Math.round((Date.now() - t0) / 1000);
    if (dt > 1) logger.info(`  (${mod.id} took ${dt}s)`);
    results.push(result);
  }
  const totalSec = Math.round((Date.now() - startTotal) / 1000);

  printSummary(results, totalSec);

  // --snapshot-build: any non-optional failure = exit 1.
  if (ctx.config.snapshotBuild) {
    const nonOptionalFailed = results.filter(
      (r) =>
        r.kind === "failed" &&
        !["apt-optional", "apt-docker", "apt-k8s", "apt-aws", "seed-history"].includes(r.id),
    );
    if (nonOptionalFailed.length > 0) {
      logger.fail(
        `[--snapshot-build] ${nonOptionalFailed.length} required module(s) failed: ` +
          nonOptionalFailed.map((r) => r.id).join(","),
      );
      return 1;
    }
  }

  // --launch path: exec into claude after a successful install.
  if (ctx.config.launch) {
    return await execLaunch(ctx, results);
  }

  return results.some((r) => r.kind === "failed") ? 1 : 0;
}

function selectModules(config: BootstrapConfig): InstallerModule[] {
  return ALL_MODULES.filter((m) => {
    if (config.skipModules.has(m.id)) return false;
    if (config.onlyModules !== undefined && !config.onlyModules.has(m.id)) return false;
    if (m.tags !== undefined) {
      for (const t of m.tags) {
        if (config.skipTags.has(t)) return false;
      }
    }
    return true;
  });
}

async function runOne(
  mod: InstallerModule,
  ctx: InstallContext,
  idx: number,
  total: number,
): Promise<ModuleStatus> {
  const log = ctx.logger.child(`${idx}/${total} ${mod.id}`);

  if (!mod.shouldRun(ctx.config)) {
    log.skip(`shouldRun=false (gated by config flags)`);
    return { kind: "skipped", id: mod.id, reason: "shouldRun=false" };
  }

  let alreadyInstalled = false;
  try {
    alreadyInstalled = await mod.isInstalled(ctx);
  } catch (err) {
    log.warn(`isInstalled() threw: ${(err as Error).message} — proceeding to install`);
  }

  if (alreadyInstalled && !ctx.config.force) {
    log.ok("already installed (use --force to re-run)");
    const v = await safeVerify(mod, ctx);
    if (!v.ok) {
      log.warn(`verify failed: ${v.message}`);
      return { kind: "failed", id: mod.id, error: `verify after skip: ${v.message}` };
    }
    return { kind: "already-installed", id: mod.id };
  }

  log.step(mod.description);

  // ACID atomicity: capture pre-state if the module supports rollback.
  let snapshot: unknown;
  if (mod.snapshotState !== undefined) {
    try {
      snapshot = await mod.snapshotState({ ...ctx, logger: log });
    } catch (err) {
      log.warn(`snapshotState() threw: ${(err as Error).message} — rollback unavailable`);
      snapshot = undefined;
    }
  }

  try {
    await mod.install({ ...ctx, logger: log });
  } catch (err) {
    const msg = (err as Error).message;
    log.fail(`install failed: ${msg}`);
    if (mod.rollback !== undefined && snapshot !== undefined) {
      log.warn("attempting rollback...");
      try {
        await mod.rollback({ ...ctx, logger: log }, snapshot);
        log.ok("rollback complete");
      } catch (rerr) {
        log.fail(`rollback ALSO failed: ${(rerr as Error).message}`);
      }
    }
    return { kind: "failed", id: mod.id, error: msg };
  }

  const v = await safeVerify(mod, ctx);
  if (!v.ok) {
    log.fail(`verify after install failed: ${v.message}`);
    return { kind: "failed", id: mod.id, error: v.message };
  }
  log.ok(v.message);
  return { kind: "ok", id: mod.id, verifyMessage: v.message };
}

async function safeVerify(mod: InstallerModule, ctx: InstallContext): Promise<{
  readonly ok: boolean;
  readonly message: string;
}> {
  try {
    return await mod.verify(ctx);
  } catch (err) {
    return { ok: false, message: `verify threw: ${(err as Error).message}` };
  }
}

// -------------------- verify --------------------

async function runVerify(ctx: InstallContext): Promise<number> {
  const modules = selectModules(ctx.config);
  logger.step(
    `verifying ${modules.length} module(s)` + (ctx.config.sessionMode ? " [session-mode]" : ""),
  );
  const results: ModuleStatus[] = [];
  let i = 0;
  for (const mod of modules) {
    i++;
    if (!mod.shouldRun(ctx.config)) {
      results.push({ kind: "skipped", id: mod.id, reason: "shouldRun=false" });
      continue;
    }
    const log = ctx.logger.child(`${i}/${modules.length} ${mod.id}`);
    const v = await safeVerify(mod, ctx);
    if (v.ok) {
      log.ok(v.message);
      results.push({ kind: "ok", id: mod.id, verifyMessage: v.message });
    } else {
      log.fail(v.message);
      results.push({ kind: "failed", id: mod.id, error: v.message });
    }
  }
  printSummary(results, 0);
  return results.some((r) => r.kind === "failed") ? 1 : 0;
}

// -------------------- list --------------------

async function runList(ctx: InstallContext): Promise<number> {
  process.stdout.write(`\n  ${ALL_MODULES.length} modules registered (${ctx.config.repoDir})\n\n`);
  for (const mod of ALL_MODULES) {
    let state: string;
    if (!mod.shouldRun(ctx.config)) {
      state = "SKIP   (gated)";
    } else {
      try {
        state = (await mod.isInstalled(ctx)) ? "INSTALLED" : "NEEDED";
      } catch {
        state = "UNKNOWN";
      }
    }
    const tags = mod.tags !== undefined ? `[${mod.tags.join(",")}]` : "";
    process.stdout.write(
      `  ${state.padEnd(14)} ${mod.id.padEnd(22)} ${mod.description} ${tags}\n`,
    );
  }
  process.stdout.write("\n");
  return 0;
}

// -------------------- landmines --------------------

async function runLandmines(ctx: InstallContext): Promise<number> {
  const result = await ctx.runner.run("bash -lic 'bashrc-landmines'", {
    stream: true,
    allowFailure: true,
  });
  return result.code;
}

// -------------------- key (subcommand) --------------------

async function runKey(ctx: InstallContext, argv: readonly string[]): Promise<number> {
  // argv at this point still has 'key' as first positional. Find the action.
  const idx = argv.indexOf("key");
  const action = idx >= 0 ? argv[idx + 1] : undefined;

  if (action === "show") {
    try {
      const { key, source } = await loadAnthropicKey({
        fromFlag: ctx.config.anthropicKey,
        logger,
        interactive: false,
        offerPersist: false,
      });
      process.stdout.write(`\n  Anthropic key: ${mask(key)}\n  Source: ${source}\n\n`);
      return 0;
    } catch (err) {
      if (err instanceof NoAnthropicKeyError) {
        logger.fail(err.message);
        return 1;
      }
      throw err;
    }
  }

  if (action === "set" || action === undefined) {
    if (process.stdin.isTTY !== true) {
      logger.fail(
        "`key set` requires a TTY (it prompts for the key with hidden input). " +
          "For non-interactive use, pass --anthropic-key=KEY or set ANTHROPIC_API_KEY.",
      );
      return 2;
    }
    logger.step("Enter your Anthropic API key (input hidden). Ctrl-C to cancel.");
    const { key } = await loadAnthropicKey({
      fromFlag: undefined, // ignore flag here — we WANT the prompt
      logger,
      interactive: true,
      offerPersist: false,
    });
    await persistKey(key);
    logger.ok(`saved to ${configFilePath()} (chmod 600, parent dir chmod 700)`);
    logger.info(`verify with: pnpm bootstrap key show`);
    return 0;
  }

  if (action === "encrypt") {
    return await runKeyEncrypt(ctx);
  }

  logger.fail(`unknown key action: ${String(action)} (try 'set', 'show', or 'encrypt')`);
  return 2;
}

/**
 * `key encrypt` — one-time interactive command. Prompts for the API key
 * (hidden input), finds the user's SSH PUBLIC key, encrypts with age, writes
 * the result to <repo>/_secrets/anthropic-key.age. User commits + pushes.
 *
 * After this, every box with the user's SSH PRIVATE key + the `age` binary
 * gets the key for free via the anthropic-key module at install time.
 */
async function runKeyEncrypt(ctx: InstallContext): Promise<number> {
  if (process.stdin.isTTY !== true) {
    logger.fail("`key encrypt` requires a TTY for the hidden key input");
    return 2;
  }
  if (!(await ctx.runner.commandExists("age"))) {
    logger.fail(
      "age binary not found on PATH. Install with: sudo apt install age (Linux), " +
        "brew install age (macOS), or `pnpm bootstrap install --module=apt-core`.",
    );
    return 1;
  }

  // Find the SSH PUBLIC key.
  const fs = await import("node:fs/promises");
  const path = await import("node:path");
  const candidates = [
    path.join(ctx.home, ".ssh", "id_ed25519.pub"),
    path.join(ctx.home, ".ssh", "id_ecdsa.pub"),
    path.join(ctx.home, ".ssh", "id_rsa.pub"),
  ];
  let pubKey: string | undefined;
  for (const c of candidates) {
    try {
      await fs.access(c);
      pubKey = c;
      break;
    } catch {
      // try next
    }
  }
  if (pubKey === undefined) {
    logger.fail(
      "no SSH PUBLIC key found at ~/.ssh/{id_ed25519,id_ecdsa,id_rsa}.pub. " +
        "Generate one: ssh-keygen -t ed25519 -C 'your-email'",
    );
    return 1;
  }
  logger.info(`encrypting with ${pubKey}`);

  // Prompt for the key with hidden input.
  logger.step("Enter your Anthropic API key (input hidden). Ctrl-C to cancel.");
  const { key } = await loadAnthropicKey({
    fromFlag: undefined,
    logger,
    interactive: true,
    offerPersist: false,
  });

  // Encrypt with age. Use stdin → stdout so plaintext never lands on disk
  // outside the user's machine.
  const target = path.join(ctx.config.repoDir, "_secrets", "anthropic-key.age");
  await fs.mkdir(path.dirname(target), { recursive: true });

  const { spawn } = await import("node:child_process");
  const result = await new Promise<{ code: number; stderr: string }>((resolve) => {
    const child = spawn("age", ["-R", pubKey!, "-o", target], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stderr = "";
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString("utf8");
    });
    child.on("close", (code) => resolve({ code: code ?? 1, stderr }));
    child.stdin.write(key);
    child.stdin.end();
  });

  if (result.code !== 0) {
    logger.fail(`age encrypt failed (exit ${result.code}): ${result.stderr.trim()}`);
    return 1;
  }
  logger.ok(`wrote ${target}`);
  logger.info("");
  logger.info("Next steps (one-time):");
  logger.info(`  git add ${path.relative(ctx.config.repoDir, target)}`);
  logger.info(`  git commit -m 'ship encrypted anthropic key'`);
  logger.info(`  git push`);
  logger.info("");
  logger.info(
    "After that, every box with your SSH private key gets the API key zero-paste " +
      "via `./bootstrap.sh install`.",
  );
  return 0;
}

// -------------------- launch --------------------

async function execLaunch(ctx: InstallContext, results: readonly ModuleStatus[]): Promise<number> {
  const failedNonOptional = results.some(
    (r) => r.kind === "failed" && !["apt-optional", "apt-docker", "apt-k8s", "apt-aws"].includes(r.id),
  );
  if (failedNonOptional) {
    logger.warn("not launching claude — required modules failed (see summary above)");
    return 1;
  }

  // Fail-loud if no key + no TTY (user expected --launch but provided no key
  // and we'd otherwise hang on the prompt forever).
  if (
    ctx.config.anthropicKey === undefined &&
    process.env["ANTHROPIC_API_KEY"] === undefined &&
    process.stdin.isTTY !== true
  ) {
    logger.fail(
      "--launch requires an Anthropic key (no TTY available for interactive prompt). " +
        "Pass --anthropic-key=KEY or set ANTHROPIC_API_KEY env, or run `pnpm bootstrap key set` first.",
    );
    return 2;
  }

  const { key, source } = await loadAnthropicKey({
    fromFlag: ctx.config.anthropicKey,
    logger,
    interactive: true,
    // Skip persist prompt when key came from the flag — passing --anthropic-key
    // signals one-shot intent (typical for fresh-DevBox installs each session).
    // Persist offer still fires when key arrives via the interactive prompt.
    offerPersist: ctx.config.anthropicKey === undefined,
  });
  logger.step(`exec'ing claude (key from ${source}: ${mask(key)})`);

  const { spawn } = await import("node:child_process");
  spawn("claude", ["--model", "claude-opus-4-7", "--effort", "max"], {
    stdio: "inherit",
    env: { ...process.env, ANTHROPIC_API_KEY: key },
  }).on("exit", (code) => process.exit(code ?? 0));
  return await new Promise(() => {}); // never resolves; child exit kills us
}

// -------------------- summary --------------------

function printSummary(results: readonly ModuleStatus[], totalSec: number): void {
  process.stdout.write("\n=== summary ===\n");
  let ok = 0;
  let already = 0;
  let skipped = 0;
  let failed = 0;
  const failedIds: string[] = [];
  for (const r of results) {
    switch (r.kind) {
      case "ok":
        process.stdout.write(`  OK       ${r.id.padEnd(22)} ${r.verifyMessage}\n`);
        ok++;
        break;
      case "already-installed":
        process.stdout.write(`  SKIP/IN  ${r.id.padEnd(22)} already installed\n`);
        already++;
        break;
      case "skipped":
        process.stdout.write(`  SKIP     ${r.id.padEnd(22)} ${r.reason}\n`);
        skipped++;
        break;
      case "failed":
        process.stdout.write(`  FAIL     ${r.id.padEnd(22)} ${r.error}\n`);
        failed++;
        failedIds.push(r.id);
        break;
    }
  }
  const totalLine = totalSec > 0 ? ` (took ${formatDuration(totalSec)})` : "";
  process.stdout.write(
    `\n  ${ok} ok | ${already} already | ${skipped} skipped | ${failed} failed${totalLine}\n`,
  );
  if (failed > 0) {
    process.stdout.write(`\n  Retry failed module(s) with:\n`);
    process.stdout.write(`    pnpm bootstrap install --module=${failedIds.join(",")}\n`);
  }
  process.stdout.write("\n");
}

// -------------------- helpers --------------------

const ETA_PER_MODULE_SEC: Readonly<Record<string, number>> = {
  "apt-core": 25,
  "apt-optional": 60,
  "apt-docker": 30,
  "apt-k8s": 10,
  "apt-aws": 30,
  node: 20,
  pnpm: 5,
  "claude-code": 15,
  eza: 15,
  zoxide: 10,
  atuin: 15,
  "seed-history": 3,
  "docker-completion": 1,
  bashrc: 1,
  "pnpm-install": 30,
  "knowledge-graph": 5,
  "verify-harness": 3,
  "verify-mcp": 5,
};

function estimateEtaSec(modules: readonly InstallerModule[]): number {
  return modules.reduce((sum, m) => sum + (ETA_PER_MODULE_SEC[m.id] ?? 5), 0);
}

function formatDuration(sec: number): string {
  if (sec < 60) return `${sec}s`;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return s === 0 ? `${m}m` : `${m}m${s}s`;
}

// -------------------- entry --------------------

main().then(
  (code) => process.exit(code),
  (err) => {
    logger.fail(`uncaught: ${(err as Error).stack ?? err}`);
    process.exit(1);
  },
);
