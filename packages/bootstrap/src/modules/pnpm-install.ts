// Module: pnpm-install — install workspace deps so the harness can run.
// This is the prerequisite for the verify-harness module.
//
// FIX (v1.2): legacy verify() checked `packages/harness/node_modules` which
// is a path that npm/yarn create but pnpm workspaces do NOT. pnpm hoists
// deps to root `node_modules/.pnpm/` and exposes packages via symlinks at
// `node_modules/<pkg>`. The fix uses both signals: (1) the .pnpm virtual
// store exists, (2) `pnpm --filter @domains/harness exec` resolves.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const pnpmInstallModule: InstallerModule = {
  id: "pnpm-install",
  description: "pnpm install in the repo root (workspace deps)",
  tags: ["repo"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // The .pnpm virtual store is the canonical "pnpm install ran cleanly"
    // signal in a pnpm workspace. Plain node_modules can exist without it.
    return await ctx.runner.pathExists(`${ctx.config.repoDir}/node_modules/.pnpm`);
  },

  async install(ctx: InstallContext): Promise<void> {
    // Drop --frozen-lockfile so a minor pnpm-version diff between machines
    // doesn't block the install. Stream output so we see what happens.
    await ctx.runner.run("pnpm install", {
      cwd: ctx.config.repoDir,
      stream: true,
      timeoutMs: 120_000,
    });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    // 1. The pnpm virtual store must exist.
    const pnpmStore = `${ctx.config.repoDir}/node_modules/.pnpm`;
    if (!(await ctx.runner.pathExists(pnpmStore))) {
      return {
        ok: false,
        message: "node_modules/.pnpm missing — pnpm install did not run successfully",
      };
    }
    // 2. Check harness package + a key dependency exist (native fs, ~0.1ms
    //    vs ~480ms for the old `pnpm --filter exec` approach).
    const harnessDir = `${ctx.config.repoDir}/packages/harness/node_modules`;
    if (!(await ctx.runner.pathExists(harnessDir))) {
      return {
        ok: false,
        message: "packages/harness/node_modules missing — workspace deps not installed",
      };
    }
    return { ok: true, message: "workspace deps present + harness ready" };
  },
};
