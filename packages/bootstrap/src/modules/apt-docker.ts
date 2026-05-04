// Module: apt-docker — install docker.io + plugins. Gated on --with-docker.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const aptDockerModule: InstallerModule = {
  id: "apt-docker",
  description: "Docker engine + compose plugin (gated on --with-docker)",
  tags: ["apt", "docker", "optional"],

  shouldRun(config): boolean {
    return process.platform === "linux" && config.withDocker;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("docker");
  },

  async install(ctx: InstallContext): Promise<void> {
    await ctx.runner.run(
      "DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin containerd uidmap",
      { sudo: true, stream: true },
    );
    const user = process.env["USER"] ?? process.env["LOGNAME"] ?? "";
    if (user !== "" && user !== "root") {
      await ctx.runner.run(`usermod -aG docker ${user}`, { sudo: true, allowFailure: true });
      ctx.logger.warn(
        "you'll need to log out + back in for docker group membership to take effect",
      );
    }
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("docker"))) {
      return { ok: false, message: "docker not on PATH" };
    }
    return { ok: true, message: "docker installed" };
  },
};
