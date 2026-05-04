// Module: eza — modern ls replacement. Apt first; if too old/missing, fall
// back to a release tarball install to /usr/local/bin.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const ezaModule: InstallerModule = {
  id: "eza",
  description: "eza (modern ls). apt first, fallback to release tarball.",
  tags: ["shell", "productivity"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("eza");
  },

  async install(ctx: InstallContext): Promise<void> {
    const aptResult = await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y eza",
      { sudo: true, allowFailure: true },
    );
    if (aptResult.code === 0 && (await ctx.runner.commandExists("eza"))) {
      return;
    }
    ctx.logger.info("apt eza unavailable; falling back to GitHub release tarball");
    await ctx.runner.run(
      "curl -fsSL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -o /tmp/eza.tar.gz",
    );
    await ctx.runner.run("tar -xzf /tmp/eza.tar.gz -C /tmp");
    await ctx.runner.run("install -o root -g root -m 0755 /tmp/eza /usr/local/bin/eza", { sudo: true });
    await ctx.runner.run("rm -f /tmp/eza /tmp/eza.tar.gz");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("eza"))) {
      return { ok: false, message: "eza not on PATH" };
    }
    return { ok: true, message: "eza installed" };
  },
};
