// Module: zoxide — smarter cd. Apt first, fall back to upstream installer.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const zoxideModule: InstallerModule = {
  id: "zoxide",
  description: "zoxide (smarter cd, frecency-based). apt → upstream installer fallback.",
  tags: ["shell", "productivity"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("zoxide");
  },

  async install(ctx: InstallContext): Promise<void> {
    const aptResult = await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y zoxide",
      { sudo: true, allowFailure: true },
    );
    if (aptResult.code === 0 && (await ctx.runner.commandExists("zoxide"))) {
      return;
    }
    ctx.logger.info("apt zoxide unavailable; falling back to upstream installer");
    await ctx.runner.run(
      "curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash",
      { stream: true },
    );
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("zoxide"))) {
      return { ok: false, message: "zoxide not on PATH (might need new shell to pick up PATH)" };
    }
    return { ok: true, message: "zoxide installed" };
  },
};
