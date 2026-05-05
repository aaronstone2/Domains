// Module: seed-history — append a curated history file to ~/.bash_history
// and import into atuin if available. Idempotent: dedupes existing entries.

import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as crypto from "node:crypto";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const STAMP_FILE = ".seed-history-hash";

export const seedHistoryModule: InstallerModule = {
  id: "seed-history",
  description: "Append cmd_history.txt → ~/.bash_history and import into atuin",
  tags: ["shell", "history"],

  shouldRun(config): boolean {
    return !config.noShellConfig;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    const seed = path.join(ctx.config.repoDir, "cmd_history.txt");
    const stamp = path.join(ctx.home, STAMP_FILE);
    try {
      const [seedBuf, savedHash] = await Promise.all([
        fs.readFile(seed),
        fs.readFile(stamp, "utf8"),
      ]);
      const currentHash = crypto.createHash("sha256").update(seedBuf).digest("hex");
      return currentHash === savedHash.trim();
    } catch {
      return false;
    }
  },

  async install(ctx: InstallContext): Promise<void> {
    const seed = path.join(ctx.config.repoDir, "cmd_history.txt");
    if (!(await ctx.runner.pathExists(seed))) {
      ctx.logger.skip(`no cmd_history.txt at ${seed}`);
      return;
    }
    const histPath = `${ctx.home}/.bash_history`;
    // Append seed to history, then dedup the file. Keep order by uniq -u then re-sort.
    await ctx.runner.run(
      `cat ${shQuote(seed)} >> ${shQuote(histPath)} && awk '!seen[$0]++' ${shQuote(histPath)} > ${shQuote(histPath + ".tmp")} && mv ${shQuote(histPath + ".tmp")} ${shQuote(histPath)}`,
    );
    ctx.logger.ok(`seeded ~/.bash_history from ${seed}`);
    if (await ctx.runner.commandExists("atuin")) {
      const result = await ctx.runner.run("atuin import bash", { allowFailure: true });
      if (result.code === 0) {
        ctx.logger.ok("atuin: imported bash history");
      } else {
        ctx.logger.warn("atuin import failed; not fatal");
      }
    }
    // Write stamp so isInstalled() can skip on next run.
    const seedBuf = await fs.readFile(seed);
    const hash = crypto.createHash("sha256").update(seedBuf).digest("hex");
    await fs.writeFile(path.join(ctx.home, STAMP_FILE), hash + "\n");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const histPath = `${ctx.home}/.bash_history`;
    if (!(await ctx.runner.pathExists(histPath))) {
      return { ok: false, message: "no ~/.bash_history" };
    }
    return { ok: true, message: "history file present" };
  },
};

function shQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}
