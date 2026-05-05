// Module: seed-history — append a curated history file to ~/.bash_history
// and import into atuin if available. Idempotent: dedupes existing entries.

import * as path from "node:path";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const seedHistoryModule: InstallerModule = {
  id: "seed-history",
  description: "Append cmd_history.txt → ~/.bash_history and import into atuin",
  tags: ["shell", "history"],

  shouldRun(config): boolean {
    return !config.noShellConfig;
  },

  async isInstalled(): Promise<boolean> {
    // No clean way to detect; treat as always-runnable. Idempotent dedup
    // means re-running is safe.
    return false;
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
