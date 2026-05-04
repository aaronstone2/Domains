// Runner — single shell-exec abstraction. Wraps child_process.spawn so every
// module uses the same code path for sudo, dry-run, output streaming, and
// error capture. Replaces the bash `$SUDO`, `command -v`, and inline
// subshell patterns scattered across the legacy script.

import { spawn, type SpawnOptions } from "node:child_process";
import { promisify } from "node:util";
import { exec as execCb } from "node:child_process";

import type { Logger } from "./log.ts";

const exec = promisify(execCb);

export interface RunResult {
  readonly stdout: string;
  readonly stderr: string;
  readonly code: number;
}

export interface RunOptions {
  /** Working directory. Defaults to process.cwd(). */
  readonly cwd?: string;
  /** Extra env vars merged onto process.env. */
  readonly env?: Readonly<Record<string, string>>;
  /** Stream stdout/stderr live to the parent terminal (vs capture only). */
  readonly stream?: boolean;
  /** Use sudo (no-op if running as root). */
  readonly sudo?: boolean;
  /** Custom timeout in ms. */
  readonly timeoutMs?: number;
  /** Don't throw on non-zero exit; let caller inspect result.code. */
  readonly allowFailure?: boolean;
}

export class CommandFailedError extends Error {
  readonly cmd: string;
  readonly code: number;
  readonly stdout: string;
  readonly stderr: string;
  constructor(cmd: string, result: RunResult) {
    super(`command failed (exit ${result.code}): ${cmd}\nstderr: ${result.stderr.trim()}`);
    this.name = "CommandFailedError";
    this.cmd = cmd;
    this.code = result.code;
    this.stdout = result.stdout;
    this.stderr = result.stderr;
  }
}

export class Runner {
  readonly dryRun: boolean;
  private readonly logger: Logger;
  private readonly isRoot: boolean;

  constructor(opts: { readonly dryRun: boolean; readonly logger: Logger }) {
    this.dryRun = opts.dryRun;
    this.logger = opts.logger;
    this.isRoot = process.getuid?.() === 0;
  }

  /**
   * Run a command. By default throws on non-zero exit. Pass allowFailure: true
   * to inspect the result without throwing (useful for `command -v` style
   * existence checks).
   */
  async run(cmd: string, opts: RunOptions = {}): Promise<RunResult> {
    const finalCmd = this.maybeSudoWrap(cmd, opts.sudo === true);

    if (this.dryRun) {
      this.logger.info(`[dry-run] ${finalCmd}`);
      return { stdout: "", stderr: "", code: 0 };
    }

    if (opts.stream === true) {
      return this.runStreaming(finalCmd, opts);
    }
    return this.runCaptured(finalCmd, opts);
  }

  /**
   * Existence check via `command -v <bin>`. Returns true if the binary is on
   * PATH. Never throws.
   */
  async commandExists(bin: string): Promise<boolean> {
    const result = await this.run(`command -v ${shellQuote(bin)} >/dev/null 2>&1`, {
      allowFailure: true,
    });
    return result.code === 0;
  }

  /**
   * Capture stdout from a command. Convenience for `result.stdout.trim()`.
   * Throws on failure (not pass-through).
   */
  async capture(cmd: string, opts: Omit<RunOptions, "stream"> = {}): Promise<string> {
    const result = await this.run(cmd, { ...opts, stream: false });
    return result.stdout.trim();
  }

  /** Returns true if `path` exists; resolves symlinks. Never throws. */
  async pathExists(path: string): Promise<boolean> {
    const result = await this.run(`test -e ${shellQuote(path)}`, { allowFailure: true });
    return result.code === 0;
  }

  /** Append text to a file (creates if missing). Honors dryRun. */
  async appendFile(path: string, content: string): Promise<void> {
    if (this.dryRun) {
      this.logger.info(`[dry-run] append ${content.length} bytes to ${path}`);
      return;
    }
    const fs = await import("node:fs/promises");
    await fs.mkdir(pathDirname(path), { recursive: true });
    await fs.appendFile(path, content);
  }

  /**
   * Write file atomically (write-to-tmp + rename). Honors dryRun.
   * Use `mode: 0o600` for secrets.
   *
   * The atomic part matters because crashing mid-write to ~/.bashrc would
   * leave a truncated file that breaks the next shell launch.
   */
  async writeFile(
    path: string,
    content: string,
    opts: { readonly mode?: number; readonly fsync?: boolean } = {},
  ): Promise<void> {
    if (this.dryRun) {
      this.logger.info(`[dry-run] write ${content.length} bytes to ${path}`);
      return;
    }
    const { atomicWrite } = await import("./atomic-write.ts");
    await atomicWrite(path, content, opts);
  }

  // -- internals --

  private maybeSudoWrap(cmd: string, wantSudo: boolean): string {
    if (!wantSudo || this.isRoot) return cmd;
    return `sudo ${cmd}`;
  }

  private async runCaptured(cmd: string, opts: RunOptions): Promise<RunResult> {
    try {
      const { stdout, stderr } = await exec(cmd, {
        cwd: opts.cwd,
        env: { ...process.env, ...(opts.env ?? {}) },
        timeout: opts.timeoutMs,
        maxBuffer: 10 * 1024 * 1024,
      });
      return { stdout, stderr, code: 0 };
    } catch (err) {
      const e = err as { code?: number; stdout?: string; stderr?: string };
      const result: RunResult = {
        stdout: e.stdout ?? "",
        stderr: e.stderr ?? "",
        code: e.code ?? 1,
      };
      if (opts.allowFailure === true) return result;
      throw new CommandFailedError(cmd, result);
    }
  }

  private runStreaming(cmd: string, opts: RunOptions): Promise<RunResult> {
    return new Promise((resolve, reject) => {
      const spawnOpts: SpawnOptions = {
        cwd: opts.cwd,
        env: { ...process.env, ...(opts.env ?? {}) },
        shell: true,
        stdio: "inherit",
      };
      const child = spawn(cmd, spawnOpts);
      const timer =
        opts.timeoutMs !== undefined
          ? setTimeout(() => child.kill("SIGTERM"), opts.timeoutMs)
          : undefined;
      child.on("close", (code) => {
        if (timer !== undefined) clearTimeout(timer);
        const result: RunResult = { stdout: "", stderr: "", code: code ?? 1 };
        if (result.code === 0 || opts.allowFailure === true) {
          resolve(result);
        } else {
          reject(new CommandFailedError(cmd, result));
        }
      });
      child.on("error", (err) => reject(err));
    });
  }
}

function shellQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

function pathDirname(p: string): string {
  const i = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"));
  return i < 0 ? "." : p.slice(0, i);
}
