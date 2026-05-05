// Module: node — Node.js >= 22. Tries NodeSource apt repo first; if that
// fails (rate-limiting, network issues, repo down), falls back to fnm
// (fast node manager) which installs user-locally with no apt dependency.
//
// The trampoline (bootstrap.sh) already ensures a basic node exists before
// this module runs. This module only fires when the existing version is
// below the required major.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const REQUIRED_MAJOR = 22;

export const nodeModule: InstallerModule = {
  id: "node",
  description: `Node.js >= ${REQUIRED_MAJOR} via NodeSource apt repo (fnm fallback)`,
  tags: ["runtime"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return (await currentNodeMajor(ctx)) >= REQUIRED_MAJOR;
  },

  async install(ctx: InstallContext): Promise<void> {
    // Strategy 1: NodeSource apt repo (preferred — system-wide install).
    const nodeSourceOk = await tryNodeSource(ctx);
    if (nodeSourceOk && (await currentNodeMajor(ctx)) >= REQUIRED_MAJOR) return;

    // Strategy 2: fnm (fast node manager) — user-local, no root needed.
    ctx.logger.warn("NodeSource install failed or node version still too old; trying fnm fallback");
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

async function tryNodeSource(ctx: InstallContext): Promise<boolean> {
  const setupUrl = `https://deb.nodesource.com/setup_${REQUIRED_MAJOR}.x`;
  const setupResult = await ctx.runner.run(`curl -fsSL --max-time 15 ${setupUrl} | bash -`, {
    sudo: true,
    stream: true,
    allowFailure: true,
  });
  if (setupResult.code !== 0) {
    ctx.logger.warn(
      `NodeSource setup script failed (exit ${setupResult.code}). ` +
        `Possibly rate-limited or unreachable.`,
    );
    return false;
  }
  const installResult = await ctx.runner.run(
    "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs",
    { sudo: true, stream: true, allowFailure: true },
  );
  return installResult.code === 0;
}

async function tryFnm(ctx: InstallContext): Promise<void> {
  // fnm installs to ~/.local/share/fnm and is a single static binary.
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
  // fnm binary lands at ~/.local/share/fnm/fnm; add to PATH for this session.
  const fnmDir = `${ctx.home}/.local/share/fnm`;
  const envSetup = `export PATH="${fnmDir}:$PATH" && eval "$(fnm env)"`;
  await ctx.runner.run(
    `${envSetup} && fnm install ${REQUIRED_MAJOR} && fnm use ${REQUIRED_MAJOR} && fnm default ${REQUIRED_MAJOR}`,
    { stream: true },
  );
  // Symlink fnm's node/npm into /usr/local/bin so subsequent modules find
  // them on the default PATH without needing fnm env in every shell.
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
  // node -v prints "vNN.MM.PP"
  const m = /^v(\d+)\./.exec(v);
  if (m === null || m[1] === undefined) return 0;
  return Number.parseInt(m[1], 10);
}
