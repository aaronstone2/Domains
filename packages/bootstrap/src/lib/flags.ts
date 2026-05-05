// Typed CLI flag parser. Replaces the bash `case "$1" in ... esac` dance from
// the legacy script. Single source of truth for flag names + types.

import * as path from "node:path";

import type { BootstrapConfig } from "./types.ts";

export type Subcommand = "install" | "verify" | "list" | "landmines" | "key" | "help";

export interface ParsedArgs {
  readonly subcommand: Subcommand;
  readonly config: BootstrapConfig;
  readonly help: boolean;
}

export interface ParseOptions {
  /** Default repoDir if --repo isn't passed. Usually process.cwd(). */
  readonly cwd: string;
}

/**
 * Parse argv into a typed config. Argv should NOT include the node binary
 * or script name (i.e. pass `process.argv.slice(2)`).
 *
 * Recognized flags:
 *   <subcommand>                  install | verify | list | landmines | help
 *   --module=ID[,ID...]           run only these modules
 *   --skip-module=ID[,ID...]      skip these modules
 *   --dry-run                     print commands, no mutation
 *   --no-claude                   skip claude-code install
 *   --no-shell-config             skip bashrc edit
 *   --minimal                     skip optional heavy apt packages
 *   --with-docker                 install docker.io
 *   --with-k8s                    install kubectl
 *   --with-aws                    install aws-cli v2
 *   --launch                      exec `claude` after install
 *   --anthropic-key=KEY           Anthropic key (for --launch)
 *   --anthropic-key KEY           same, two-arg form
 *   --repo=PATH                   path to the domains repo (default: cwd)
 *   --force                       run modules even if isInstalled() is true
 *   --help, -h                    show help and exit
 */
export function parseArgs(argv: readonly string[], opts: ParseOptions): ParsedArgs {
  // Strip POSIX flag-terminator '--' if pnpm passed it through. Some pnpm
  // versions strip it before exec'ing the script; others don't. Filtering
  // here makes the parser version-agnostic.
  argv = argv.filter((a) => a !== "--");

  let subcommand: Subcommand = "install";
  let dryRun = false;
  let noClaude = false;
  let noShellConfig = false;
  let minimal = false;
  let withDocker = false;
  let withK8s = false;
  let withAws = false;
  let launch = false;
  let anthropicKey: string | undefined;
  let repoDir = opts.cwd;
  let onlyModules: Set<string> | undefined;
  const skipModules: Set<string> = new Set();
  const skipTags: Set<string> = new Set();
  let force = false;
  let help = false;
  let snapshotBuild = false;
  let sessionMode = false;
  let offline = false;

  let i = 0;
  // First positional: subcommand
  const first = argv[0];
  if (first !== undefined && !first.startsWith("-")) {
    if (
      first === "install" ||
      first === "verify" ||
      first === "list" ||
      first === "landmines" ||
      first === "key" ||
      first === "help"
    ) {
      subcommand = first;
      i = 1;
    }
  }

  for (; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === undefined) break;
    const [key, inlineValue] = splitFlag(arg);

    switch (key) {
      case "--dry-run":
        dryRun = true;
        break;
      case "--no-claude":
        noClaude = true;
        break;
      case "--no-shell-config":
        noShellConfig = true;
        break;
      case "--minimal":
        minimal = true;
        break;
      case "--with-docker":
        withDocker = true;
        break;
      case "--with-k8s":
        withK8s = true;
        break;
      case "--with-aws":
        withAws = true;
        break;
      case "--launch":
        launch = true;
        break;
      case "--force":
        force = true;
        break;
      case "--snapshot-build":
        snapshotBuild = true;
        break;
      case "--session-mode":
        sessionMode = true;
        break;
      case "--offline":
        offline = true;
        break;
      case "--skip-tag": {
        const tags = (inlineValue ?? takeNext(argv, i++, "--skip-tag")).split(",").filter((s) => s !== "");
        for (const t of tags) skipTags.add(t);
        break;
      }
      case "--help":
      case "-h":
        help = true;
        break;
      case "--anthropic-key":
        anthropicKey = inlineValue ?? takeNext(argv, i++, "--anthropic-key");
        break;
      case "--repo":
        repoDir = path.resolve(inlineValue ?? takeNext(argv, i++, "--repo"));
        break;
      case "--module": {
        const ids = (inlineValue ?? takeNext(argv, i++, "--module")).split(",").filter((s) => s !== "");
        if (onlyModules === undefined) onlyModules = new Set();
        for (const id of ids) onlyModules.add(id);
        break;
      }
      case "--skip-module": {
        const ids = (inlineValue ?? takeNext(argv, i++, "--skip-module"))
          .split(",")
          .filter((s) => s !== "");
        for (const id of ids) skipModules.add(id);
        break;
      }
      default:
        if (arg.startsWith("-")) {
          throw new Error(`Unknown flag: ${arg}`);
        }
        // ignore unknown positional (shouldn't happen — subcommand consumed first)
        break;
    }
  }

  const config: BootstrapConfig = {
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
    skipTags,
  };

  return { subcommand, config, help };
}

function splitFlag(arg: string): [string, string | undefined] {
  const eq = arg.indexOf("=");
  if (eq < 0) return [arg, undefined];
  return [arg.slice(0, eq), arg.slice(eq + 1)];
}

function takeNext(argv: readonly string[], i: number, name: string): string {
  const next = argv[i + 1];
  if (next === undefined || next.startsWith("-")) {
    throw new Error(`${name} requires a value`);
  }
  return next;
}

export const HELP_TEXT: string = `domains-bootstrap — modular DevBox installer

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
