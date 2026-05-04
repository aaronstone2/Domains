// Module: apt-k8s — install kubectl. Direct binary download from dl.k8s.io.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const aptK8sModule: InstallerModule = {
  id: "apt-k8s",
  description: "kubectl from upstream stable release (gated on --with-k8s)",
  tags: ["k8s", "optional"],

  shouldRun(config): boolean {
    return process.platform === "linux" && config.withK8s;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("kubectl");
  },

  async install(ctx: InstallContext): Promise<void> {
    const version = (
      await ctx.runner.capture("curl -fsSL https://dl.k8s.io/release/stable.txt")
    ).trim();
    if (!/^v\d+\.\d+\.\d+/.test(version)) {
      throw new Error(`unexpected kubectl version string from dl.k8s.io: ${version}`);
    }
    await ctx.runner.run(
      `curl -fsSLo /tmp/kubectl https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl`,
    );
    await ctx.runner.run("install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl", {
      sudo: true,
    });
    await ctx.runner.run("rm -f /tmp/kubectl");
    ctx.logger.ok(`kubectl ${version} installed`);
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("kubectl"))) {
      return { ok: false, message: "kubectl not on PATH" };
    }
    const version = await ctx.runner.capture("kubectl version --client -o yaml | head -3");
    return { ok: true, message: `kubectl present (${version.split("\n")[0]})` };
  },
};
