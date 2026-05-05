// Module: knowledge-graph — build the corpus knowledge graph if missing.
// The graph file is gitignored; the build is fast (~1s) but requires the
// 76MB _db/knowledge.duckdb file to be present (which is git-tracked +
// allowlisted in .gitignore).
//
// FIX (v1.2): legacy install() warned if duckdb was missing then ran the
// graph build anyway, which exited 1 with empty stderr — useless to debug.
// New version hard-fails immediately with a clear remediation message.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const knowledgeGraphModule: InstallerModule = {
  id: "knowledge-graph",
  description: "Build _db/knowledge_graph.json if missing (`pnpm graph`)",
  tags: ["repo", "corpus"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    return await ctx.runner.pathExists(`${ctx.config.repoDir}/_db/knowledge_graph.json`);
  },

  async install(ctx: InstallContext): Promise<void> {
    const duckdb = `${ctx.config.repoDir}/_db/knowledge.duckdb`;
    if (!(await ctx.runner.pathExists(duckdb))) {
      throw new Error(
        `prerequisite missing: ${duckdb} (76MB) is required to build the knowledge graph. ` +
          `It's git-tracked + allowlisted in .gitignore, so 'git clone' should pull it. ` +
          `Check on this box: ls -la _db/knowledge.duckdb (file should exist + be ~76MB). ` +
          `If it's empty/0-byte, run: git fetch && git checkout origin/main -- _db/knowledge.duckdb`,
      );
    }
    // Capture stderr separately for clearer error messages on failure.
    const result = await ctx.runner.run("pnpm graph", {
      cwd: ctx.config.repoDir,
      allowFailure: true,
    });
    if (result.code !== 0) {
      throw new Error(
        `pnpm graph exited ${result.code}. ` +
          `stderr: ${result.stderr.trim() || "(empty)"} ` +
          `stdout: ${result.stdout.trim().slice(-300) || "(empty)"}`,
      );
    }
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const present = await ctx.runner.pathExists(
      `${ctx.config.repoDir}/_db/knowledge_graph.json`,
    );
    return present
      ? { ok: true, message: "knowledge_graph.json present" }
      : { ok: false, message: "knowledge_graph.json missing" };
  },
};
