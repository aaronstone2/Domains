// Module: verify-harness — end-to-end check that the harness CLI can hit
// the corpus and return a known failure-mode. Doubles as proof the install
// actually works.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const verifyHarnessModule: InstallerModule = {
  id: "verify-harness",
  description: "End-to-end: `pnpm harness ask 'OOMKilled'` returns a docker failure-mode",
  tags: ["repo", "verify"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(): Promise<boolean> {
    // Always re-run the verify; it's fast (~1-2s) and idempotent.
    return false;
  },

  async install(ctx: InstallContext): Promise<void> {
    const result = await ctx.runner.run('pnpm harness ask "OOMKilled" 2>&1 | head -40', {
      cwd: ctx.config.repoDir,
      allowFailure: true,
    });
    const text = result.stdout + result.stderr;
    if (!/oom|kill/i.test(text)) {
      throw new Error(`harness ask 'OOMKilled' did not return a relevant result. Output:\n${text}`);
    }
    ctx.logger.ok("harness ask hit the corpus successfully");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const result = await ctx.runner.run('pnpm harness ask "OOMKilled" 2>&1 | head -40', {
      cwd: ctx.config.repoDir,
      allowFailure: true,
    });
    const text = result.stdout + result.stderr;
    return /oom|kill/i.test(text)
      ? { ok: true, message: "corpus reachable" }
      : { ok: false, message: "corpus query did not match expected output" };
  },
};
