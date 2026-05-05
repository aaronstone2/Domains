// Module: node — Node.js >= 22. Uses binary tarball for speed (~2s vs ~25s
// for NodeSource apt). Falls back to fnm if the tarball download fails.
//
// The trampoline (bootstrap.sh) already ensures node exists before this
// module runs. This module only fires when the existing version is below
// the required major (e.g. system node is v18).

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const REQUIRED_MAJOR = 22;
const NODE_VERSION = "22.15.0";

export const nodeModule: InstallerModule = {
  id: "node",
  description: `Node.js >= ${REQUIRED_MAJOR} via binary tarball (fnm fallback)`,
  tags: ["runtime"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return (await currentNodeMajor(ctx)) >= REQUIRED_MAJOR;
  },

  async install(ctx: InstallContext): Promise<void> {
    // Strategy 1: binary tarball (fast — ~2s download+extract, no apt needed).
    const tarballOk = await tryBinaryTarball(ctx);
    if (tarballOk && (await currentNodeMajor(ctx)) >= REQUIRED_MAJOR) return;

    // Strategy 2: fnm (fast node manager) — user-local, no root needed.
    ctx.logger.warn("binary tarball install failed; trying fnm fallback");
    await tryFnm(ctx);
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

async function tryBinaryTarball(ctx: InstallContext): Promise<boolean> {
  const arch = process.arch === "x64" ? "x64" : "arm64";
  const url = `https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.gz`;
  const nodeDir = `/usr/local/lib/node-v${NODE_VERSION}`;

  const result = await ctx.runner.run(
    `curl -fsSL --max-time 15 "${url}" | tar xz -C /usr/local/lib/ && mv /usr/local/lib/node-v${NODE_VERSION}-linux-${arch} ${nodeDir}`,
    { sudo: true, allowFailure: true },
  );
  if (result.code !== 0) {
    ctx.logger.warn(`binary tarball download failed (exit ${result.code})`);
    return false;
  }
  // Symlink into /usr/local/bin
  for (const bin of ["node", "npm", "npx"]) {
    await ctx.runner.run(`ln -sf ${nodeDir}/bin/${bin} /usr/local/bin/${bin}`, {
      sudo: true,
      allowFailure: true,
    });
  }
  return true;
}

async function tryFnm(ctx: InstallContext): Promise<void> {
  const fnmInstall = await ctx.runner.run(
    "curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell",
    { stream: true, allowFailure: true },
  );
  if (fnmInstall.code !== 0) {
    throw new Error(
      `fnm fallback install also failed (exit ${fnmInstall.code}). ` +
        `No way to get Node ${REQUIRED_MAJOR}. Install manually: ` +
        `curl -fsSL https://fnm.vercel.app/install | bash`,
    );
  }
  const fnmDir = `${ctx.home}/.local/share/fnm`;
  const envSetup = `export PATH="${fnmDir}:$PATH" && eval "$(fnm env)"`;
  await ctx.runner.run(
    `${envSetup} && fnm install ${REQUIRED_MAJOR} && fnm use ${REQUIRED_MAJOR} && fnm default ${REQUIRED_MAJOR}`,
    { stream: true },
  );
  const nodePathResult = await ctx.runner.run(
    `${envSetup} && which node`,
    { allowFailure: true },
  );
  if (nodePathResult.code === 0) {
    const nodePath = nodePathResult.stdout.trim();
    const npmPath = nodePath.replace(/\/node$/, "/npm");
    const npxPath = nodePath.replace(/\/node$/, "/npx");
    await ctx.runner.run(`ln -sf ${nodePath} /usr/local/bin/node`, { sudo: true, allowFailure: true });
    await ctx.runner.run(`ln -sf ${npmPath} /usr/local/bin/npm`, { sudo: true, allowFailure: true });
    await ctx.runner.run(`ln -sf ${npxPath} /usr/local/bin/npx`, { sudo: true, allowFailure: true });
    ctx.logger.ok(`symlinked fnm node ${REQUIRED_MAJOR} into /usr/local/bin`);
  }
}

async function currentNodeMajor(ctx: InstallContext): Promise<number> {
  if (!(await ctx.runner.commandExists("node"))) return 0;
  const v = await ctx.runner.capture("node -v");
  const m = /^v(\d+)\./.exec(v);
  if (m === null || m[1] === undefined) return 0;
  return Number.parseInt(m[1], 10);
}
