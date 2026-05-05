#!/usr/bin/env -S npx tsx
// Apply versioned SQL migrations from domains/_shared/queries/migrations/
// to the corpus DuckDB. Idempotent: each migration uses INSERT OR REPLACE / UPDATE
// guarded by NOT-already-applied predicates, so re-running is safe.
//
// Run: pnpm corpus migrate
//      pnpm corpus migrate --dry-run       # print files, don't execute
//      pnpm corpus migrate --rebuild-fts   # also re-run fts_index.sql at end
//
// On success the bootstrap knowledge-graph module can call this so fresh
// DevBox installs end up with the same enriched corpus state.

import { Database } from "duckdb-async";
import { readFile, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve, basename } from "node:path";

const here: string = dirname(fileURLToPath(import.meta.url));
const repoRoot: string = resolve(here, "..", "..", "..");
const dbPath: string = resolve(repoRoot, "_db", "knowledge.duckdb");
const migrationsDir: string = resolve(
  repoRoot,
  "domains",
  "_shared",
  "queries",
  "migrations",
);
const ftsScript: string = resolve(
  repoRoot,
  "domains",
  "_shared",
  "queries",
  "fts_index.sql",
);

interface Args {
  dryRun: boolean;
  rebuildFts: boolean;
}

function parseArgs(argv: readonly string[]): Args {
  return {
    dryRun: argv.includes("--dry-run"),
    rebuildFts: argv.includes("--rebuild-fts"),
  };
}

async function listMigrations(): Promise<readonly string[]> {
  if (!existsSync(migrationsDir)) {
    return [];
  }
  const entries = await readdir(migrationsDir);
  return entries.filter((f) => f.endsWith(".sql")).sort();
}

async function ensureMigrationsTable(db: Database): Promise<void> {
  await db.all(`
    CREATE TABLE IF NOT EXISTS meta_migrations (
      filename VARCHAR PRIMARY KEY,
      applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      sha256 VARCHAR
    )
  `);
}

async function appliedSet(db: Database): Promise<Set<string>> {
  const rows = (await db.all(
    `SELECT filename FROM meta_migrations`,
  )) as unknown as ReadonlyArray<{ filename: string }>;
  return new Set(rows.map((r) => r.filename));
}

async function applyMigration(
  db: Database,
  filename: string,
  args: Args,
): Promise<void> {
  const fullPath = resolve(migrationsDir, filename);
  const sql = await readFile(fullPath, "utf-8");
  if (args.dryRun) {
    console.log(`[dry-run] would apply ${filename} (${sql.length} bytes)`);
    return;
  }
  console.log(`==> applying ${filename}`);
  await db.exec(sql);
  await db.all(`INSERT OR REPLACE INTO meta_migrations (filename) VALUES (?)`, filename);
  console.log(`    OK ${filename}`);
}

async function rebuildFts(db: Database, args: Args): Promise<void> {
  if (!existsSync(ftsScript)) {
    console.log("    (skip FTS rebuild — fts_index.sql not found)");
    return;
  }
  const sql = await readFile(ftsScript, "utf-8");
  if (args.dryRun) {
    console.log(`[dry-run] would re-run ${basename(ftsScript)}`);
    return;
  }
  console.log(`==> rebuilding FTS indexes via ${basename(ftsScript)}`);
  await db.exec(sql);
  console.log("    OK FTS rebuilt");
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (!existsSync(dbPath)) {
    console.error(`error: corpus DB not found at ${dbPath}`);
    console.error(`hint: pnpm graph builds it; or git pull to fetch the binary blob.`);
    process.exit(1);
  }
  const migrations = await listMigrations();
  if (migrations.length === 0) {
    console.log("no migrations found in", migrationsDir);
    return;
  }
  console.log(`found ${migrations.length} migration file(s)`);

  if (args.dryRun) {
    for (const filename of migrations) {
      console.log(`[dry-run] would apply ${filename}`);
    }
    if (args.rebuildFts) {
      console.log(`[dry-run] would rebuild FTS via ${basename(ftsScript)}`);
    }
    return;
  }

  const db = await Database.create(dbPath);
  try {
    await ensureMigrationsTable(db);
    const already = await appliedSet(db);
    let pending = 0;
    for (const filename of migrations) {
      if (already.has(filename)) {
        console.log(`    skip ${filename} (already applied)`);
        continue;
      }
      await applyMigration(db, filename, args);
      pending += 1;
    }
    if (args.rebuildFts || pending > 0) {
      await rebuildFts(db, args);
    } else {
      console.log("    (no new migrations applied — skip FTS rebuild; pass --rebuild-fts to force)");
    }
    console.log(`done. ${pending} migration(s) applied.`);
  } finally {
    await db.close();
  }
}

main().catch((err: unknown) => {
  console.error("migrate failed:", err);
  process.exit(1);
});
