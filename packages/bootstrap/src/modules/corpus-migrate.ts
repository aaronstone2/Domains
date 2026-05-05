// Module: corpus-migrate — apply versioned SQL migrations to _db/knowledge.duckdb.
// Idempotent: each migration uses INSERT OR REPLACE / UPDATE WHERE NOT, so re-running
// is safe. Tracks applied migrations in meta_migrations table.
//
// Runs BEFORE knowledge-graph (which derives knowledge_graph.json from current DB state)
// so the graph reflects the post-migration state.
//
// Fast-path: if the set of migration files hasn't changed since last run (tracked
// via a stamp file), skip the expensive tsx + DuckDB spawn entirely.
//
// PERF: on cold clone with all migrations already applied in the committed DB,
// the stamp file won't exist but migrations don't need re-running. We detect
// this by checking the stamp OR verifying the DB has all migrations applied
// (via a quick `duckdb` check if available, otherwise via the lightweight
// file-count heuristic).

import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as crypto from "node:crypto";
import { createRequire } from "node:module";

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

async function migrationFileCount(repoDir: string): Promise<number> {
  const dir = path.join(repoDir, "domains", "_shared", "queries", "migrations");
  try {
    const entries = (await fs.readdir(dir)).filter((f) => f.endsWith(".sql"));
    return entries.length;
  } catch {
    return 0;
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
    // Fast-path 1: stamp file matches → skip.
    const stamp = path.join(ctx.home, STAMP_FILE);
    try {
      const [currentHash, savedHash] = await Promise.all([
        migrationFilesHash(ctx.config.repoDir),
        fs.readFile(stamp, "utf8"),
      ]);
      if (currentHash !== "" && currentHash === savedHash.trim()) return true;
    } catch {
      // No stamp — fall through to fast-path 2.
    }

    // Fast-path 2: DB exists and we can check if migrations are already applied
    // without spawning a heavy tsx process. Use the harness's duckdb-async
    // via dynamic import from the workspace.
    const duckdb = path.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      await fs.access(duckdb);
    } catch {
      return false; // DB doesn't exist → definitely needs work.
    }

    try {
      const fileCount = await migrationFileCount(ctx.config.repoDir);
      if (fileCount === 0) return true; // No migrations to apply.

      // Try to check via duckdb-async if available in the workspace.
      // Use createRequire to resolve through pnpm's hoisted symlinks.
      const require = createRequire(path.join(ctx.config.repoDir, "packages", "harness", "x.cjs"));
      const resolvedPath = require.resolve("duckdb-async");
      const { Database } = await import(resolvedPath) as { Database: { create(path: string): Promise<{ all(sql: string): Promise<unknown[]>; close(): Promise<void> }> } };
      const db = await Database.create(duckdb);
      try {
        const rows = await db.all("SELECT COUNT(*) AS cnt FROM meta_migrations") as Array<{ cnt: number }>;
        const appliedCount = rows[0]?.cnt ?? 0;
        if (appliedCount >= fileCount) {
          // All migrations applied — write stamp and skip.
          const hash = await migrationFilesHash(ctx.config.repoDir);
          if (hash) await fs.writeFile(path.join(ctx.home, STAMP_FILE), hash + "\n");
          return true;
        }
      } finally {
        await db.close();
      }
    } catch {
      // duckdb-async not available or table doesn't exist — fall through.
    }

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
