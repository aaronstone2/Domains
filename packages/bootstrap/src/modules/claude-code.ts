// Module: claude-code — install @anthropic-ai/claude-code globally via npm.
// Skipped by --no-claude.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const claudeCodeModule: InstallerModule = {
  id: "claude-code",
  description: "@anthropic-ai/claude-code CLI (global npm install)",
  tags: ["runtime", "ai"],

  shouldRun(config): boolean {
    return !config.noClaude;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.commandExists("claude");
  },

  async install(ctx: InstallContext): Promise<void> {
    if (!(await ctx.runner.commandExists("npm"))) {
      throw new Error("npm not found — run the 'node' module first");
    }
    await ctx.runner.run("npm install -g @anthropic-ai/claude-code", {
      sudo: true,
      stream: true,
    });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    if (!(await ctx.runner.commandExists("claude"))) {
      return { ok: false, message: "claude not on PATH" };
    }
    return { ok: true, message: "claude installed" };
  },
};
