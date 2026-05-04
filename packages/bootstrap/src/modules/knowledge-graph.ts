// Module: knowledge-graph — build the corpus knowledge graph if missing.
// The graph file is gitignored; the build is fast (~1s).

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
    if (!(await ctx.runner.pathExists(`${ctx.config.repoDir}/_db/knowledge.duckdb`))) {
      ctx.logger.warn("_db/knowledge.duckdb missing — graph build will likely fail");
    }
    await ctx.runner.run("pnpm graph", { cwd: ctx.config.repoDir, stream: true });
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
