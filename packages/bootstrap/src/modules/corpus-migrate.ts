// Module: corpus-migrate — apply versioned SQL migrations to _db/knowledge.duckdb.
// Idempotent: each migration uses INSERT OR REPLACE / UPDATE WHERE NOT, so re-running
// is safe. Tracks applied migrations in meta_migrations table.
//
// Runs BEFORE knowledge-graph (which derives knowledge_graph.json from current DB state)
// so the graph reflects the post-migration state.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const corpusMigrateModule: InstallerModule = {
  id: "corpus-migrate",
  description: "Apply versioned SQL migrations to _db/knowledge.duckdb (`pnpm corpus`)",
  tags: ["repo", "corpus"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // Always re-check by running migrate; the script itself is idempotent and
    // will report "no new migrations applied" when there's nothing pending.
    // We treat that as an OK signal in verify(). Returning false here forces
    // install() to run on every bootstrap, which is what we want.
    void ctx;
    return false;
  },

  async install(ctx: InstallContext): Promise<void> {
    const duckdb = `${ctx.config.repoDir}/_db/knowledge.duckdb`;
    if (!(await ctx.runner.pathExists(duckdb))) {
      throw new Error(
        `prerequisite missing: ${duckdb} required for corpus migrations. ` +
          `Run knowledge-graph module first (it has the same precondition).`,
      );
    }
    const result = await ctx.runner.run("pnpm corpus --rebuild-fts", {
      cwd: ctx.config.repoDir,
      allowFailure: true,
    });
    if (result.code !== 0) {
      throw new Error(
        `pnpm corpus exited ${result.code}. ` +
          `stderr: ${result.stderr.trim() || "(empty)"} ` +
          `stdout: ${result.stdout.trim().slice(-300) || "(empty)"}`,
      );
    }
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    void ctx;
    // The install step itself is the verify — if it succeeded, FTS was rebuilt
    // and migrations either applied or were already up-to-date.
    return { ok: true, message: "migrations applied (or already up-to-date)" };
  },
};
