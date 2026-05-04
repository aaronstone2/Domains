// Core types — every installer module conforms to InstallerModule.
//
// The orchestrator (src/index.ts) treats modules as opaque units: it knows
// only this interface, not the specific tool. New modules drop into
// src/modules/, register in registry.ts, and Just Work.

import type { Logger } from "./log.ts";
import type { Runner } from "./runner.ts";

/**
 * User-facing flags + derived config. Built once from argv and threaded into
 * every module so they can decide whether to run, where to write, etc.
 */
export interface BootstrapConfig {
  /** Repo absolute path. Defaults to the directory containing bootstrap.sh. */
  readonly repoDir: string;
  /** Don't actually mutate anything; just print the commands. */
  readonly dryRun: boolean;
  /** Skip claude-code npm install. */
  readonly noClaude: boolean;
  /** Skip the bashrc-block edit. */
  readonly noShellConfig: boolean;
  /** Skip optional heavy apt packages (eBPF, perf, headers). */
  readonly minimal: boolean;
  /** Install docker.io + plugins. */
  readonly withDocker: boolean;
  /** Install kubectl. */
  readonly withK8s: boolean;
  /** Install aws-cli v2. */
  readonly withAws: boolean;
  /** Anthropic key — passed through to `claude` if --launch is set. */
  readonly anthropicKey: string | undefined;
  /** Exec into `claude` after a successful install. */
  readonly launch: boolean;
  /** Only run modules whose id is in this set; if undefined, run all. */
  readonly onlyModules: ReadonlySet<string> | undefined;
  /** Skip modules whose id is in this set. */
  readonly skipModules: ReadonlySet<string>;
  /** Force-rerun modules even if isInstalled() returns true. */
  readonly force: boolean;
  /**
   * Snapshot-build mode: every required module MUST succeed; soft failures
   * become hard. Used for the DevBox blueprint `initialize:` step where a
   * partial install poisons the snapshot.
   */
  readonly snapshotBuild: boolean;
  /**
   * Session-mode: verify only, no installs. Used for the DevBox blueprint
   * `maintenance:` step or any sanity-check on session start.
   */
  readonly sessionMode: boolean;
  /**
   * Skip network-dependent preflight checks. Useful when running offline
   * with a pre-warmed apt cache + node_modules.
   */
  readonly offline: boolean;
  /**
   * Skip modules with this tag (e.g. --skip-tag=productivity excludes
   * eza/zoxide/atuin which add no diagnostic value).
   */
  readonly skipTags: ReadonlySet<string>;
}

/**
 * Per-invocation context — what every module needs to do its work without
 * reaching into globals or the filesystem directly.
 */
export interface InstallContext {
  readonly config: BootstrapConfig;
  readonly logger: Logger;
  readonly runner: Runner;
  /** OS user's home directory, resolved once. */
  readonly home: string;
}

/**
 * Result of a verify step. Modules return ok=false with a non-empty message
 * when their post-state check fails.
 */
export interface VerifyResult {
  readonly ok: boolean;
  readonly message: string;
}

/**
 * The unit of installation. Each tool, apt package set, bashrc edit, etc. is
 * one InstallerModule. Single-responsibility — if a module covers more than
 * one concern, split it.
 */
export interface InstallerModule {
  /**
   * CLI-stable identifier. Used in --module=X filtering and the retry
   * suggestion printed at end-of-run on failure.
   */
  readonly id: string;
  /** One-line description shown by `pnpm bootstrap list`. */
  readonly description: string;
  /** Free-form tags ("shell", "apt", "interactive") for grouping/filters. */
  readonly tags?: readonly string[];

  /**
   * Decide whether this module should run for the given config. Returns false
   * for, e.g., apt-docker when --with-docker is not set. The orchestrator
   * skips modules whose shouldRun is false (they appear as "skipped" in the
   * summary).
   */
  shouldRun(config: BootstrapConfig): boolean;

  /**
   * Returns true if the module's installable thing is already in place.
   * Used to skip work on re-runs (unless --force).
   */
  isInstalled(ctx: InstallContext): Promise<boolean>;

  /**
   * Do the actual install. Must be idempotent — running install() on a system
   * where isInstalled() returned true should be safe and fast (the orchestrator
   * does not call install() when already installed unless --force, but errors
   * are not fatal).
   */
  install(ctx: InstallContext): Promise<void>;

  /**
   * Post-install verification. Run after install(). If returns ok=false, the
   * module is marked failed in the summary even if install() didn't throw.
   */
  verify(ctx: InstallContext): Promise<VerifyResult>;

  /**
   * Optional: capture pre-install state so a failed install() can be undone.
   * Called by the orchestrator BEFORE install(). The returned object is
   * passed to rollback() if install() throws.
   *
   * Modules that mutate files (bashrc, docker-completion, anthropic-key)
   * should implement this. Pure-package modules (apt-core, eza) usually
   * don't need to — their idempotent re-install handles partial state.
   */
  snapshotState?(ctx: InstallContext): Promise<unknown>;

  /**
   * Optional: undo install() partial work using state captured by
   * snapshotState(). Best-effort — log and continue if rollback itself fails.
   */
  rollback?(ctx: InstallContext, state: unknown): Promise<void>;
}

/** Status returned by the orchestrator for one module. */
export type ModuleStatus =
  | { readonly kind: "ok"; readonly id: string; readonly verifyMessage: string }
  | { readonly kind: "skipped"; readonly id: string; readonly reason: string }
  | { readonly kind: "already-installed"; readonly id: string }
  | { readonly kind: "failed"; readonly id: string; readonly error: string };

/** Single-source-of-truth for the bashrc block markers. */
export const BASHRC_MARKER_BEGIN: string = "# >>> domains-bootstrap >>>";
export const BASHRC_MARKER_END: string = "# <<< domains-bootstrap <<<";
