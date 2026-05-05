// Module: verify-harness — end-to-end check that the harness CLI can hit
// the corpus and return a known failure-mode. Doubles as proof the install
// actually works.
//
// FIX (v1.2): legacy version captured combined stdout+stderr via `2>&1` then
// piped through head, which sometimes truncated the actual error before we
// could read it. New version captures stdout+stderr separately and reports
// both, plus the exit code, so failures are debuggable from the install
// summary alone.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

async function runHarnessAsk(ctx: InstallContext): Promise<{
  readonly stdout: string;
  readonly stderr: string;
  readonly code: number;
  readonly text: string;
}> {
  const result = await ctx.runner.run('pnpm harness ask "OOMKilled"', {
    cwd: ctx.config.repoDir,
    allowFailure: true,
    timeoutMs: 30_000,
  });
  return {
    stdout: result.stdout,
    stderr: result.stderr,
    code: result.code,
    text: (result.stdout + "\n" + result.stderr).trim(),
  };
}

export const verifyHarnessModule: InstallerModule = {
  id: "verify-harness",
  description: "End-to-end: `pnpm harness ask 'OOMKilled'` returns a docker failure-mode",
  tags: ["repo", "verify"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(): Promise<boolean> {
    return false; // always re-run; fast + idempotent
  },

  async install(ctx: InstallContext): Promise<void> {
    const r = await runHarnessAsk(ctx);
    if (r.code !== 0) {
      throw new Error(
        `pnpm harness ask exited ${r.code}. ` +
          `stderr: ${r.stderr.trim() || "(empty)"} ` +
          `stdout (last 300): ${r.stdout.trim().slice(-300) || "(empty)"}`,
      );
    }
    if (!/oom|kill/i.test(r.text)) {
      throw new Error(
        `pnpm harness ask returned exit 0 but no oom/kill match in output. ` +
          `Output (first 500): ${r.text.slice(0, 500)}`,
      );
    }
    ctx.logger.ok("harness ask hit the corpus successfully");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const r = await runHarnessAsk(ctx);
    if (r.code !== 0) {
      return {
        ok: false,
        message: `harness exit ${r.code}. stderr: ${r.stderr.trim().slice(0, 200) || "(empty)"}`,
      };
    }
    return /oom|kill/i.test(r.text)
      ? { ok: true, message: "corpus reachable" }
      : { ok: false, message: `query returned no relevant content. First 200: ${r.text.slice(0, 200)}` };
  },
};
