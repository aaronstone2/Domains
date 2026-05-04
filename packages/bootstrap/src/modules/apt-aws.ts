// Module: apt-aws — install aws-cli v2 via the official installer.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const aptAwsModule: InstallerModule = {
  id: "apt-aws",
  description: "aws-cli v2 from awscli-exe-linux installer (gated on --with-aws)",
  tags: ["aws", "optional"],

  shouldRun(config): boolean {
    return process.platform === "linux" && config.withAws;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("aws");
  },

  async install(ctx: InstallContext): Promise<void> {
    await ctx.runner.run(
      'curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip',
    );
    await ctx.runner.run("cd /tmp && unzip -q -o awscliv2.zip");
    await ctx.runner.run("/tmp/aws/install --update", { sudo: true });
    await ctx.runner.run("rm -rf /tmp/aws /tmp/awscliv2.zip");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("aws"))) {
      return { ok: false, message: "aws not on PATH" };
    }
    const version = await ctx.runner.capture("aws --version 2>&1 | head -1");
    return { ok: true, message: `aws-cli present (${version.trim()})` };
  },
};
