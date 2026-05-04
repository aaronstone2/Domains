// Module: node — Node.js >= 22 via NodeSource. The harness package needs
// modern Node for ESM + tsx; the legacy bash bootstrap also enforced 22+.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const REQUIRED_MAJOR = 22;

export const nodeModule: InstallerModule = {
  id: "node",
  description: `Node.js >= ${REQUIRED_MAJOR} via NodeSource apt repo`,
  tags: ["runtime"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return (await currentNodeMajor(ctx)) >= REQUIRED_MAJOR;
  },

  async install(ctx: InstallContext): Promise<void> {
    const setupUrl = `https://deb.nodesource.com/setup_${REQUIRED_MAJOR}.x`;
    // NodeSource's setup script needs to run as root and configures the apt repo.
    await ctx.runner.run(`curl -fsSL ${setupUrl} | bash -`, { sudo: true, stream: true });
    await ctx.runner.run("DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs", {
      sudo: true,
      stream: true,
    });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const major = await currentNodeMajor(ctx);
    if (major < REQUIRED_MAJOR) {
      return { ok: false, message: `node major version ${major} < ${REQUIRED_MAJOR}` };
    }
    const version = await ctx.runner.capture("node -v");
    return { ok: true, message: `node ${version}` };
  },
};

async function currentNodeMajor(ctx: InstallContext): Promise<number> {
  if (!(await ctx.runner.commandExists("node"))) return 0;
  const v = await ctx.runner.capture("node -v");
  // node -v prints "vNN.MM.PP"
  const m = /^v(\d+)\./.exec(v);
  if (m === null || m[1] === undefined) return 0;
  return Number.parseInt(m[1], 10);
}
