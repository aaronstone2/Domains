// Module: interview-notes — copy the RCA notes template to ~/notes.md so
// it's ready to use the moment the installer finishes. No manual cp needed.

import * as path from "node:path";
import * as fs from "node:fs/promises";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const TEMPLATE = "interview-notes.template.md";
const TARGET = "notes.md";

export const interviewNotesModule: InstallerModule = {
  id: "interview-notes",
  description: "Copy RCA notes template to ~/notes.md",
  tags: ["shell", "productivity"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.pathExists(path.join(ctx.home, TARGET));
  },

  async install(ctx: InstallContext): Promise<void> {
    const src = path.join(ctx.config.repoDir, TEMPLATE);
    const dest = path.join(ctx.home, TARGET);

    try {
      await fs.access(src);
    } catch {
      ctx.logger.skip(`${TEMPLATE} not found in repo — skipping`);
      return;
    }

    await fs.copyFile(src, dest);
    ctx.logger.ok(`copied ${TEMPLATE} → ${dest}`);
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const dest = path.join(ctx.home, TARGET);
    if (await ctx.runner.pathExists(dest)) {
      return { ok: true, message: `${dest} present` };
    }
    return { ok: false, message: `${dest} missing` };
  },
};
