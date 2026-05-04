// Module: atuin — shell history with TUI search and optional sync. Installed
// via the official setup script which drops binaries to ~/.atuin/bin (no
// sudo needed).

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const atuinModule: InstallerModule = {
  id: "atuin",
  description: "atuin (TUI shell history). User-local install via setup.atuin.sh.",
  tags: ["shell", "productivity"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    if (await ctx.runner.commandExists("atuin")) return true;
    // Setup script may have just dropped the binary in ~/.atuin/bin without
    // re-sourcing PATH yet — check the conventional install path too.
    return await ctx.runner.pathExists(`${ctx.home}/.atuin/bin/atuin`);
  },

  async install(ctx: InstallContext): Promise<void> {
    await ctx.runner.run("curl --proto '=https' --tlsv1.2 -fsSL https://setup.atuin.sh | sh", {
      stream: true,
    });
    if (!(await this.isInstalled(ctx))) {
      throw new Error("atuin install completed but binary not found in expected paths");
    }
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const installed = await this.isInstalled(ctx);
    return installed
      ? { ok: true, message: "atuin installed" }
      : { ok: false, message: "atuin not found after install (need new shell to pick up PATH?)" };
  },
};
