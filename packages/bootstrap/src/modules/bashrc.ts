// Module: bashrc — write the managed block (atuin/zoxide/fzf inits, completions,
// aliases SANS grep=rg, demoshell, bashrc-landmines) to ~/.bashrc.
//
// All composition is in src/bashrc/builder.ts. This module just calls the
// builder + writes the file via the shared marker-based helper.
//
// ACID: implements snapshotState() (saves full ~/.bashrc) and rollback()
// (restores it) so a failed write doesn't leave the user shell-less.

import * as fs from "node:fs/promises";
import * as path from "node:path";

import { buildBashrcBody } from "../bashrc/builder.ts";
import { readBashrcBlock, writeBashrcBlock } from "../lib/bashrc-block.ts";
import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const bashrcModule: InstallerModule = {
  id: "bashrc",
  description: "Write managed block to ~/.bashrc (atuin/zoxide/fzf, aliases, safety functions)",
  tags: ["shell"],

  shouldRun(config): boolean {
    return !config.noShellConfig;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    const current = await readBashrcBlock(`${ctx.home}/.bashrc`);
    const next = buildBashrcBody({ repoDir: ctx.config.repoDir });
    return current.trim() === next.trim();
  },

  async install(ctx: InstallContext): Promise<void> {
    const body = buildBashrcBody({ repoDir: ctx.config.repoDir });
    await writeBashrcBlock({
      path: path.join(ctx.home, ".bashrc"),
      content: body,
      runner: ctx.runner,
    });
    ctx.logger.ok("~/.bashrc managed block written");
    ctx.logger.info("open a NEW shell (or `source ~/.bashrc`) to pick up changes");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const block = await readBashrcBlock(`${ctx.home}/.bashrc`);
    if (block === "") {
      return { ok: false, message: "managed block missing from ~/.bashrc" };
    }
    if (!block.includes("demoshell()") || !block.includes("bashrc-landmines()")) {
      return { ok: false, message: "managed block present but missing safety functions" };
    }
    if (block.includes("alias grep='rg'")) {
      return { ok: false, message: "grep=rg landmine present in managed block — STOP, regenerate" };
    }
    // bash -n parses the file; detect any syntax error introduced by adjacent unmanaged blocks.
    const result = await ctx.runner.run(`bash -n ${ctx.home}/.bashrc`, { allowFailure: true });
    if (result.code !== 0) {
      return { ok: false, message: `~/.bashrc has bash -n syntax error: ${result.stderr.trim()}` };
    }
    return { ok: true, message: "managed block intact + safety functions present + no landmines" };
  },

  /**
   * Capture entire ~/.bashrc (or note its absence) so we can restore it if
   * install() corrupts the file. Returns the exact bytes; rollback() writes
   * them back atomically.
   */
  async snapshotState(ctx: InstallContext): Promise<unknown> {
    const target = path.join(ctx.home, ".bashrc");
    try {
      const content = await fs.readFile(target, "utf8");
      return { existed: true, content, path: target } as const;
    } catch (err) {
      const e = err as NodeJS.ErrnoException;
      if (e.code === "ENOENT") return { existed: false, path: target } as const;
      throw err;
    }
  },

  /**
   * Restore ~/.bashrc from the captured state. Atomic write.
   */
  async rollback(ctx: InstallContext, state: unknown): Promise<void> {
    const s = state as { existed: boolean; content?: string; path: string };
    if (!s.existed) {
      // Bashrc didn't exist before; remove anything we created.
      try {
        await fs.unlink(s.path);
      } catch {
        // ignore
      }
      ctx.logger.warn("rolled back bashrc by removing newly-created file");
      return;
    }
    await ctx.runner.writeFile(s.path, s.content ?? "");
    ctx.logger.warn(`rolled back bashrc to pre-install state (${(s.content ?? "").length} bytes)`);
  },
};
