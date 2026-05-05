// Module: verify-harness — end-to-end check that the harness CLI can hit
// the corpus and return a known failure-mode. Runs once per bootstrap;
// install() does the work and caches the result for verify().

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

let cachedResult: { readonly ok: boolean; readonly message: string } | undefined;

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
    const result = await ctx.runner.run('pnpm harness ask "OOMKilled"', {
      cwd: ctx.config.repoDir,
      allowFailure: true,
      timeoutMs: 30_000,
    });
    const text = (result.stdout + "\n" + result.stderr).trim();
    if (result.code !== 0) {
      cachedResult = {
        ok: false,
        message: `harness exit ${result.code}. stderr: ${result.stderr.trim().slice(0, 200) || "(empty)"}`,
      };
      throw new Error(
        `pnpm harness ask exited ${result.code}. ` +
          `stderr: ${result.stderr.trim() || "(empty)"} ` +
          `stdout (last 300): ${result.stdout.trim().slice(-300) || "(empty)"}`,
      );
    }
    if (!/oom|kill/i.test(text)) {
      cachedResult = { ok: false, message: `no relevant content. First 200: ${text.slice(0, 200)}` };
      throw new Error(`pnpm harness ask returned exit 0 but no oom/kill match in output.`);
    }
    cachedResult = { ok: true, message: "corpus reachable" };
    ctx.logger.ok("harness ask hit the corpus successfully");
  },

  async verify(): Promise<VerifyResult> {
    return cachedResult ?? { ok: false, message: "install() did not run" };
  },
};
