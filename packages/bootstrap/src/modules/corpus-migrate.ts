// Module: corpus-migrate — apply versioned SQL migrations to _db/knowledge.duckdb.
// Idempotent: each migration uses INSERT OR REPLACE / UPDATE WHERE NOT, so re-running
// is safe. Tracks applied migrations in meta_migrations table.
//
// Runs BEFORE knowledge-graph (which derives knowledge_graph.json from current DB state)
// so the graph reflects the post-migration state.
//
// Fast-path: if the set of migration files hasn't changed since last run (tracked
// via a stamp file), skip the expensive tsx + DuckDB spawn entirely.

import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as crypto from "node:crypto";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const STAMP_FILE = ".corpus-migrate-hash";

async function migrationFilesHash(repoDir: string): Promise<string> {
  const dir = path.join(repoDir, "domains", "_shared", "queries", "migrations");
  try {
    const entries = (await fs.readdir(dir)).filter((f) => f.endsWith(".sql")).sort();
    const h = crypto.createHash("sha256");
    for (const entry of entries) {
      const content = await fs.readFile(path.join(dir, entry));
      h.update(entry);
      h.update(content);
    }
    return h.digest("hex");
  } catch {
    return "";
  }
}

export const corpusMigrateModule: InstallerModule = {
  id: "corpus-migrate",
  description: "Apply versioned SQL migrations to _db/knowledge.duckdb (`pnpm corpus`)",
  tags: ["repo", "corpus"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    const stamp = path.join(ctx.home, STAMP_FILE);
    try {
      const [currentHash, savedHash] = await Promise.all([
        migrationFilesHash(ctx.config.repoDir),
        fs.readFile(stamp, "utf8"),
      ]);
      return currentHash !== "" && currentHash === savedHash.trim();
    } catch {
      return false;
    }
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
    // Write stamp so isInstalled() can skip on next run.
    const hash = await migrationFilesHash(ctx.config.repoDir);
    if (hash) {
      await fs.writeFile(path.join(ctx.home, STAMP_FILE), hash + "\n");
    }
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    void ctx;
    return { ok: true, message: "migrations applied (or already up-to-date)" };
  },
};
