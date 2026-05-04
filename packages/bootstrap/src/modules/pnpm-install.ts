// Module: pnpm-install — install workspace deps so the harness can run.
// This is the prerequisite for the verify-harness module.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const pnpmInstallModule: InstallerModule = {
  id: "pnpm-install",
  description: "pnpm install in the repo root (workspace deps)",
  tags: ["repo"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // node_modules at the repo root is the cheap signal. Not perfect (could
    // be partial install) but adequate; install() is fast on no-op anyway.
    return await ctx.runner.pathExists(`${ctx.config.repoDir}/node_modules`);
  },

  async install(ctx: InstallContext): Promise<void> {
    await ctx.runner.run("pnpm install --silent --frozen-lockfile", {
      cwd: ctx.config.repoDir,
      stream: true,
    });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const harnessDir = `${ctx.config.repoDir}/packages/harness/node_modules`;
    if (!(await ctx.runner.pathExists(harnessDir))) {
      return { ok: false, message: "harness/node_modules missing — pnpm install incomplete" };
    }
    return { ok: true, message: "workspace deps present" };
  },
};
