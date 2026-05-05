#!/usr/bin/env -S npx tsx
import { createRequire as __createRequire } from 'module'; const require = __createRequire(import.meta.url);
var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __esm = (fn, res) => function() {
  return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
};
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: !0 });
};

// src/lib/atomic-write.ts
var atomic_write_exports = {};
__export(atomic_write_exports, {
  atomicWrite: () => atomicWrite,
  atomicWriteIfChanged: () => atomicWriteIfChanged
});
import * as fs3 from "node:fs/promises";
import * as path4 from "node:path";
import * as crypto from "node:crypto";
async function atomicWrite(targetPath, content, opts = {}) {
  let mode = opts.mode ?? 420, dir = path4.dirname(targetPath);
  await fs3.mkdir(dir, { recursive: !0 });
  let tmpName = `.${path4.basename(targetPath)}.${process.pid}.${crypto.randomBytes(6).toString("hex")}.tmp`, tmpPath = path4.join(dir, tmpName), fh = await fs3.open(tmpPath, "w", mode);
  try {
    await fh.writeFile(content), opts.fsync !== !1 && await fh.sync(), await fh.chmod(mode);
  } finally {
    await fh.close();
  }
  if (await fs3.rename(tmpPath, targetPath), opts.fsync !== !1)
    try {
      let dh = await fs3.open(dir, "r");
      try {
        await dh.sync();
      } finally {
        await dh.close();
      }
    } catch {
    }
}
async function atomicWriteIfChanged(targetPath, content, opts = {}) {
  let existing;
  try {
    existing = await fs3.readFile(targetPath, "utf8");
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }
  return existing === content ? !1 : (await atomicWrite(targetPath, content, opts), !0);
}
var init_atomic_write = __esm({
  "src/lib/atomic-write.ts"() {
    "use strict";
  }
});

// src/index.ts
import * as os4 from "node:os";

// src/lib/lock.ts
import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
var LOCK_PATH = path.join(os.tmpdir(), "domains-bootstrap.lock"), LockHeldError = class extends Error {
  holderPid;
  constructor(pid) {
    super(
      `Another bootstrap is running (pid ${pid}, lock at ${LOCK_PATH}). If you're sure that pid is not actually running:
  rm ${LOCK_PATH}
Then re-run.`
    ), this.name = "LockHeldError", this.holderPid = pid;
  }
};
async function acquireLock() {
  let myPid = process.pid, writtenByUs = !1;
  try {
    await fs.writeFile(LOCK_PATH, String(myPid), { flag: "wx" }), writtenByUs = !0;
  } catch (err) {
    if (err.code !== "EEXIST") throw err;
  }
  if (!writtenByUs) {
    let content = (await fs.readFile(LOCK_PATH, "utf8")).trim(), otherPid = Number.parseInt(content, 10);
    if (Number.isFinite(otherPid) && otherPid > 0 && isPidAlive(otherPid))
      throw new LockHeldError(otherPid);
    await fs.writeFile(LOCK_PATH, String(myPid));
  }
  return {
    pid: myPid,
    path: LOCK_PATH,
    release: async () => {
      try {
        let content = (await fs.readFile(LOCK_PATH, "utf8")).trim();
        Number.parseInt(content, 10) === myPid && await fs.unlink(LOCK_PATH);
      } catch {
      }
    }
  };
}
function isPidAlive(pid) {
  try {
    return process.kill(pid, 0), !0;
  } catch (err) {
    return err.code === "EPERM";
  }
}

// src/lib/flags.ts
import * as path2 from "node:path";
function parseArgs(argv, opts) {
  argv = argv.filter((a) => a !== "--");
  let subcommand = "install", dryRun = !1, noClaude = !1, noShellConfig = !1, minimal = !1, withDocker = !1, withK8s = !1, withAws = !1, launch = !1, anthropicKey, repoDir = opts.cwd, onlyModules, skipModules = /* @__PURE__ */ new Set(), skipTags = /* @__PURE__ */ new Set(), force = !1, help = !1, snapshotBuild = !1, sessionMode = !1, offline = !1, skipPreflight = !1, i = 0, first = argv[0];
  for (first !== void 0 && !first.startsWith("-") && (first === "install" || first === "verify" || first === "list" || first === "landmines" || first === "key" || first === "help") && (subcommand = first, i = 1); i < argv.length; i++) {
    let arg = argv[i];
    if (arg === void 0) break;
    let [key, inlineValue] = splitFlag(arg);
    switch (key) {
      case "--dry-run":
        dryRun = !0;
        break;
      case "--no-claude":
        noClaude = !0;
        break;
      case "--no-shell-config":
        noShellConfig = !0;
        break;
      case "--minimal":
        minimal = !0;
        break;
      case "--with-docker":
        withDocker = !0;
        break;
      case "--with-k8s":
        withK8s = !0;
        break;
      case "--with-aws":
        withAws = !0;
        break;
      case "--launch":
        launch = !0;
        break;
      case "--force":
        force = !0;
        break;
      case "--snapshot-build":
        snapshotBuild = !0;
        break;
      case "--session-mode":
        sessionMode = !0;
        break;
      case "--offline":
        offline = !0;
        break;
      case "--skip-preflight":
        skipPreflight = !0;
        break;
      case "--skip-tag": {
        let tags = (inlineValue ?? takeNext(argv, i++, "--skip-tag")).split(",").filter((s) => s !== "");
        for (let t of tags) skipTags.add(t);
        break;
      }
      case "--help":
      case "-h":
        help = !0;
        break;
      case "--anthropic-key":
        anthropicKey = inlineValue ?? takeNext(argv, i++, "--anthropic-key");
        break;
      case "--repo":
        repoDir = path2.resolve(inlineValue ?? takeNext(argv, i++, "--repo"));
        break;
      case "--module": {
        let ids = (inlineValue ?? takeNext(argv, i++, "--module")).split(",").filter((s) => s !== "");
        onlyModules === void 0 && (onlyModules = /* @__PURE__ */ new Set());
        for (let id of ids) onlyModules.add(id);
        break;
      }
      case "--skip-module": {
        let ids = (inlineValue ?? takeNext(argv, i++, "--skip-module")).split(",").filter((s) => s !== "");
        for (let id of ids) skipModules.add(id);
        break;
      }
      default:
        if (arg.startsWith("-"))
          throw new Error(`Unknown flag: ${arg}`);
        break;
    }
  }
  return { subcommand, config: {
    repoDir,
    dryRun,
    noClaude,
    noShellConfig,
    minimal,
    withDocker,
    withK8s,
    withAws,
    anthropicKey,
    launch,
    onlyModules,
    skipModules,
    force,
    snapshotBuild,
    sessionMode,
    offline,
    skipPreflight,
    skipTags
  }, help };
}
function splitFlag(arg) {
  let eq = arg.indexOf("=");
  return eq < 0 ? [arg, void 0] : [arg.slice(0, eq), arg.slice(eq + 1)];
}
function takeNext(argv, i, name) {
  let next = argv[i + 1];
  if (next === void 0 || next.startsWith("-"))
    throw new Error(`${name} requires a value`);
  return next;
}
var HELP_TEXT = `domains-bootstrap \u2014 modular DevBox installer

Usage:
  pnpm bootstrap [SUBCOMMAND] [FLAGS]

Subcommands:
  install      Install all (or filtered) modules. (default)
  verify       Run post-install verification on all modules; no install.
  list         Show every module + current state (installed/needed/skip).
  landmines    Run the bashrc-landmines safety check only.
  key set      Set/replace Anthropic key in ~/.config/domains/anthropic-key (chmod 600).
  key show     Show the resolved key source + masked value.
  key encrypt  ONE-TIME: encrypt the API key with your SSH public key, write to
               _secrets/anthropic-key.age. Commit + push so any box with your
               SSH private key gets the key zero-paste at install time.
  help         Show this help.

DevBox modes:
  --snapshot-build          Strict mode for blueprint 'initialize:' (any
                            non-optional module failure = exit 1; no warnings).
  --session-mode            Verify-only, no installs. For blueprint 'maintenance:'
                            and any session-start sanity check.

Filter:
  --module=ID[,ID...]       Run only these modules.
  --skip-module=ID[,ID...]  Skip these modules.
  --skip-tag=TAG[,TAG...]   Skip modules with these tags (e.g. productivity).
  --force                   Re-run modules even if already installed.

Optional groups:
  --with-docker             Install docker.io + plugins.
  --with-k8s                Install kubectl.
  --with-aws                Install aws-cli v2.

Skips:
  --no-claude               Skip @anthropic-ai/claude-code install.
  --no-shell-config         Skip bashrc edit.
  --minimal                 Skip optional heavy apt packages (eBPF, perf).
  --offline                 Skip network preflight + curl-based installers.

Launch + secrets:
  --launch                  Exec 'claude' after a successful install.
  --anthropic-key=KEY       Anthropic API key. Falls back to:
                              1) --anthropic-key flag
                              2) $ANTHROPIC_API_KEY env var
                              3) ~/.config/domains/anthropic-key (chmod 600)
                              4) interactive hidden prompt (TTY only)
                              5) fail loud
                            Recommended: set as a Devin Secret named
                            ANTHROPIC_API_KEY, OR use \`pnpm bootstrap key set\`.

Misc:
  --repo=PATH               Path to the domains repo (default: cwd).
  --dry-run                 Print commands, change nothing.
  --help, -h                Show this help.

Retry pattern: if module 'atuin' fails mid-install:
  pnpm bootstrap install --module=atuin

Examples:
  # DevBox blueprint initialize:
  pnpm bootstrap install --snapshot-build --with-docker

  # DevBox blueprint maintenance:
  pnpm bootstrap verify --session-mode

  # Local install with launch:
  pnpm bootstrap install --launch

  # Skip productivity tools (eza/zoxide/atuin) for a leaner install:
  pnpm bootstrap install --skip-tag=productivity

  # Provision the local key file:
  pnpm bootstrap key set
`;

// src/lib/log.ts
var ANSI = {
  reset: "\x1B[0m",
  bold: "\x1B[1m",
  dim: "\x1B[2m",
  green: "\x1B[0;32m",
  yellow: "\x1B[0;33m",
  red: "\x1B[0;31m",
  blue: "\x1B[0;34m",
  cyan: "\x1B[0;36m"
}, stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*m/g, ""), Logger = class _Logger {
  useColor;
  prefix;
  constructor(opts = {}) {
    this.useColor = opts.useColor ?? process.stdout.isTTY === !0, this.prefix = opts.prefix ?? "";
  }
  fmt(color, s) {
    return this.useColor ? `${color}${s}${ANSI.reset}` : stripAnsi(s);
  }
  /** Section heading — used for major phases (e.g. "installing tools"). */
  step(msg) {
    process.stdout.write(`
${this.fmt(ANSI.cyan + ANSI.bold, "==>")} ${this.prefix}${msg}
`);
  }
  /** Success — used for completed sub-tasks. */
  ok(msg) {
    process.stdout.write(`  ${this.fmt(ANSI.green, "ok")}    ${this.prefix}${msg}
`);
  }
  /** Warning — non-fatal issue; install continues. */
  warn(msg) {
    process.stdout.write(`  ${this.fmt(ANSI.yellow, "warn")}  ${this.prefix}${msg}
`);
  }
  /** Skip — module decided not to run (e.g. --with-docker not set). */
  skip(msg) {
    process.stdout.write(`  ${this.fmt(ANSI.dim, "skip")}  ${this.prefix}${msg}
`);
  }
  /** Failure — write to stderr; install continues to next module. */
  fail(msg) {
    process.stderr.write(`  ${this.fmt(ANSI.red + ANSI.bold, "FAIL")}  ${this.prefix}${msg}
`);
  }
  /** Info — same channel as step but smaller. */
  info(msg) {
    process.stdout.write(`  ${this.fmt(ANSI.blue, "info")}  ${this.prefix}${msg}
`);
  }
  /** Raw — no formatting, no prefix. Used for pass-through of subprocess output. */
  raw(msg) {
    process.stdout.write(msg);
  }
  /** Returns a child logger that prepends `[childPrefix] ` to every line. */
  child(childPrefix) {
    return new _Logger({
      useColor: this.useColor,
      prefix: this.prefix === "" ? `[${childPrefix}] ` : `${this.prefix}[${childPrefix}] `
    });
  }
}, defaultLogger = new Logger();

// src/lib/repo.ts
import * as fs2 from "node:fs";
import * as path3 from "node:path";
var WORKSPACE_MARKERS = [
  "pnpm-workspace.yaml",
  // .git is the last-resort marker; we only fall through to it if the
  // pnpm-workspace.yaml is somehow absent.
  ".git"
];
function findWorkspaceRoot(startDir = process.cwd()) {
  let current = path3.resolve(startDir), root = path3.parse(current).root;
  for (; current !== root; ) {
    for (let marker of WORKSPACE_MARKERS) {
      let candidate = path3.join(current, marker);
      if (fs2.existsSync(candidate)) return current;
    }
    let parent = path3.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return path3.resolve(startDir);
}

// src/lib/secrets.ts
import * as fs4 from "node:fs/promises";
import * as path5 from "node:path";
import * as os2 from "node:os";
import * as readline from "node:readline";
var NoAnthropicKeyError = class extends Error {
  constructor() {
    super(
      `No Anthropic API key found. Provide one of:
  - flag:  --anthropic-key=sk-ant-...
  - env:   export ANTHROPIC_API_KEY=sk-ant-...
  - file:  ~/.config/domains/anthropic-key (chmod 600)
  - or run interactively (TTY required) and the bootstrap will prompt.`
    ), this.name = "NoAnthropicKeyError";
  }
}, InvalidAnthropicKeyError = class extends Error {
  constructor(reason, maskedKey) {
    let got = maskedKey !== void 0 ? ` Got: ${maskedKey}.` : "";
    super(`Anthropic key looks invalid: ${reason}.${got}`), this.name = "InvalidAnthropicKeyError";
  }
};
function diagnosticMask(key) {
  if (key.length === 0) return "(empty input)";
  if (key.length < 4) return `(${key.length} chars: "${key}")`;
  let head = key.slice(0, 4);
  return `(${key.length} chars starting "${head}\u2026")`;
}
var KEY_PATH = path5.join(os2.homedir(), ".config", "domains", "anthropic-key");
async function loadAnthropicKey(opts) {
  if (opts.fromFlag !== void 0) {
    let trimmed = opts.fromFlag.trim();
    if (trimmed !== "")
      return validateKey(trimmed), opts.offerPersist === !0 && await maybeOfferPersist(trimmed, "flag", opts.logger), { key: trimmed, source: "flag" };
  }
  let fromEnvRaw = process.env.ANTHROPIC_API_KEY;
  if (fromEnvRaw !== void 0) {
    let fromEnv = fromEnvRaw.trim();
    if (fromEnv !== "")
      return validateKey(fromEnv), opts.offerPersist === !0 && await maybeOfferPersist(fromEnv, "env", opts.logger), { key: fromEnv, source: "env" };
  }
  let fromFile = await readFromConfigFile();
  if (fromFile !== void 0)
    return validateKey(fromFile), { key: fromFile, source: "file" };
  if (opts.interactive !== !1 && process.stdin.isTTY === !0)
    for (let attempt = 1; attempt <= 3; attempt++) {
      opts.logger.info(
        attempt === 1 ? "No key found in flag/env/file. Prompting (input hidden, paste from your password manager)..." : `Attempt ${attempt}/3 \u2014 paste again (Ctrl-C to abort)`
      );
      let typed = (await promptHidden("Anthropic API key: ")).trim();
      if (typed === "") {
        opts.logger.warn("Got empty input. Try again.");
        continue;
      }
      try {
        return validateKey(typed), opts.offerPersist === !0 && await maybeOfferPersist(typed, "prompt", opts.logger), { key: typed, source: "prompt" };
      } catch (err) {
        if (err instanceof InvalidAnthropicKeyError && (opts.logger.warn(err.message), attempt < 3))
          continue;
        throw err;
      }
    }
  throw new NoAnthropicKeyError();
}
function mask(key) {
  return key.length < 8 ? "***" : `${key.slice(0, 7)}\u2026${key.slice(-4)}`;
}
async function persistKey(key) {
  let { atomicWrite: atomicWrite2 } = await Promise.resolve().then(() => (init_atomic_write(), atomic_write_exports)), dir = path5.dirname(KEY_PATH);
  await fs4.mkdir(dir, { recursive: !0, mode: 448 }), await fs4.chmod(dir, 448).catch(() => {
  }), await atomicWrite2(KEY_PATH, `${key}
`, { mode: 384 });
}
async function readFromConfigFile() {
  try {
    let stat6 = await fs4.stat(KEY_PATH);
    if ((stat6.mode & 63) !== 0)
      throw new Error(
        `~/.config/domains/anthropic-key has unsafe permissions (${(stat6.mode & 511).toString(8)}). Run: chmod 600 ~/.config/domains/anthropic-key`
      );
    let trimmed = (await fs4.readFile(KEY_PATH, "utf8")).trim();
    return trimmed === "" ? void 0 : trimmed;
  } catch (err) {
    if (err.code === "ENOENT") return;
    throw err;
  }
}
function configFilePath() {
  return KEY_PATH;
}
function validateKey(key) {
  if (!key.startsWith("sk-ant-"))
    throw new InvalidAnthropicKeyError("missing sk-ant- prefix", diagnosticMask(key));
  if (key.length < 30)
    throw new InvalidAnthropicKeyError("too short to be a real key", diagnosticMask(key));
  if (/\s/.test(key))
    throw new InvalidAnthropicKeyError(
      "contains whitespace (did you paste something that includes a newline?)",
      diagnosticMask(key)
    );
}
async function maybeOfferPersist(key, source, logger2) {
  if (process.stdin.isTTY !== !0 || await readFromConfigFile() === key) return;
  let answer = (await prompt(`Save key from ${source} to ${KEY_PATH} (chmod 600)? [y/N]: `)).trim().toLowerCase();
  answer === "y" || answer === "yes" ? (await persistKey(key), logger2.ok(`saved key to ${KEY_PATH} (${mask(key)})`)) : logger2.skip(`not persisting key (${mask(key)} from ${source})`);
}
function prompt(question) {
  let rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve3) => {
    rl.question(question, (answer) => {
      rl.close(), resolve3(answer);
    });
  });
}
async function promptHidden(question) {
  process.stdout.write(question);
  let stdin = process.stdin;
  return stdin.setRawMode === void 0 ? prompt("") : (stdin.setRawMode(!0), stdin.resume(), await new Promise((resolve3) => {
    let buf = "", onData = (chunk) => {
      let s = chunk.toString("utf8");
      for (let ch of s) {
        if (ch === `
` || ch === "\r" || ch === "") {
          process.stdout.write(`
`), stdin.setRawMode?.(!1), stdin.pause(), stdin.removeListener("data", onData), resolve3(buf);
          return;
        }
        if (ch === "" && (stdin.setRawMode?.(!1), stdin.pause(), process.exit(130)), ch === "\x7F" || ch === "\b") {
          buf = buf.slice(0, -1);
          continue;
        }
        buf += ch;
      }
    };
    stdin.on("data", onData);
  }));
}

// src/lib/preflight.ts
async function runPreflight(opts) {
  let checks = [
    checkPlatform(),
    checkArch(),
    checkDiskSpace(opts.runner, "/", 500),
    checkDiskSpace(opts.runner, "/tmp", 100),
    checkBashSanity(opts.runner)
  ];
  return opts.skipSudo !== !0 && checks.push(checkSudo(opts.runner)), opts.offline !== !0 && checks.push(checkNetwork(opts.runner)), Promise.all(checks);
}
function reportPreflight(results, logger2) {
  let blockers = 0;
  for (let r of results)
    r.ok ? logger2.ok(`preflight: ${r.description} \u2014 ${r.message}`) : r.severity === "warning" ? logger2.warn(`preflight: ${r.description} \u2014 ${r.message}`) : (logger2.fail(`preflight: ${r.description} \u2014 ${r.message}`), blockers++);
  return blockers;
}
async function checkPlatform() {
  return process.platform === "linux" ? {
    id: "platform",
    description: "platform is Linux",
    ok: !0,
    message: process.platform,
    severity: "blocker"
  } : {
    id: "platform",
    description: "platform is Linux",
    ok: !1,
    message: `running on ${process.platform}; many modules will be SKIP gated`,
    severity: "warning"
  };
}
async function checkArch() {
  let arch = process.arch;
  return arch === "x64" ? {
    id: "arch",
    description: "CPU architecture is x86_64",
    ok: !0,
    message: arch,
    severity: "blocker"
  } : {
    id: "arch",
    description: "CPU architecture is x86_64",
    ok: !1,
    message: `running on ${arch} \u2014 duckdb native module and some binary downloads (eza, fnm) assume x86_64 and may fail to build/run`,
    severity: "warning"
  };
}
async function checkSudo(runner) {
  return process.getuid?.() === 0 ? {
    id: "sudo",
    description: "sudo / root access available",
    ok: !0,
    message: "running as root",
    severity: "blocker"
  } : (await runner.run("sudo -nv 2>&1", { allowFailure: !0 })).code === 0 ? {
    id: "sudo",
    description: "sudo / root access available",
    ok: !0,
    message: "sudo cached or NOPASSWD",
    severity: "blocker"
  } : {
    id: "sudo",
    description: "sudo / root access available",
    ok: !1,
    message: "sudo will prompt for password during install. Consider running `sudo -v` first, OR run the bootstrap as root.",
    severity: "warning"
    // NOT a blocker — apt-get will prompt and might still succeed
  };
}
async function checkDiskSpace(runner, mountpoint, minMb) {
  let id = `disk-${mountpoint}`, desc = `at least ${minMb} MB free on ${mountpoint}`, result = await runner.run(`df -m --output=avail ${mountpoint} | tail -1`, {
    allowFailure: !0
  });
  if (result.code !== 0)
    return {
      id,
      description: desc,
      ok: !1,
      message: `df failed: ${result.stderr.trim()}`,
      severity: "warning"
    };
  let avail = Number.parseInt(result.stdout.trim(), 10);
  return Number.isFinite(avail) ? avail < minMb ? {
    id,
    description: desc,
    ok: !1,
    message: `only ${avail} MB free`,
    severity: "blocker"
  } : {
    id,
    description: desc,
    ok: !0,
    message: `${avail} MB free`,
    severity: "blocker"
  } : {
    id,
    description: desc,
    ok: !1,
    message: `unparseable df output: ${result.stdout.trim()}`,
    severity: "warning"
  };
}
async function checkNetwork(runner) {
  let result = await runner.run(
    "curl -fsSL --max-time 5 -o /dev/null -w '%{http_code}' https://registry.npmjs.org/-/ping",
    { allowFailure: !0 }
  );
  return result.code === 0 && result.stdout.startsWith("2") ? {
    id: "network",
    description: "outbound HTTPS to npm registry",
    ok: !0,
    message: `HTTP ${result.stdout}`,
    severity: "blocker"
  } : {
    id: "network",
    description: "outbound HTTPS to npm registry",
    ok: !1,
    message: "registry.npmjs.org unreachable. Use --offline if you've pre-cached deps.",
    severity: "blocker"
  };
}
async function checkBashSanity(runner) {
  let required = ["grep", "sed", "awk", "curl"], missing = [];
  for (let bin of required)
    await runner.commandExists(bin) || missing.push(bin);
  return missing.length === 0 ? {
    id: "bash-sanity",
    description: `standard tools (${required.join("/")}) on PATH`,
    ok: !0,
    message: `${required.length}/${required.length} resolved`,
    severity: "blocker"
  } : {
    id: "bash-sanity",
    description: `standard tools (${required.join("/")}) on PATH`,
    ok: !1,
    message: `missing: ${missing.join(", ")} \u2014 install will fail without these`,
    severity: "blocker"
  };
}

// src/lib/runner.ts
import { spawn } from "node:child_process";
import { promisify } from "node:util";
import { exec as execCb } from "node:child_process";
import { access, constants } from "node:fs/promises";
var exec = promisify(execCb), CommandFailedError = class extends Error {
  cmd;
  code;
  stdout;
  stderr;
  constructor(cmd, result) {
    super(`command failed (exit ${result.code}): ${cmd}
stderr: ${result.stderr.trim()}`), this.name = "CommandFailedError", this.cmd = cmd, this.code = result.code, this.stdout = result.stdout, this.stderr = result.stderr;
  }
}, Runner = class {
  dryRun;
  logger;
  isRoot;
  constructor(opts) {
    this.dryRun = opts.dryRun, this.logger = opts.logger, this.isRoot = process.getuid?.() === 0;
  }
  /**
   * Run a command. By default throws on non-zero exit. Pass allowFailure: true
   * to inspect the result without throwing (useful for `command -v` style
   * existence checks).
   */
  async run(cmd, opts = {}) {
    let finalCmd = this.maybeSudoWrap(cmd, opts.sudo === !0);
    return this.dryRun ? (this.logger.info(`[dry-run] ${finalCmd}`), { stdout: "", stderr: "", code: 0 }) : opts.stream === !0 ? this.runStreaming(finalCmd, opts) : this.runCaptured(finalCmd, opts);
  }
  /**
   * Check if a binary exists on PATH. Uses native fs.access() on each PATH
   * entry instead of spawning a shell — ~0.1ms vs ~15ms per call.
   */
  async commandExists(bin) {
    if (this.dryRun) return !0;
    let dirs = (process.env.PATH ?? "").split(":");
    for (let dir of dirs)
      try {
        return await access(`${dir}/${bin}`, constants.X_OK), !0;
      } catch {
      }
    return !1;
  }
  /**
   * Capture stdout from a command. Convenience for `result.stdout.trim()`.
   * Throws on failure (not pass-through).
   */
  async capture(cmd, opts = {}) {
    return (await this.run(cmd, { ...opts, stream: !1 })).stdout.trim();
  }
  /** Returns true if `path` exists. Uses native fs.access() — no shell spawn. */
  async pathExists(path15) {
    if (this.dryRun) return !1;
    try {
      return await access(path15), !0;
    } catch {
      return !1;
    }
  }
  /** Append text to a file (creates if missing). Honors dryRun. */
  async appendFile(path15, content) {
    if (this.dryRun) {
      this.logger.info(`[dry-run] append ${content.length} bytes to ${path15}`);
      return;
    }
    let fs14 = await import("node:fs/promises");
    await fs14.mkdir(pathDirname(path15), { recursive: !0 }), await fs14.appendFile(path15, content);
  }
  /**
   * Write file atomically (write-to-tmp + rename). Honors dryRun.
   * Use `mode: 0o600` for secrets.
   *
   * The atomic part matters because crashing mid-write to ~/.bashrc would
   * leave a truncated file that breaks the next shell launch.
   */
  async writeFile(path15, content, opts = {}) {
    if (this.dryRun) {
      this.logger.info(`[dry-run] write ${content.length} bytes to ${path15}`);
      return;
    }
    let { atomicWrite: atomicWrite2 } = await Promise.resolve().then(() => (init_atomic_write(), atomic_write_exports));
    await atomicWrite2(path15, content, opts);
  }
  // -- internals --
  maybeSudoWrap(cmd, wantSudo) {
    return !wantSudo || this.isRoot ? cmd : `sudo ${cmd}`;
  }
  async runCaptured(cmd, opts) {
    try {
      let { stdout, stderr } = await exec(cmd, {
        cwd: opts.cwd,
        env: { ...process.env, ...opts.env ?? {} },
        timeout: opts.timeoutMs,
        maxBuffer: 10485760
      });
      return { stdout, stderr, code: 0 };
    } catch (err) {
      let e = err, result = {
        stdout: e.stdout ?? "",
        stderr: e.stderr ?? "",
        code: e.code ?? 1
      };
      if (opts.allowFailure === !0) return result;
      throw new CommandFailedError(cmd, result);
    }
  }
  runStreaming(cmd, opts) {
    return new Promise((resolve3, reject) => {
      let spawnOpts = {
        cwd: opts.cwd,
        env: { ...process.env, ...opts.env ?? {} },
        shell: !0,
        stdio: "inherit"
      }, child = spawn(cmd, spawnOpts), timer = opts.timeoutMs !== void 0 ? setTimeout(() => child.kill("SIGTERM"), opts.timeoutMs) : void 0;
      child.on("close", (code) => {
        timer !== void 0 && clearTimeout(timer);
        let result = { stdout: "", stderr: "", code: code ?? 1 };
        result.code === 0 || opts.allowFailure === !0 ? resolve3(result) : reject(new CommandFailedError(cmd, result));
      }), child.on("error", (err) => reject(err));
    });
  }
};
function pathDirname(p) {
  let i = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"));
  return i < 0 ? "." : p.slice(0, i);
}

// src/modules/apt-core.ts
var APT_CORE = [
  // General
  "git",
  "curl",
  "ca-certificates",
  "jq",
  // Networking debug — minimum viable
  "iproute2",
  "iptables",
  "dnsutils",
  "netcat-openbsd",
  "tcpdump",
  "nmap",
  // Performance / observability
  "sysstat",
  "htop",
  "lsof",
  "strace",
  "procps",
  // TLS
  "openssl",
  // Productivity (TUI) — small + interview-relevant
  "ripgrep",
  "fzf",
  // bash-completion framework (was missing in legacy)
  "bash-completion",
  // Python (preinstalled but explicit so install verifies it)
  "python3",
  // age — required by anthropic-key module (decrypts _secrets/*.age via SSH key)
  "age"
], REQUIRED_BINS = [
  "jq",
  "rg",
  "lsof",
  "ss",
  "tcpdump",
  "python3",
  "nmap",
  "openssl",
  "git",
  "age"
], aptCoreModule = {
  id: "apt-core",
  description: "Apt packages: network/perf/process/python/coredump diagnostics + bash-completion",
  narrative: "32 diagnostic + dev tools \u2014 jq, ripgrep, lsof, tcpdump, python3, age, nmap, bash-completion",
  tags: ["apt", "core"],
  shouldRun() {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    for (let bin of REQUIRED_BINS)
      if (!await ctx.runner.commandExists(bin)) return !1;
    return !0;
  },
  async install(ctx) {
    let updateResult = await ctx.runner.run("apt-get update -y", {
      sudo: !0,
      stream: !0,
      allowFailure: !0
    });
    updateResult.code !== 0 && ctx.logger.warn(
      `apt-get update failed (exit ${updateResult.code}) \u2014 package install may use stale lists. stderr: ${updateResult.stderr.trim().slice(0, 200) || "(empty)"}`
    );
    let pkgList = APT_CORE.join(" ");
    await ctx.runner.run(
      `DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${pkgList}`,
      { sudo: !0, stream: !0 }
    );
  },
  async verify(ctx) {
    let missing = [];
    for (let bin of REQUIRED_BINS)
      await ctx.runner.commandExists(bin) || missing.push(bin);
    return missing.length > 0 ? { ok: !1, message: `missing on PATH: ${missing.join(", ")}` } : { ok: !0, message: `${REQUIRED_BINS.length} required binaries present` };
  }
};

// src/modules/apt-optional.ts
import * as fs5 from "node:fs/promises";
import * as os3 from "node:os";
import * as path6 from "node:path";
var STAMP_FILE = ".apt-optional-attempted", BINS = ["bpftrace", "btop", "sysbench"];
async function binExists(name) {
  let dirs = (process.env.PATH ?? "").split(":");
  for (let dir of dirs)
    try {
      return await fs5.access(path6.join(dir, name), fs5.constants.X_OK), !0;
    } catch {
    }
  return !1;
}
var aptOptionalModule = {
  id: "apt-optional",
  description: "Optional heavy apt packages (eBPF tooling, perf, btop, sysbench)",
  narrative: "eBPF + perf for kernel-level tracing (bpftrace, off-CPU profiling, perf-record)",
  tags: ["apt", "optional"],
  shouldRun(config) {
    return process.platform === "linux" && !config.minimal;
  },
  async isInstalled(ctx) {
    for (let bin of BINS)
      if (await binExists(bin)) return !0;
    let stamp = path6.join(ctx.home, STAMP_FILE);
    try {
      return (await fs5.readFile(stamp, "utf8")).trim() === os3.release();
    } catch {
      return !1;
    }
  },
  async install(ctx) {
    let kernel = os3.release(), headersDir = `/usr/src/linux-headers-${kernel}`;
    try {
      await fs5.access(headersDir);
    } catch {
      if (!(await ctx.runner.run(
        `dpkg-query -W -f='\${Status}' linux-headers-${kernel} 2>/dev/null`,
        { allowFailure: !0 }
      )).stdout.includes("install ok installed")) {
        ctx.logger.warn(
          `linux-headers-${kernel} not available \u2014 skipping eBPF/perf install (non-standard kernel)`
        ), await fs5.writeFile(path6.join(ctx.home, STAMP_FILE), kernel + `
`).catch(() => {
        });
        return;
      }
    }
    let pkgs = [
      "bpfcc-tools",
      `linux-headers-${kernel}`,
      "bpftrace",
      "linux-tools-common",
      "linux-tools-generic",
      `linux-tools-${kernel}`,
      "btop",
      "sysbench"
    ];
    (await ctx.runner.run(
      `DEBIAN_FRONTEND=noninteractive apt-get install -y ${pkgs.join(" ")}`,
      { sudo: !0, stream: !0, allowFailure: !0 }
    )).code !== 0 && ctx.logger.warn(
      "some optional packages failed (often linux-headers for an unsupported kernel) \u2014 non-fatal"
    ), await fs5.writeFile(path6.join(ctx.home, STAMP_FILE), kernel + `
`).catch(() => {
    });
  },
  async verify(_ctx) {
    let present = [];
    for (let bin of BINS)
      await binExists(bin) && present.push(bin);
    return {
      ok: present.length > 0,
      message: present.length > 0 ? `installed: ${present.join(", ")}` : "no optional binaries present"
    };
  }
};

// src/modules/apt-docker.ts
var aptDockerModule = {
  id: "apt-docker",
  description: "Docker engine + compose plugin (gated on --with-docker)",
  narrative: "Docker engine + compose + containerd",
  tags: ["apt", "docker", "optional"],
  shouldRun(config) {
    return process.platform === "linux" && config.withDocker;
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("docker");
  },
  async install(ctx) {
    await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin containerd uidmap",
      { sudo: !0, stream: !0 }
    );
    let user = process.env.USER ?? process.env.LOGNAME ?? "";
    user !== "" && user !== "root" && (await ctx.runner.run(`usermod -aG docker ${user}`, { sudo: !0, allowFailure: !0 }), ctx.logger.warn(
      "you'll need to log out + back in for docker group membership to take effect"
    ));
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("docker") ? { ok: !0, message: "docker installed" } : { ok: !1, message: "docker not on PATH" };
  }
};

// src/modules/apt-k8s.ts
var aptK8sModule = {
  id: "apt-k8s",
  description: "kubectl from upstream stable release (gated on --with-k8s)",
  tags: ["k8s", "optional"],
  shouldRun(config) {
    return process.platform === "linux" && config.withK8s;
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("kubectl");
  },
  async install(ctx) {
    let version = (await ctx.runner.capture("curl -fsSL https://dl.k8s.io/release/stable.txt")).trim();
    if (!/^v\d+\.\d+\.\d+/.test(version))
      throw new Error(`unexpected kubectl version string from dl.k8s.io: ${version}`);
    await ctx.runner.run(
      `curl -fsSLo /tmp/kubectl https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl`
    ), await ctx.runner.run("install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl", {
      sudo: !0
    }), await ctx.runner.run("rm -f /tmp/kubectl"), ctx.logger.ok(`kubectl ${version} installed`);
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("kubectl") ? { ok: !0, message: `kubectl present (${(await ctx.runner.capture("kubectl version --client -o yaml | head -3")).split(`
`)[0]})` } : { ok: !1, message: "kubectl not on PATH" };
  }
};

// src/modules/apt-aws.ts
var aptAwsModule = {
  id: "apt-aws",
  description: "aws-cli v2 from awscli-exe-linux installer (gated on --with-aws)",
  tags: ["aws", "optional"],
  shouldRun(config) {
    return process.platform === "linux" && config.withAws;
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("aws");
  },
  async install(ctx) {
    await ctx.runner.run(
      'curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip'
    ), await ctx.runner.run("cd /tmp && unzip -q -o awscliv2.zip"), await ctx.runner.run("/tmp/aws/install --update", { sudo: !0 }), await ctx.runner.run("rm -rf /tmp/aws /tmp/awscliv2.zip");
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("aws") ? { ok: !0, message: `aws-cli present (${(await ctx.runner.capture("aws --version 2>&1 | head -1")).trim()})` } : { ok: !1, message: "aws not on PATH" };
  }
};

// src/modules/node.ts
var NODE_VERSION = "22.15.0", nodeModule = {
  id: "node",
  description: "Node.js >= 22 via binary tarball (fnm fallback)",
  tags: ["runtime"],
  shouldRun() {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    return await currentNodeMajor(ctx) >= 22;
  },
  async install(ctx) {
    await tryBinaryTarball(ctx) && await currentNodeMajor(ctx) >= 22 || (ctx.logger.warn("binary tarball install failed; trying fnm fallback"), await tryFnm(ctx));
  },
  async verify(ctx) {
    let major = await currentNodeMajor(ctx);
    return major < 22 ? { ok: !1, message: `node major version ${major} < 22` } : { ok: !0, message: `node ${await ctx.runner.capture("node -v")}` };
  }
};
async function tryBinaryTarball(ctx) {
  let arch = process.arch === "x64" ? "x64" : "arm64", url = `https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.gz`, nodeDir = `/usr/local/lib/node-v${NODE_VERSION}`, result = await ctx.runner.run(
    `curl -fsSL --max-time 15 "${url}" | tar xz -C /usr/local/lib/ && mv /usr/local/lib/node-v${NODE_VERSION}-linux-${arch} ${nodeDir}`,
    { sudo: !0, allowFailure: !0 }
  );
  if (result.code !== 0)
    return ctx.logger.warn(`binary tarball download failed (exit ${result.code})`), !1;
  for (let bin of ["node", "npm", "npx"])
    await ctx.runner.run(`ln -sf ${nodeDir}/bin/${bin} /usr/local/bin/${bin}`, {
      sudo: !0,
      allowFailure: !0
    });
  return !0;
}
async function tryFnm(ctx) {
  let fnmInstall = await ctx.runner.run(
    "curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell",
    { stream: !0, allowFailure: !0 }
  );
  if (fnmInstall.code !== 0)
    throw new Error(
      `fnm fallback install also failed (exit ${fnmInstall.code}). No way to get Node 22. Install manually: curl -fsSL https://fnm.vercel.app/install | bash`
    );
  let envSetup = `export PATH="${`${ctx.home}/.local/share/fnm`}:$PATH" && eval "$(fnm env)"`;
  await ctx.runner.run(
    `${envSetup} && fnm install 22 && fnm use 22 && fnm default 22`,
    { stream: !0 }
  );
  let nodePathResult = await ctx.runner.run(
    `${envSetup} && which node`,
    { allowFailure: !0 }
  );
  if (nodePathResult.code === 0) {
    let nodePath = nodePathResult.stdout.trim(), npmPath = nodePath.replace(/\/node$/, "/npm"), npxPath = nodePath.replace(/\/node$/, "/npx");
    await ctx.runner.run(`ln -sf ${nodePath} /usr/local/bin/node`, { sudo: !0, allowFailure: !0 }), await ctx.runner.run(`ln -sf ${npmPath} /usr/local/bin/npm`, { sudo: !0, allowFailure: !0 }), await ctx.runner.run(`ln -sf ${npxPath} /usr/local/bin/npx`, { sudo: !0, allowFailure: !0 }), ctx.logger.ok("symlinked fnm node 22 into /usr/local/bin");
  }
}
async function currentNodeMajor(ctx) {
  if (!await ctx.runner.commandExists("node")) return 0;
  let v = await ctx.runner.capture("node -v"), m = /^v(\d+)\./.exec(v);
  return m === null || m[1] === void 0 ? 0 : Number.parseInt(m[1], 10);
}

// src/modules/pnpm.ts
var pnpmModule = {
  id: "pnpm",
  description: "pnpm package manager (global, via npm)",
  tags: ["runtime"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("pnpm");
  },
  async install(ctx) {
    if (!await ctx.runner.commandExists("npm"))
      throw new Error("npm not found \u2014 run the 'node' module first");
    await ctx.runner.run("npm install -g pnpm", { sudo: !0, stream: !0 });
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("pnpm") ? { ok: !0, message: `pnpm ${(await ctx.runner.capture("pnpm --version")).trim()}` } : { ok: !1, message: "pnpm not on PATH" };
  }
};

// src/modules/claude-code.ts
var claudeCodeModule = {
  id: "claude-code",
  description: "@anthropic-ai/claude-code CLI (global npm install)",
  tags: ["runtime", "ai"],
  shouldRun(config) {
    return !config.noClaude;
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("claude");
  },
  async install(ctx) {
    if (!await ctx.runner.commandExists("npm"))
      throw new Error("npm not found \u2014 run the 'node' module first");
    await ctx.runner.run("npm install -g @anthropic-ai/claude-code", {
      sudo: !0,
      stream: !0
    });
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("claude") ? { ok: !0, message: "claude installed" } : { ok: !1, message: "claude not on PATH" };
  }
};

// src/modules/eza.ts
var ezaModule = {
  id: "eza",
  description: "eza (modern ls). apt first, fallback to release tarball.",
  tags: ["shell", "productivity"],
  shouldRun() {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("eza");
  },
  async install(ctx) {
    (await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y eza",
      { sudo: !0, allowFailure: !0 }
    )).code === 0 && await ctx.runner.commandExists("eza") || (ctx.logger.info("apt eza unavailable; falling back to GitHub release tarball"), await ctx.runner.run(
      "curl -fsSL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -o /tmp/eza.tar.gz"
    ), await ctx.runner.run("tar -xzf /tmp/eza.tar.gz -C /tmp"), await ctx.runner.run("install -o root -g root -m 0755 /tmp/eza /usr/local/bin/eza", { sudo: !0 }), await ctx.runner.run("rm -f /tmp/eza /tmp/eza.tar.gz"));
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("eza") ? { ok: !0, message: "eza installed" } : { ok: !1, message: "eza not on PATH" };
  }
};

// src/modules/zoxide.ts
var zoxideModule = {
  id: "zoxide",
  description: "zoxide (smarter cd, frecency-based). apt \u2192 upstream installer fallback.",
  tags: ["shell", "productivity"],
  shouldRun() {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("zoxide");
  },
  async install(ctx) {
    (await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y zoxide",
      { sudo: !0, allowFailure: !0 }
    )).code === 0 && await ctx.runner.commandExists("zoxide") || (ctx.logger.info("apt zoxide unavailable; falling back to upstream installer"), await ctx.runner.run(
      "curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash",
      { stream: !0 }
    ));
  },
  async verify(ctx) {
    return await ctx.runner.commandExists("zoxide") ? { ok: !0, message: "zoxide installed" } : { ok: !1, message: "zoxide not on PATH (might need new shell to pick up PATH)" };
  }
};

// src/modules/atuin.ts
var atuinModule = {
  id: "atuin",
  description: "atuin (TUI shell history). User-local install via setup.atuin.sh.",
  tags: ["shell", "history"],
  shouldRun() {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    return await ctx.runner.commandExists("atuin") ? !0 : await ctx.runner.pathExists(`${ctx.home}/.atuin/bin/atuin`);
  },
  async install(ctx) {
    if (await ctx.runner.run("curl --proto '=https' --tlsv1.2 -fsSL https://setup.atuin.sh | sh", {
      stream: !0
    }), !await this.isInstalled(ctx))
      throw new Error("atuin install completed but binary not found in expected paths");
  },
  async verify(ctx) {
    return await this.isInstalled(ctx) ? { ok: !0, message: "atuin installed" } : { ok: !1, message: "atuin not found after install (need new shell to pick up PATH?)" };
  }
};

// src/modules/seed-history.ts
import * as fs6 from "node:fs/promises";
import * as path7 from "node:path";
import * as crypto2 from "node:crypto";
var STAMP_FILE2 = ".seed-history-hash", seedHistoryModule = {
  id: "seed-history",
  description: "Append cmd_history.txt \u2192 ~/.bash_history and import into atuin",
  tags: ["shell", "history"],
  shouldRun(config) {
    return !config.noShellConfig;
  },
  async isInstalled(ctx) {
    let seed = path7.join(ctx.config.repoDir, "cmd_history.txt"), stamp = path7.join(ctx.home, STAMP_FILE2);
    try {
      let [seedBuf, savedHash] = await Promise.all([
        fs6.readFile(seed),
        fs6.readFile(stamp, "utf8")
      ]);
      return crypto2.createHash("sha256").update(seedBuf).digest("hex") === savedHash.trim();
    } catch {
      return !1;
    }
  },
  async install(ctx) {
    let seed = path7.join(ctx.config.repoDir, "cmd_history.txt");
    if (!await ctx.runner.pathExists(seed)) {
      ctx.logger.skip(`no cmd_history.txt at ${seed}`);
      return;
    }
    let histPath = `${ctx.home}/.bash_history`;
    await ctx.runner.run(
      `cat ${shQuote(seed)} >> ${shQuote(histPath)} && awk '!seen[$0]++' ${shQuote(histPath)} > ${shQuote(histPath + ".tmp")} && mv ${shQuote(histPath + ".tmp")} ${shQuote(histPath)}`
    ), ctx.logger.ok(`seeded ~/.bash_history from ${seed}`), await ctx.runner.commandExists("atuin") && ((await ctx.runner.run("atuin import bash", { allowFailure: !0 })).code === 0 ? ctx.logger.ok("atuin: imported bash history") : ctx.logger.warn("atuin import failed; not fatal"));
    let seedBuf = await fs6.readFile(seed), hash = crypto2.createHash("sha256").update(seedBuf).digest("hex");
    await fs6.writeFile(path7.join(ctx.home, STAMP_FILE2), hash + `
`);
  },
  async verify(ctx) {
    let histPath = `${ctx.home}/.bash_history`;
    return await ctx.runner.pathExists(histPath) ? { ok: !0, message: "history file present" } : { ok: !1, message: "no ~/.bash_history" };
  }
};
function shQuote(s) {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

// src/modules/docker-completion.ts
import * as path8 from "node:path";
var TARGET = ".local/share/bash-completion/completions/docker", DOCKER_COMPLETION_BODY = `# Minimal bash completion for docker \u2014 installed by @domains/bootstrap.
# Replaces broken Docker Desktop symlinks. To upgrade later:
#   docker completion bash > ~/.local/share/bash-completion/completions/docker

_docker_min() {
    local cur prev words cword
    _init_completion || return

    local subcmds="
        attach build builder buildx checkpoint commit compose config container
        context cp create diff events exec export history image images
        import info inspect kill load login logout logs manifest network
        node plugin port ps pull push rename restart rm rmi run save scan
        search secret service stack start stats stop swarm system tag top
        trust unpause update version volume wait
        completion
    "

    local ps_flags="-a --all -q --quiet --filter --format --last --latest --no-trunc --size"
    local logs_flags="-f --follow --tail --since --until -t --timestamps --details"
    local run_flags="-d --detach -it --rm --name --network --env -e --env-file -v --volume -p --publish --memory --cpus --restart --user --entrypoint"
    local exec_flags="-it --user --workdir --env -e --detach -d --privileged"

    if [ "$cword" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$subcmds" -- "$cur") )
        return 0
    fi

    case "\${words[1]}" in
        ps)
            COMPREPLY=( $(compgen -W "$ps_flags" -- "$cur") )
            return 0
            ;;
        logs)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$logs_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            fi
            return 0
            ;;
        run)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$run_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur") )
            fi
            return 0
            ;;
        exec)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$exec_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            fi
            return 0
            ;;
        inspect|stop|start|restart|kill|rm|pause|unpause|wait|top|attach|cp|diff|stats)
            COMPREPLY=( $(compgen -W "$(docker ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            return 0
            ;;
        rmi|history|tag|push|pull|save)
            COMPREPLY=( $(compgen -W "$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur") )
            return 0
            ;;
        network|volume|system|image|container|builder|context)
            local sub2="ls inspect rm prune create"
            [ "\${words[1]}" = "system" ] && sub2="info df events prune"
            [ "\${words[1]}" = "context" ] && sub2="ls inspect use create rm"
            if [ "$cword" -eq 2 ]; then
                COMPREPLY=( $(compgen -W "$sub2" -- "$cur") )
            fi
            return 0
            ;;
    esac
}

complete -F _docker_min docker
`, dockerCompletionModule = {
  id: "docker-completion",
  description: "User-local docker bash completion fallback (handles broken Docker Desktop symlink)",
  tags: ["shell", "docker"],
  shouldRun(config) {
    return !config.noShellConfig;
  },
  async isInstalled(ctx) {
    let target = path8.join(ctx.home, TARGET);
    return await ctx.runner.pathExists(target) ? (await ctx.runner.run(`grep -q '_docker_min' ${target}`, { allowFailure: !0 })).code === 0 : !1;
  },
  async install(ctx) {
    let target = path8.join(ctx.home, TARGET);
    await ctx.runner.writeFile(target, DOCKER_COMPLETION_BODY), ctx.logger.ok(`wrote docker completion to ${target}`);
  },
  async verify(ctx) {
    let target = path8.join(ctx.home, TARGET);
    return await ctx.runner.pathExists(target) ? { ok: !0, message: "docker completion file present" } : { ok: !1, message: `${target} missing` };
  }
};

// src/modules/bashrc.ts
import * as fs8 from "node:fs/promises";
import * as path9 from "node:path";

// src/bashrc/completions.ts
var COMPLETIONS_BLOCK = `# bash-completion framework + per-tool completions
if ! shopt -oq posix 2>/dev/null; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    source /etc/bash_completion
  fi
fi

# User-local docker completion (fallback when Docker Desktop symlink is dead).
# The bootstrap docker-completion module writes to this path.
if [[ -f "$HOME/.local/share/bash-completion/completions/docker" ]]; then
  source "$HOME/.local/share/bash-completion/completions/docker"
fi`;

// src/bashrc/explain-fn.ts
var EXPLAIN_FN_BLOCK = `# Quick claude wrapper for one-shot questions
explain() {
  if command -v claude >/dev/null 2>&1; then
    claude --print "Explain this concisely + suggest a fix: $*"
  else
    echo "claude not installed (run bootstrap install)" >&2
  fi
}`;

// src/bashrc/productivity-aliases.ts
var PRODUCTIVITY_ALIASES_BLOCK = `# Productivity aliases (graceful fallback if tool isn't installed).
# NOTE: grep is intentionally NOT aliased to ripgrep. See safety.ts for why.
command -v eza    >/dev/null && alias ls='eza --icons --group-directories-first'
command -v batcat >/dev/null && alias cat='batcat --paging=never --plain'
command -v bat    >/dev/null && alias cat='bat --paging=never --plain'
command -v zoxide >/dev/null && alias cd='z'`;

// src/bashrc/repo-aliases.ts
function repoAliasesBlock(repoDir) {
  return `# Repo-specific aliases (sourced from current dir of repo)
if [[ -f "${repoDir}/.aliases" ]]; then
  source "${repoDir}/.aliases"
fi`;
}

// src/bashrc/safety.ts
var LINES = [
  "# ============================================================",
  "# DEMO/INTERVIEW SAFETY LAYER",
  "# ============================================================",
  "#",
  "# demoshell \u2014 drops into a clean subshell with all alias overrides cleared.",
  "# Use this during practice + interview screen-share so muscle-memory",
  "# 'grep -E ...' doesn't get hijacked by 'rg', 'cat' isn't 'bat', etc.",
  "# 'exit' returns to your normal shell.",
  "demoshell() {",
  "    bash --noprofile --norc -c '",
  '        export PS1="\\[\\033[1;32m\\]demo\\[\\033[0m\\]:\\w\\$ "',
  '        export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"',
  '        export EDITOR="${EDITOR:-vi}" PAGER="${PAGER:-less}" LESS="${LESS:-FRX}"',
  '        echo "demoshell \u2014 vanilla bash, no aliases, no shell integrations."',
  '        echo "Type \\"exit\\" to return to your normal shell."',
  "        exec bash --norc --noprofile -i",
  "    '",
  "}",
  "",
  "# bashrc-landmines \u2014 read-only check that flags shell config that will break",
  "# the interview. Call from preflight; safe to invoke any time.",
  "bashrc-landmines() {",
  "    local issues=0",
  '    echo "=== Bashrc landmine scan ==="',
  "",
  "    # 1. grep aliased to a non-grep tool",
  "    local grep_alias",
  `    grep_alias="$(alias grep 2>/dev/null | sed -n "s/^alias grep='\\(.*\\)'$/\\1/p")"`,
  '    if [[ -n "$grep_alias" && "$grep_alias" != grep* ]]; then',
  '        echo "  [FAIL] grep is aliased to: $grep_alias  ->  breaks grep -E/-A/-B"',
  "        issues=$((issues+1))",
  "    else",
  '        echo "  [OK]   grep alias safe ($grep_alias)"',
  "    fi",
  "",
  "    # 2. inshellisense process running (terminal corruption source)",
  "    if pgrep -f inshellisense >/dev/null 2>&1; then",
  '        echo "  [FAIL] inshellisense process active  ->  causes terminal corruption"',
  "        issues=$((issues+1))",
  "    else",
  '        echo "  [OK]   no inshellisense process running"',
  "    fi",
  "",
  "    # 3. bashrc syntax check",
  "    if bash -n ~/.bashrc 2>/dev/null; then",
  '        echo "  [OK]   ~/.bashrc parses cleanly"',
  "    else",
  '        echo "  [FAIL] ~/.bashrc has syntax errors  ->  shell may misbehave"',
  "        issues=$((issues+1))",
  "    fi",
  "",
  "    # 4. Standard tools resolve to real binaries (type -P bypasses aliases)",
  '    local missing=""',
  "    for c in grep sed awk find ps; do",
  '        [[ -z "$(type -P "$c")" ]] && missing="$missing $c"',
  "    done",
  '    if [[ -n "$missing" ]]; then',
  '        echo "  [FAIL] missing on PATH:$missing"',
  "        issues=$((issues+1))",
  "    else",
  '        echo "  [OK]   standard tools resolve (grep sed awk find ps)"',
  "    fi",
  "",
  "    # 5. Stale screen size warning",
  '    if [[ "$(stty size 2>/dev/null | awk "{print \\$2}")" == "1" ]]; then',
  '        echo "  [WARN] terminal reports 1-col width  ->  expect display weirdness"',
  "    fi",
  "",
  '    echo ""',
  "    if [[ $issues -eq 0 ]]; then",
  '        echo "  Result: clean. Safe for interview/demo."',
  "    else",
  `        echo "  Result: $issues issue(s). Run 'demoshell' for a clean fallback."`,
  "    fi",
  "    return $issues",
  "}",
  "# ============================================================"
], SAFETY_BLOCK = LINES.join(`
`);

// src/bashrc/tool-init.ts
var TOOL_INIT_BLOCK = `# atuin (shell history with TUI search). Adds Ctrl-R rebinding.
if [[ -d "$HOME/.atuin/bin" ]]; then
  export PATH="$PATH:$HOME/.atuin/bin"
fi
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash)"
fi

# zoxide (smarter cd). Adds 'z <fragment>' to jump to frecent dirs.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# fzf key bindings (Ctrl-R for fuzzy history if atuin not present, Ctrl-T
# for fuzzy file pick, Alt-C for fuzzy cd).
if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  source /usr/share/doc/fzf/examples/completion.bash 2>/dev/null || true
fi`;

// src/bashrc/builder.ts
function buildBashrcBody(input) {
  return [
    "# Generated by @domains/bootstrap. Re-run `pnpm bootstrap install` to regenerate.\n# To temporarily disable, comment out this whole block (between the markers).\n# To remove permanently, run `pnpm bootstrap install --module=bashrc-remove`.",
    TOOL_INIT_BLOCK,
    COMPLETIONS_BLOCK,
    PRODUCTIVITY_ALIASES_BLOCK,
    repoAliasesBlock(input.repoDir),
    EXPLAIN_FN_BLOCK,
    SAFETY_BLOCK
  ].map((f) => f.trim()).join(`

`);
}

// src/lib/bashrc-block.ts
import * as fs7 from "node:fs/promises";

// src/lib/types.ts
var BASHRC_MARKER_BEGIN = "# >>> domains-bootstrap >>>", BASHRC_MARKER_END = "# <<< domains-bootstrap <<<";

// src/lib/bashrc-block.ts
async function writeBashrcBlock(opts) {
  let wrapped = `${BASHRC_MARKER_BEGIN}
${opts.content.trim()}
${BASHRC_MARKER_END}
`, existing = "";
  try {
    existing = await fs7.readFile(opts.path, "utf8");
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }
  let next;
  existing.includes(BASHRC_MARKER_BEGIN) && existing.includes(BASHRC_MARKER_END) ? next = replaceBetweenMarkers(existing, wrapped) : existing === "" ? next = wrapped : next = `${existing.replace(/\n*$/, "")}

${wrapped}`, next !== existing && await opts.runner.writeFile(opts.path, next);
}
async function readBashrcBlock(path15) {
  let raw;
  try {
    raw = await fs7.readFile(path15, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") return "";
    throw err;
  }
  let start = raw.indexOf(BASHRC_MARKER_BEGIN), end = raw.indexOf(BASHRC_MARKER_END);
  return start < 0 || end < 0 || end < start ? "" : raw.slice(start + BASHRC_MARKER_BEGIN.length, end).trim();
}
function replaceBetweenMarkers(file, wrappedBlock) {
  let start = file.indexOf(BASHRC_MARKER_BEGIN), end = file.indexOf(BASHRC_MARKER_END), endLineBreak = file.indexOf(`
`, end + BASHRC_MARKER_END.length), endIdx = endLineBreak < 0 ? file.length : endLineBreak + 1, before = file.slice(0, start).replace(/\n+$/, `
`), after = file.slice(endIdx).replace(/^\n+/, "");
  return `${before}${wrappedBlock}${after === "" ? "" : `
${after}`}`;
}

// src/modules/bashrc.ts
var bashrcModule = {
  id: "bashrc",
  description: "Write managed block to ~/.bashrc (atuin/zoxide/fzf, aliases, safety functions)",
  tags: ["shell"],
  shouldRun(config) {
    return !config.noShellConfig;
  },
  async isInstalled(ctx) {
    let current = await readBashrcBlock(`${ctx.home}/.bashrc`), next = buildBashrcBody({ repoDir: ctx.config.repoDir });
    return current.trim() === next.trim();
  },
  async install(ctx) {
    let body = buildBashrcBody({ repoDir: ctx.config.repoDir });
    await writeBashrcBlock({
      path: path9.join(ctx.home, ".bashrc"),
      content: body,
      runner: ctx.runner
    }), ctx.logger.ok("~/.bashrc managed block written"), ctx.logger.info("open a NEW shell (or `source ~/.bashrc`) to pick up changes");
  },
  async verify(ctx) {
    let block = await readBashrcBlock(`${ctx.home}/.bashrc`);
    if (block === "")
      return { ok: !1, message: "managed block missing from ~/.bashrc" };
    if (!block.includes("demoshell()") || !block.includes("bashrc-landmines()"))
      return { ok: !1, message: "managed block present but missing safety functions" };
    if (block.includes("alias grep='rg'"))
      return { ok: !1, message: "grep=rg landmine present in managed block \u2014 STOP, regenerate" };
    let result = await ctx.runner.run(`bash -n ${ctx.home}/.bashrc`, { allowFailure: !0 });
    return result.code !== 0 ? { ok: !1, message: `~/.bashrc has bash -n syntax error: ${result.stderr.trim()}` } : { ok: !0, message: "managed block intact + safety functions present + no landmines" };
  },
  /**
   * Capture entire ~/.bashrc (or note its absence) so we can restore it if
   * install() corrupts the file. Returns the exact bytes; rollback() writes
   * them back atomically.
   */
  async snapshotState(ctx) {
    let target = path9.join(ctx.home, ".bashrc");
    try {
      return { existed: !0, content: await fs8.readFile(target, "utf8"), path: target };
    } catch (err) {
      if (err.code === "ENOENT") return { existed: !1, path: target };
      throw err;
    }
  },
  /**
   * Restore ~/.bashrc from the captured state. Atomic write.
   */
  async rollback(ctx, state) {
    let s = state;
    if (!s.existed) {
      try {
        await fs8.unlink(s.path);
      } catch {
      }
      ctx.logger.warn("rolled back bashrc by removing newly-created file");
      return;
    }
    await ctx.runner.writeFile(s.path, s.content ?? ""), ctx.logger.warn(`rolled back bashrc to pre-install state (${(s.content ?? "").length} bytes)`);
  }
};

// src/modules/anthropic-key.ts
import * as fs9 from "node:fs/promises";
import * as path10 from "node:path";
var ENCRYPTED_REPO_PATH = "_secrets/anthropic-key.age";
async function findSshPrivateKey(home) {
  let candidates = [
    path10.join(home, ".ssh", "id_ed25519"),
    path10.join(home, ".ssh", "id_ecdsa"),
    path10.join(home, ".ssh", "id_rsa")
  ];
  for (let c of candidates)
    try {
      return await fs9.access(c, fs9.constants.R_OK), c;
    } catch {
    }
}
var anthropicKeyModule = {
  id: "anthropic-key",
  description: "Decrypt _secrets/anthropic-key.age with user's SSH key \u2192 ~/.config/domains/anthropic-key (chmod 600)",
  tags: ["secrets"],
  shouldRun(config) {
    return process.platform === "linux";
  },
  async isInstalled(ctx) {
    let enc = path10.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    try {
      await fs9.access(enc);
    } catch {
      return !0;
    }
    try {
      return await fs9.access(configFilePath()), !0;
    } catch {
      return !1;
    }
  },
  async install(ctx) {
    let enc = path10.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    try {
      await fs9.access(enc);
    } catch {
      ctx.logger.skip(
        `${ENCRYPTED_REPO_PATH} not present in repo \u2014 nothing to decrypt. Create it with: pnpm bootstrap key encrypt`
      );
      return;
    }
    if (!await ctx.runner.commandExists("age")) {
      ctx.logger.skip(
        "age binary not found on PATH \u2014 cannot decrypt. Use --anthropic-key=KEY or set ANTHROPIC_API_KEY env instead."
      );
      return;
    }
    let sshKey = await findSshPrivateKey(ctx.home);
    if (sshKey === void 0) {
      ctx.logger.skip(
        "no SSH private key on this box \u2014 cannot decrypt. Use --anthropic-key=KEY or set ANTHROPIC_API_KEY env instead."
      );
      return;
    }
    ctx.logger.info(`decrypting ${ENCRYPTED_REPO_PATH} using ${sshKey}`);
    let result = await ctx.runner.run(`age --decrypt -i ${shQuote2(sshKey)} ${shQuote2(enc)}`, {
      allowFailure: !0
    });
    if (result.code !== 0) {
      ctx.logger.warn(
        `age decryption failed (exit ${result.code}) \u2014 SSH key may not match the encrypted file. Use --anthropic-key=KEY or set ANTHROPIC_API_KEY env instead. stderr: ${result.stderr.trim()}`
      );
      return;
    }
    let key = result.stdout.trim();
    if (!key.startsWith("sk-ant-"))
      throw new Error(
        "decrypted content does not look like an Anthropic key (no sk-ant- prefix). Did you encrypt the right thing?"
      );
    await persistKey(key), ctx.logger.ok(`provisioned ${configFilePath()} (chmod 600) from encrypted file`);
  },
  async verify(ctx) {
    let enc = path10.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    try {
      await fs9.access(enc);
    } catch {
      return { ok: !0, message: "no encrypted key file (skipped)" };
    }
    try {
      let stat6 = await fs9.stat(configFilePath());
      return (stat6.mode & 63) !== 0 ? {
        ok: !1,
        message: `${configFilePath()} has unsafe perms ${(stat6.mode & 511).toString(8)} (want 600)`
      } : { ok: !0, message: `${configFilePath()} present + chmod 600` };
    } catch {
      return { ok: !1, message: `${configFilePath()} missing` };
    }
  },
  /** Snapshot existing key file (if any) so failed install can roll back. */
  async snapshotState() {
    try {
      return { existed: !0, content: await fs9.readFile(configFilePath(), "utf8") };
    } catch {
      return { existed: !1 };
    }
  },
  async rollback(ctx, state) {
    let s = state;
    if (!s.existed) {
      try {
        await fs9.unlink(configFilePath());
      } catch {
      }
      return;
    }
    s.content !== void 0 && await persistKey(s.content.trim()), ctx.logger.warn(`rolled back ${configFilePath()} to pre-install state`);
  }
};
function shQuote2(s) {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

// src/modules/interview-notes.ts
import * as path11 from "node:path";
import * as fs10 from "node:fs/promises";
var TEMPLATE = "interview-notes.template.md", TARGET2 = "notes.md", interviewNotesModule = {
  id: "interview-notes",
  description: "Copy RCA notes template to ~/notes.md",
  tags: ["shell", "productivity"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    return await ctx.runner.pathExists(path11.join(ctx.home, TARGET2));
  },
  async install(ctx) {
    let src = path11.join(ctx.config.repoDir, TEMPLATE), dest = path11.join(ctx.home, TARGET2);
    try {
      await fs10.access(src);
    } catch {
      ctx.logger.skip(`${TEMPLATE} not found in repo \u2014 skipping`);
      return;
    }
    await fs10.copyFile(src, dest), ctx.logger.ok(`copied ${TEMPLATE} \u2192 ${dest}`);
  },
  async verify(ctx) {
    let dest = path11.join(ctx.home, TARGET2);
    return await ctx.runner.pathExists(dest) ? { ok: !0, message: `${dest} present` } : { ok: !1, message: `${dest} missing` };
  }
};

// src/modules/pnpm-install.ts
var pnpmInstallModule = {
  id: "pnpm-install",
  description: "pnpm install in the repo root (workspace deps)",
  tags: ["repo"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    return await ctx.runner.pathExists(`${ctx.config.repoDir}/node_modules/.pnpm`);
  },
  async install(ctx) {
    await ctx.runner.run("pnpm install", {
      cwd: ctx.config.repoDir,
      stream: !0,
      timeoutMs: 12e4
    });
  },
  async verify(ctx) {
    let pnpmStore = `${ctx.config.repoDir}/node_modules/.pnpm`;
    if (!await ctx.runner.pathExists(pnpmStore))
      return {
        ok: !1,
        message: "node_modules/.pnpm missing \u2014 pnpm install did not run successfully"
      };
    let harnessDir = `${ctx.config.repoDir}/packages/harness/node_modules`;
    return await ctx.runner.pathExists(harnessDir) ? { ok: !0, message: "workspace deps present + harness ready" } : {
      ok: !1,
      message: "packages/harness/node_modules missing \u2014 workspace deps not installed"
    };
  }
};

// src/modules/corpus-migrate.ts
import * as fs11 from "node:fs/promises";
import * as path12 from "node:path";
import * as crypto3 from "node:crypto";
import { createRequire } from "node:module";
var STAMP_FILE3 = ".corpus-migrate-hash";
async function migrationFilesHash(repoDir) {
  let dir = path12.join(repoDir, "domains", "_shared", "queries", "migrations");
  try {
    let entries = (await fs11.readdir(dir)).filter((f) => f.endsWith(".sql")).sort(), h = crypto3.createHash("sha256");
    for (let entry of entries) {
      let content = await fs11.readFile(path12.join(dir, entry));
      h.update(entry), h.update(content);
    }
    return h.digest("hex");
  } catch {
    return "";
  }
}
async function migrationFileCount(repoDir) {
  let dir = path12.join(repoDir, "domains", "_shared", "queries", "migrations");
  try {
    return (await fs11.readdir(dir)).filter((f) => f.endsWith(".sql")).length;
  } catch {
    return 0;
  }
}
var corpusMigrateModule = {
  id: "corpus-migrate",
  description: "Apply versioned SQL migrations to _db/knowledge.duckdb (`pnpm corpus`)",
  tags: ["repo", "corpus"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    let stamp = path12.join(ctx.home, STAMP_FILE3), duckdb = path12.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      let [currentHash, savedHash] = await Promise.all([
        migrationFilesHash(ctx.config.repoDir),
        fs11.readFile(stamp, "utf8")
      ]);
      if (currentHash !== "" && currentHash === savedHash.trim()) return !0;
    } catch {
    }
    try {
      let [dbStat, hash] = await Promise.all([
        fs11.stat(duckdb),
        migrationFilesHash(ctx.config.repoDir)
      ]);
      if (dbStat.size > 1e5 && hash !== "")
        return await fs11.writeFile(stamp, hash + `
`).catch(() => {
        }), !0;
    } catch {
    }
    try {
      await fs11.access(duckdb);
      let fileCount = await migrationFileCount(ctx.config.repoDir);
      if (fileCount === 0) return !0;
      let resolvedPath = createRequire(path12.join(ctx.config.repoDir, "packages", "harness", "x.cjs")).resolve("duckdb-async"), { Database } = await import(resolvedPath), db = await Database.create(duckdb);
      try {
        if (((await db.all("SELECT COUNT(*) AS cnt FROM meta_migrations"))[0]?.cnt ?? 0) >= fileCount) {
          let hash = await migrationFilesHash(ctx.config.repoDir);
          return hash && await fs11.writeFile(stamp, hash + `
`), !0;
        }
      } finally {
        await db.close();
      }
    } catch {
    }
    return !1;
  },
  async install(ctx) {
    let duckdb = `${ctx.config.repoDir}/_db/knowledge.duckdb`;
    if (!await ctx.runner.pathExists(duckdb))
      throw new Error(
        `prerequisite missing: ${duckdb} required for corpus migrations. Run knowledge-graph module first (it has the same precondition).`
      );
    let result = await ctx.runner.run("pnpm corpus --rebuild-fts", {
      cwd: ctx.config.repoDir,
      allowFailure: !0
    });
    if (result.code !== 0)
      throw new Error(
        `pnpm corpus exited ${result.code}. stderr: ${result.stderr.trim() || "(empty)"} stdout: ${result.stdout.trim().slice(-300) || "(empty)"}`
      );
    let hash = await migrationFilesHash(ctx.config.repoDir);
    hash && await fs11.writeFile(path12.join(ctx.home, STAMP_FILE3), hash + `
`);
  },
  async verify(ctx) {
    return { ok: !0, message: "migrations applied (or already up-to-date)" };
  }
};

// src/modules/knowledge-graph.ts
var knowledgeGraphModule = {
  id: "knowledge-graph",
  description: "Build _db/knowledge_graph.json if missing (`pnpm graph`)",
  tags: ["repo", "corpus"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    return await ctx.runner.pathExists(`${ctx.config.repoDir}/_db/knowledge_graph.json`);
  },
  async install(ctx) {
    let duckdb = `${ctx.config.repoDir}/_db/knowledge.duckdb`;
    if (!await ctx.runner.pathExists(duckdb))
      throw new Error(
        `prerequisite missing: ${duckdb} (76MB) is required to build the knowledge graph. It's git-tracked + allowlisted in .gitignore, so 'git clone' should pull it. Check on this box: ls -la _db/knowledge.duckdb (file should exist + be ~76MB). If it's empty/0-byte, run: git fetch && git checkout origin/main -- _db/knowledge.duckdb`
      );
    let result = await ctx.runner.run("pnpm graph", {
      cwd: ctx.config.repoDir,
      allowFailure: !0
    });
    if (result.code !== 0)
      throw new Error(
        `pnpm graph exited ${result.code}. stderr: ${result.stderr.trim() || "(empty)"} stdout: ${result.stdout.trim().slice(-300) || "(empty)"}`
      );
  },
  async verify(ctx) {
    return await ctx.runner.pathExists(
      `${ctx.config.repoDir}/_db/knowledge_graph.json`
    ) ? { ok: !0, message: "knowledge_graph.json present" } : { ok: !1, message: "knowledge_graph.json missing" };
  }
};

// src/modules/verify-harness.ts
import * as fs12 from "node:fs/promises";
import * as path13 from "node:path";
import { createRequire as createRequire2 } from "node:module";
var STAMP_FILE4 = ".verify-harness-ok", cachedResult, verifyHarnessModule = {
  id: "verify-harness",
  description: "Verify harness can query the corpus (inline DuckDB check, subprocess fallback)",
  tags: ["repo", "verify"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    let stamp = path13.join(ctx.home, STAMP_FILE4), dbPath = path13.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      let [stampStat, dbStat] = await Promise.all([
        fs12.stat(stamp),
        fs12.stat(dbPath)
      ]);
      if (stampStat.mtimeMs >= dbStat.mtimeMs)
        return cachedResult = { ok: !0, message: "corpus reachable (cached)" }, !0;
    } catch {
    }
    return !1;
  },
  async install(ctx) {
    let dbPath = path13.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      let resolvedPath = createRequire2(path13.join(ctx.config.repoDir, "packages", "harness", "x.cjs")).resolve("duckdb-async"), { Database } = await import(resolvedPath), db = await Database.create(dbPath);
      try {
        let rows = await db.all(
          "SELECT id FROM docker.failure_modes WHERE id ILIKE '%oom%' LIMIT 1"
        );
        if (rows.length > 0 && /oom/i.test(rows[0].id))
          cachedResult = { ok: !0, message: "corpus reachable" }, await fs12.writeFile(path13.join(ctx.home, STAMP_FILE4), `ok
`).catch(() => {
          }), ctx.logger.ok("harness corpus query verified (inline)");
        else
          throw new Error("no OOM failure mode found in corpus");
      } finally {
        await db.close();
      }
    } catch {
      ctx.logger.info("inline DuckDB check failed, falling back to subprocess");
      let result = await ctx.runner.run('pnpm harness ask "OOMKilled"', {
        cwd: ctx.config.repoDir,
        allowFailure: !0,
        timeoutMs: 3e4
      }), text = (result.stdout + `
` + result.stderr).trim();
      if (result.code !== 0)
        throw cachedResult = {
          ok: !1,
          message: `harness exit ${result.code}. stderr: ${result.stderr.trim().slice(0, 200) || "(empty)"}`
        }, new Error(cachedResult.message);
      if (!/oom|kill/i.test(text))
        throw cachedResult = { ok: !1, message: `no relevant content. First 200: ${text.slice(0, 200)}` }, new Error("pnpm harness ask returned exit 0 but no oom/kill match in output.");
      cachedResult = { ok: !0, message: "corpus reachable" }, await fs12.writeFile(path13.join(ctx.home, STAMP_FILE4), `ok
`).catch(() => {
      }), ctx.logger.ok("harness ask hit the corpus successfully");
    }
  },
  async verify() {
    return cachedResult ?? { ok: !1, message: "install() did not run" };
  }
};

// src/modules/verify-mcp.ts
import * as fs13 from "node:fs/promises";
import * as path14 from "node:path";
var STAMP_FILE5 = ".verify-mcp-ok", INITIALIZE_REQUEST = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "@domains/bootstrap", version: "0.1.0" }
  }
}), cachedResult2, verifyMcpModule = {
  id: "verify-mcp",
  description: "Verify MCP server entry point + DuckDB accessible (subprocess fallback)",
  tags: ["repo", "verify", "mcp"],
  shouldRun() {
    return !0;
  },
  async isInstalled(ctx) {
    let stamp = path14.join(ctx.home, STAMP_FILE5), mcpEntry = path14.join(ctx.config.repoDir, "packages", "harness-mcp", "src", "index.ts"), dbPath = path14.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      let [stampStat, mcpStat, dbStat] = await Promise.all([
        fs13.stat(stamp),
        fs13.stat(mcpEntry),
        fs13.stat(dbPath)
      ]);
      if (stampStat.mtimeMs >= mcpStat.mtimeMs && stampStat.mtimeMs >= dbStat.mtimeMs)
        return cachedResult2 = { ok: !0, message: "MCP entry point + DuckDB accessible (cached)" }, !0;
    } catch {
    }
    return !1;
  },
  async install(ctx) {
    let mcpEntry = path14.join(ctx.config.repoDir, "packages", "harness-mcp", "src", "index.ts"), dbPath = path14.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      await Promise.all([
        fs13.access(mcpEntry, fs13.constants.R_OK),
        fs13.access(dbPath, fs13.constants.R_OK)
      ]), cachedResult2 = { ok: !0, message: "MCP entry point + DuckDB accessible" }, await fs13.writeFile(path14.join(ctx.home, STAMP_FILE5), `ok
`).catch(() => {
      }), ctx.logger.ok("MCP server verified (inline check)");
    } catch {
      ctx.logger.info("inline MCP check failed, falling back to subprocess");
      let cmd = `printf '%s\\n' '${INITIALIZE_REQUEST}' | pnpm --filter @domains/harness-mcp --silent start 2>/dev/null | head -1`, result = await ctx.runner.run(cmd, {
        cwd: ctx.config.repoDir,
        allowFailure: !0,
        timeoutMs: 3e4
      });
      if (!result.stdout.includes('"jsonrpc"') || !result.stdout.includes('"result"'))
        throw cachedResult2 = {
          ok: !1,
          message: `MCP handshake failed. Got: ${result.stdout.slice(0, 200)}`
        }, new Error(cachedResult2.message);
      cachedResult2 = { ok: !0, message: "MCP server boots + handshakes" }, await fs13.writeFile(path14.join(ctx.home, STAMP_FILE5), `ok
`).catch(() => {
      }), ctx.logger.ok("MCP initialize handshake succeeded");
    }
  },
  async verify() {
    return cachedResult2 ?? { ok: !1, message: "install() did not run" };
  }
};

// src/modules/registry.ts
var PHASES = [
  {
    name: "System packages",
    description: "Apt installs that bring the box up to interview-ready state",
    modules: [aptCoreModule, aptOptionalModule, aptDockerModule, aptK8sModule, aptAwsModule]
  },
  {
    name: "Runtimes",
    description: "Node.js, pnpm, Claude Code CLI",
    modules: [nodeModule, pnpmModule, claudeCodeModule]
  },
  {
    name: "Shell + secrets",
    description: "Productivity tools, bash config (safety functions), API key provisioning",
    modules: [
      ezaModule,
      zoxideModule,
      atuinModule,
      dockerCompletionModule,
      bashrcModule,
      seedHistoryModule,
      anthropicKeyModule,
      interviewNotesModule
    ]
  },
  {
    name: "Repo deps",
    description: "Workspace deps + corpus migrations (sequential \u2014 DuckDB locks)",
    modules: [pnpmInstallModule, corpusMigrateModule, knowledgeGraphModule],
    parallel: !1
  },
  {
    name: "Verify",
    description: "End-to-end smoke tests (parallel)",
    modules: [verifyHarnessModule, verifyMcpModule]
  }
], ALL_MODULES = PHASES.flatMap((p) => p.modules);

// src/index.ts
var logger = new Logger(), GLOBAL_TIMEOUT_MS = 18e4;
async function main() {
  setTimeout(() => {
    logger.fail(
      `TIMEOUT: bootstrap exceeded ${GLOBAL_TIMEOUT_MS / 1e3}s. Aborting. If a module is stalled, retry it individually with --module=<id>.`
    ), process.exit(1);
  }, GLOBAL_TIMEOUT_MS).unref();
  let argv = process.argv.slice(2), parsed;
  try {
    parsed = parseArgs(argv, { cwd: findWorkspaceRoot() });
  } catch (err) {
    return logger.fail(err.message), process.stderr.write(`
${HELP_TEXT}`), 2;
  }
  if (parsed.help || parsed.subcommand === "help")
    return process.stdout.write(HELP_TEXT), 0;
  if (parsed.config.snapshotBuild && parsed.config.sessionMode)
    return logger.fail("--snapshot-build and --session-mode are mutually exclusive"), 2;
  let ctx = {
    config: parsed.config,
    logger,
    runner: new Runner({ dryRun: parsed.config.dryRun, logger }),
    home: os4.homedir()
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
async function runInstallWithLock(ctx) {
  if (ctx.config.sessionMode)
    return logger.step("--session-mode: skipping install, running verify only"), runVerify(ctx);
  let lock;
  try {
    lock = await acquireLock(), logger.info(`acquired bootstrap lock (pid ${lock.pid}, ${lock.path})`);
  } catch (err) {
    if (err instanceof LockHeldError)
      return logger.fail(err.message), 1;
    throw err;
  }
  try {
    return await runInstall(ctx);
  } finally {
    lock !== void 0 && (await lock.release(), logger.info("released bootstrap lock"));
  }
}
async function runInstall(ctx) {
  ctx.config.dryRun && logger.step("DRY RUN \u2014 printing commands; no mutations");
  let modules = selectModules(ctx.config);
  if (modules.length === 0)
    return logger.warn("no modules selected (check --module / --skip-module / --skip-tag)"), 0;
  let installedCache = /* @__PURE__ */ new Map(), preflightPromise = !ctx.config.dryRun && !ctx.config.skipPreflight ? runPreflight({ runner: ctx.runner, logger: ctx.logger, offline: ctx.config.offline }) : Promise.resolve(void 0), installCheckPromise = Promise.all(modules.map(async (mod) => {
    if (mod.shouldRun(ctx.config))
      try {
        installedCache.set(mod.id, await mod.isInstalled(ctx));
      } catch {
        installedCache.set(mod.id, !1);
      }
  })), [preflightResults] = await Promise.all([preflightPromise, installCheckPromise]);
  if (preflightResults !== void 0) {
    logger.step("pre-flight checks");
    let blockers = reportPreflight(preflightResults, logger);
    if (blockers > 0)
      return logger.fail(
        `pre-flight: ${blockers} blocker(s); aborting before modules run. Override with --skip-preflight if you believe this is a false positive.`
      ), 2;
  }
  let needsInstall = modules.filter(
    (m) => m.shouldRun(ctx.config) && (!installedCache.get(m.id) || ctx.config.force)
  ), needsSet = new Set(needsInstall.map((m) => m.id)), etaSec = 0;
  for (let phase of PHASES) {
    let phaseNeeds = phase.modules.filter((m) => needsSet.has(m.id));
    phaseNeeds.length !== 0 && (phase.parallel !== !1 && phaseNeeds.length > 1 ? etaSec += Math.max(...phaseNeeds.map((m) => ETA_PER_MODULE_SEC[m.id] ?? 2)) : etaSec += phaseNeeds.reduce((s, m) => s + (ETA_PER_MODULE_SEC[m.id] ?? 2), 0));
  }
  let etaLabel = needsInstall.length === 0 ? " \u2014 all cached" : ` \u2014 ETA ~${formatDuration(etaSec || 3)}`;
  logger.step(
    `installing ${modules.length} module(s)` + (needsInstall.length < modules.length ? ` (${needsInstall.length} need work)` : "") + etaLabel + (ctx.config.snapshotBuild ? " [snapshot-build: strict mode]" : "") + (ctx.config.onlyModules !== void 0 ? ` (filtered: ${[...ctx.config.onlyModules].join(",")})` : "")
  );
  let results = [], startTotal = Date.now(), globalIdx = 0;
  for (let phase of PHASES) {
    let phaseModules = phase.modules.filter((m) => modules.includes(m));
    if (phaseModules.length === 0) continue;
    let runParallel = phase.parallel !== !1, baseIdx = globalIdx;
    if (runParallel && phaseModules.length > 1) {
      let phasePromises = phaseModules.map(async (mod, j) => {
        let idx = baseIdx + j + 1, t0 = Date.now(), result = await runOne(mod, ctx, idx, modules.length, installedCache), dt = Math.round((Date.now() - t0) / 1e3);
        return dt > 1 && logger.info(`  (${mod.id} took ${dt}s)`), result;
      }), phaseResults = await Promise.all(phasePromises);
      results.push(...phaseResults);
    } else
      for (let j = 0; j < phaseModules.length; j++) {
        let mod = phaseModules[j], idx = baseIdx + j + 1, t0 = Date.now(), result = await runOne(mod, ctx, idx, modules.length, installedCache), dt = Math.round((Date.now() - t0) / 1e3);
        dt > 1 && logger.info(`  (${mod.id} took ${dt}s)`), results.push(result);
      }
    globalIdx += phaseModules.length;
  }
  let totalSec = Math.round((Date.now() - startTotal) / 1e3);
  if (printSummary(results, totalSec), ctx.config.snapshotBuild) {
    let nonOptionalFailed = results.filter(
      (r) => r.kind === "failed" && !isOptionalModule(r.id)
    );
    if (nonOptionalFailed.length > 0)
      return logger.fail(
        `[--snapshot-build] ${nonOptionalFailed.length} required module(s) failed: ` + nonOptionalFailed.map((r) => r.id).join(",")
      ), 1;
  }
  return ctx.config.launch ? await execLaunch(ctx, results) : results.some(
    (r) => r.kind === "failed" && !isOptionalModule(r.id)
  ) ? 1 : 0;
}
function selectModules(config) {
  return ALL_MODULES.filter((m) => {
    if (config.skipModules.has(m.id) || config.onlyModules !== void 0 && !config.onlyModules.has(m.id)) return !1;
    if (m.tags !== void 0) {
      for (let t of m.tags)
        if (config.skipTags.has(t)) return !1;
    }
    return !0;
  });
}
async function runOne(mod, ctx, idx, total, installedCache) {
  let log = ctx.logger.child(`${idx}/${total} ${mod.id}`);
  if (!mod.shouldRun(ctx.config))
    return log.skip("shouldRun=false (gated by config flags)"), { kind: "skipped", id: mod.id, reason: "shouldRun=false" };
  if ((installedCache.get(mod.id) ?? !1) && !ctx.config.force) {
    log.ok("already installed (use --force to re-run)");
    let v2 = await safeVerify(mod, ctx);
    return v2.ok ? { kind: "already-installed", id: mod.id } : (log.warn(`verify failed: ${v2.message}`), { kind: "failed", id: mod.id, error: `verify after skip: ${v2.message}` });
  }
  log.step(mod.description);
  let snapshot;
  if (mod.snapshotState !== void 0)
    try {
      snapshot = await mod.snapshotState({ ...ctx, logger: log });
    } catch (err) {
      log.warn(`snapshotState() threw: ${err.message} \u2014 rollback unavailable`), snapshot = void 0;
    }
  try {
    await mod.install({ ...ctx, logger: log });
  } catch (err) {
    let msg = err.message;
    if (log.fail(`install failed: ${msg}`), mod.rollback !== void 0 && snapshot !== void 0) {
      log.warn("attempting rollback...");
      try {
        await mod.rollback({ ...ctx, logger: log }, snapshot), log.ok("rollback complete");
      } catch (rerr) {
        log.fail(`rollback ALSO failed: ${rerr.message}`);
      }
    }
    return { kind: "failed", id: mod.id, error: msg };
  }
  let v = await safeVerify(mod, ctx);
  return v.ok ? (log.ok(v.message), { kind: "ok", id: mod.id, verifyMessage: v.message }) : (log.fail(`verify after install failed: ${v.message}`), { kind: "failed", id: mod.id, error: v.message });
}
async function safeVerify(mod, ctx) {
  try {
    return await mod.verify(ctx);
  } catch (err) {
    return { ok: !1, message: `verify threw: ${err.message}` };
  }
}
async function runVerify(ctx) {
  let modules = selectModules(ctx.config);
  logger.step(
    `verifying ${modules.length} module(s)` + (ctx.config.sessionMode ? " [session-mode]" : "")
  );
  let results = [], i = 0;
  for (let mod of modules) {
    if (i++, !mod.shouldRun(ctx.config)) {
      results.push({ kind: "skipped", id: mod.id, reason: "shouldRun=false" });
      continue;
    }
    let log = ctx.logger.child(`${i}/${modules.length} ${mod.id}`), v = await safeVerify(mod, ctx);
    v.ok ? (log.ok(v.message), results.push({ kind: "ok", id: mod.id, verifyMessage: v.message })) : (log.fail(v.message), results.push({ kind: "failed", id: mod.id, error: v.message }));
  }
  return printSummary(results, 0), results.some(
    (r) => r.kind === "failed" && !isOptionalModule(r.id)
  ) ? 1 : 0;
}
async function runList(ctx) {
  process.stdout.write(`
  ${ALL_MODULES.length} modules registered (${ctx.config.repoDir})

`);
  for (let mod of ALL_MODULES) {
    let state;
    if (!mod.shouldRun(ctx.config))
      state = "SKIP   (gated)";
    else
      try {
        state = await mod.isInstalled(ctx) ? "INSTALLED" : "NEEDED";
      } catch {
        state = "UNKNOWN";
      }
    let tags = mod.tags !== void 0 ? `[${mod.tags.join(",")}]` : "";
    process.stdout.write(
      `  ${state.padEnd(14)} ${mod.id.padEnd(22)} ${mod.description} ${tags}
`
    );
  }
  return process.stdout.write(`
`), 0;
}
async function runLandmines(ctx) {
  return (await ctx.runner.run("bash -lic 'bashrc-landmines'", {
    stream: !0,
    allowFailure: !0
  })).code;
}
async function runKey(ctx, argv) {
  let idx = argv.indexOf("key"), action = idx >= 0 ? argv[idx + 1] : void 0;
  if (action === "show")
    try {
      let { key, source } = await loadAnthropicKey({
        fromFlag: ctx.config.anthropicKey,
        logger,
        interactive: !1,
        offerPersist: !1
      });
      return process.stdout.write(`
  Anthropic key: ${mask(key)}
  Source: ${source}

`), 0;
    } catch (err) {
      if (err instanceof NoAnthropicKeyError)
        return logger.fail(err.message), 1;
      throw err;
    }
  if (action === "set" || action === void 0) {
    if (process.stdin.isTTY !== !0)
      return logger.fail(
        "`key set` requires a TTY (it prompts for the key with hidden input). For non-interactive use, pass --anthropic-key=KEY or set ANTHROPIC_API_KEY."
      ), 2;
    logger.step("Enter your Anthropic API key (input hidden). Ctrl-C to cancel.");
    let { key } = await loadAnthropicKey({
      fromFlag: void 0,
      // ignore flag here — we WANT the prompt
      logger,
      interactive: !0,
      offerPersist: !1
    });
    return await persistKey(key), logger.ok(`saved to ${configFilePath()} (chmod 600, parent dir chmod 700)`), logger.info("verify with: pnpm bootstrap key show"), 0;
  }
  return action === "encrypt" ? await runKeyEncrypt(ctx) : (logger.fail(`unknown key action: ${String(action)} (try 'set', 'show', or 'encrypt')`), 2);
}
async function runKeyEncrypt(ctx) {
  if (process.stdin.isTTY !== !0)
    return logger.fail("`key encrypt` requires a TTY for the hidden key input"), 2;
  if (!await ctx.runner.commandExists("age"))
    return logger.fail(
      "age binary not found on PATH. Install with: sudo apt install age (Linux), brew install age (macOS), or `pnpm bootstrap install --module=apt-core`."
    ), 1;
  let fs14 = await import("node:fs/promises"), path15 = await import("node:path"), candidates = [
    path15.join(ctx.home, ".ssh", "id_ed25519.pub"),
    path15.join(ctx.home, ".ssh", "id_ecdsa.pub"),
    path15.join(ctx.home, ".ssh", "id_rsa.pub")
  ], pubKey;
  for (let c of candidates)
    try {
      await fs14.access(c), pubKey = c;
      break;
    } catch {
    }
  if (pubKey === void 0)
    return logger.fail(
      "no SSH PUBLIC key found at ~/.ssh/{id_ed25519,id_ecdsa,id_rsa}.pub. Generate one: ssh-keygen -t ed25519 -C 'your-email'"
    ), 1;
  logger.info(`encrypting with ${pubKey}`), logger.step("Enter your Anthropic API key (input hidden). Ctrl-C to cancel.");
  let { key } = await loadAnthropicKey({
    fromFlag: void 0,
    logger,
    interactive: !0,
    offerPersist: !1
  }), target = path15.join(ctx.config.repoDir, "_secrets", "anthropic-key.age");
  await fs14.mkdir(path15.dirname(target), { recursive: !0 });
  let { spawn: spawn2 } = await import("node:child_process"), result = await new Promise((resolve3) => {
    let child = spawn2("age", ["-R", pubKey, "-o", target], {
      stdio: ["pipe", "pipe", "pipe"]
    }), stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    }), child.on("close", (code) => resolve3({ code: code ?? 1, stderr })), child.stdin.write(key), child.stdin.end();
  });
  return result.code !== 0 ? (logger.fail(`age encrypt failed (exit ${result.code}): ${result.stderr.trim()}`), 1) : (logger.ok(`wrote ${target}`), logger.info(""), logger.info("Next steps (one-time):"), logger.info(`  git add ${path15.relative(ctx.config.repoDir, target)}`), logger.info("  git commit -m 'ship encrypted anthropic key'"), logger.info("  git push"), logger.info(""), logger.info(
    "After that, every box with your SSH private key gets the API key zero-paste via `./bootstrap.sh install`."
  ), 0);
}
async function execLaunch(ctx, results) {
  if (results.some(
    (r) => r.kind === "failed" && !isOptionalModule(r.id)
  ))
    return logger.warn("not launching claude \u2014 required modules failed (see summary above)"), 1;
  if (ctx.config.anthropicKey === void 0 && process.env.ANTHROPIC_API_KEY === void 0 && process.stdin.isTTY !== !0)
    return logger.fail(
      "--launch requires an Anthropic key (no TTY available for interactive prompt). Pass --anthropic-key=KEY or set ANTHROPIC_API_KEY env, or run `pnpm bootstrap key set` first."
    ), 2;
  let { key, source } = await loadAnthropicKey({
    fromFlag: ctx.config.anthropicKey,
    logger,
    interactive: !0,
    // Skip persist prompt when key came from the flag — passing --anthropic-key
    // signals one-shot intent (typical for fresh-DevBox installs each session).
    // Persist offer still fires when key arrives via the interactive prompt.
    offerPersist: ctx.config.anthropicKey === void 0
  });
  logger.step(`exec'ing claude (key from ${source}: ${mask(key)})`);
  let { spawn: spawn2 } = await import("node:child_process");
  return spawn2("claude", ["--model", "claude-opus-4-7", "--effort", "max"], {
    stdio: "inherit",
    env: { ...process.env, ANTHROPIC_API_KEY: key }
  }).on("exit", (code) => process.exit(code ?? 0)), await new Promise(() => {
  });
}
function printSummary(results, totalSec) {
  process.stdout.write(`
=== summary ===
`);
  let ok = 0, already = 0, skipped = 0, failed = 0, warned = 0, failedIds = [];
  for (let r of results)
    switch (r.kind) {
      case "ok":
        process.stdout.write(`  OK       ${r.id.padEnd(22)} ${r.verifyMessage}
`), ok++;
        break;
      case "already-installed":
        process.stdout.write(`  SKIP/IN  ${r.id.padEnd(22)} already installed
`), already++;
        break;
      case "skipped":
        process.stdout.write(`  SKIP     ${r.id.padEnd(22)} ${r.reason}
`), skipped++;
        break;
      case "failed":
        isOptionalModule(r.id) ? (process.stdout.write(`  WARN     ${r.id.padEnd(22)} ${r.error} (optional)
`), warned++) : (process.stdout.write(`  FAIL     ${r.id.padEnd(22)} ${r.error}
`), failed++, failedIds.push(r.id));
        break;
    }
  let totalLine = totalSec > 0 ? ` (took ${formatDuration(totalSec)})` : "", parts = [`${ok} ok`, `${already} already`, `${skipped} skipped`];
  warned > 0 && parts.push(`${warned} warned`), failed > 0 && parts.push(`${failed} failed`), process.stdout.write(`
  ${parts.join(" | ")}${totalLine}
`), failed > 0 && (process.stdout.write(`
  Retry failed module(s) with:
`), process.stdout.write(`    pnpm bootstrap install --module=${failedIds.join(",")}
`)), process.stdout.write(`
`);
}
function isOptionalModule(id) {
  return ALL_MODULES.find((m) => m.id === id)?.tags?.includes("optional") ?? !1;
}
var ETA_PER_MODULE_SEC = {
  "apt-core": 5,
  "apt-optional": 2,
  "apt-docker": 5,
  "apt-k8s": 3,
  "apt-aws": 5,
  node: 1,
  pnpm: 1,
  "claude-code": 3,
  eza: 2,
  zoxide: 2,
  atuin: 2,
  "seed-history": 1,
  "docker-completion": 1,
  "interview-notes": 1,
  bashrc: 1,
  "anthropic-key": 1,
  "pnpm-install": 2,
  "corpus-migrate": 1,
  "knowledge-graph": 1,
  "verify-harness": 2,
  "verify-mcp": 2
};
function formatDuration(sec) {
  if (sec < 60) return `${sec}s`;
  let m = Math.floor(sec / 60), s = sec % 60;
  return s === 0 ? `${m}m` : `${m}m${s}s`;
}
main().then(
  (code) => process.exit(code),
  (err) => {
    logger.fail(`uncaught: ${err.stack ?? err}`), process.exit(1);
  }
);
