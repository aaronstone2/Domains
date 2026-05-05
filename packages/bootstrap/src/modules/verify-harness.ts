// Module: verify-harness — verify the harness can query the corpus.
//
// PERF: instead of spawning `pnpm harness ask "OOMKilled"` (~1s tsx overhead),
// we do an inline DuckDB FTS query using the same dynamic import pattern as
// corpus-migrate. Falls back to subprocess if the inline path fails.

import * as path from "node:path";
import { createRequire } from "node:module";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

let cachedResult: { readonly ok: boolean; readonly message: string } | undefined;

export const verifyHarnessModule: InstallerModule = {
  id: "verify-harness",
  description: "Verify harness can query the corpus (inline DuckDB check, subprocess fallback)",
  tags: ["repo", "verify"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(): Promise<boolean> {
    return false; // always re-run; fast + idempotent
  },

  async install(ctx: InstallContext): Promise<void> {
    // Fast path: inline DuckDB query (~0.1s vs ~1s subprocess).
    const dbPath = path.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      const require = createRequire(path.join(ctx.config.repoDir, "packages", "harness", "x.cjs"));
      const resolvedPath = require.resolve("duckdb-async");
      const { Database } = await import(resolvedPath) as {
        Database: { create(p: string): Promise<{ all(sql: string, ...args: unknown[]): Promise<unknown[]>; close(): Promise<void> }> }
      };
      const db = await Database.create(dbPath);
      try {
        // Simple ILIKE query to verify corpus is readable and has OOM data.
        const rows = await db.all(
          `SELECT id FROM docker.failure_modes WHERE id ILIKE '%oom%' LIMIT 1`,
        ) as Array<{ id: string }>;

        if (rows.length > 0 && /oom/i.test(rows[0]!.id)) {
          cachedResult = { ok: true, message: "corpus reachable" };
          ctx.logger.ok("harness corpus query verified (inline)");
        } else {
          throw new Error("no OOM failure mode found in corpus");
        }
      } finally {
        await db.close();
      }
    } catch {
      // Fallback: subprocess (slower but reliable).
      ctx.logger.info("inline DuckDB check failed, falling back to subprocess");
      const result = await ctx.runner.run('pnpm harness ask "OOMKilled"', {
        cwd: ctx.config.repoDir,
        allowFailure: true,
        timeoutMs: 30_000,
      });
      const text = (result.stdout + "\n" + result.stderr).trim();
      if (result.code !== 0) {
        cachedResult = {
          ok: false,
          message: `harness exit ${result.code}. stderr: ${result.stderr.trim().slice(0, 200) || "(empty)"}`,
        };
        throw new Error(cachedResult.message);
      }
      if (!/oom|kill/i.test(text)) {
        cachedResult = { ok: false, message: `no relevant content. First 200: ${text.slice(0, 200)}` };
        throw new Error(`pnpm harness ask returned exit 0 but no oom/kill match in output.`);
      }
      cachedResult = { ok: true, message: "corpus reachable" };
      ctx.logger.ok("harness ask hit the corpus successfully");
    }
  },

  async verify(): Promise<VerifyResult> {
    return cachedResult ?? { ok: false, message: "install() did not run" };
  },
};
