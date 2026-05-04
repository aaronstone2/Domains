// Module: pnpm — global pnpm via npm. Required for `pnpm bootstrap` to run
// (chicken/egg avoided by the trampoline ensuring it's present before we
// even reach this module; this module exists to ensure idempotency on
// re-runs and to verify on a fresh DevBox).

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const pnpmModule: InstallerModule = {
  id: "pnpm",
  description: "pnpm package manager (global, via npm)",
  tags: ["runtime"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("pnpm");
  },

  async install(ctx: InstallContext): Promise<void> {
    if (!(await ctx.runner.commandExists("npm"))) {
      throw new Error("npm not found — run the 'node' module first");
    }
    await ctx.runner.run("npm install -g pnpm", { sudo: true, stream: true });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("pnpm"))) {
      return { ok: false, message: "pnpm not on PATH" };
    }
    const version = await ctx.runner.capture("pnpm --version");
    return { ok: true, message: `pnpm ${version.trim()}` };
  },
};
