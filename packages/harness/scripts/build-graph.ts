#!/usr/bin/env -S npx tsx
// Derive _db/knowledge_graph.json from the SQL relationships table for the
// `memory` MCP server. The memory server reads NDJSON — one JSON object per
// line — where each line is either an entity or a relation. Schema:
//   {"type":"entity","name":"<id>","entityType":"<kind>","observations":["..."]}
//   {"type":"relation","from":"<id>","to":"<id>","relationType":"<rel>"}
//
// Why this exists: the master plan called for a knowledge-graph layer
// "complementary, not duplicative" — SQL is source-of-truth, the graph is
// a derived view that lets Claude do typed entity-relation queries via the
// memory MCP. This script builds it from current DB state.
//
// Run: pnpm --filter @domains/harness exec tsx scripts/build-graph.ts
// Or:  pnpm graph (root script — see package.json)

import { Database } from "duckdb-async";
import { writeFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here: string = dirname(fileURLToPath(import.meta.url));
const repoRoot: string = resolve(here, "..", "..", "..");
const dbPath: string = resolve(repoRoot, "_db", "knowledge.duckdb");
const outPath: string = resolve(repoRoot, "_db", "knowledge_graph.json");

const DOMAINS = ["docker", "linux", "k8s", "devin", "methodology", "firecracker", "ecs"] as const;

interface EntityRow {
  domain: string;
  id: string;
  entity_type: string;
  observation: string;
}
interface RelRow {
  from_id: string;
  to_id: string;
  rel_type: string;
}

async function main(): Promise<void> {
  console.error(`reading ${dbPath}`);
  const db = await Database.create(dbPath);

  // Concepts → entities
  const conceptsSql = DOMAINS.map((d) => `
    SELECT '${d}' AS domain, id, COALESCE(kind, 'concept') AS entity_type,
           COALESCE(name, id) || ': ' || COALESCE(description, '') AS observation
    FROM ${d}.concepts
  `).join(" UNION ALL ");

  // Failure modes → entities (entity_type = 'failure_mode')
  const fmsSql = DOMAINS.map((d) => `
    SELECT '${d}' AS domain, id, 'failure_mode' AS entity_type,
           symptom || COALESCE(' [class: ' || root_cause_class || ']', '') AS observation
    FROM ${d}.failure_modes
  `).join(" UNION ALL ");

  // Commands → entities (entity_type = 'command')
  const cmdsSql = DOMAINS.map((d) => `
    SELECT '${d}' AS domain, id, 'command' AS entity_type,
           command || COALESCE(' — ' || purpose, '') AS observation
    FROM ${d}.commands
  `).join(" UNION ALL ");

  // Config keys → entities (entity_type = 'config_key')
  const configSql = DOMAINS.map((d) => `
    SELECT '${d}' AS domain, id, 'config_key' AS entity_type,
           COALESCE(scope || '.', '') || key || COALESCE(': ' || description, '') AS observation
    FROM ${d}.config_keys
  `).join(" UNION ALL ");

  console.error("loading entities …");
  const entities = await db.all(`${conceptsSql} UNION ALL ${fmsSql} UNION ALL ${cmdsSql} UNION ALL ${configSql}`) as unknown as EntityRow[];
  console.error(`  ${entities.length} entities`);

  // Relationships → relations
  const relsSql = DOMAINS.map((d) => `SELECT from_id, to_id, rel_type FROM ${d}.relationships`).join(" UNION ALL ");
  const rels = await db.all(relsSql) as unknown as RelRow[];
  console.error(`loading relations … ${rels.length} relations`);

  await db.close();

  // Coalesce duplicate entities (same id from multiple sources): keep one,
  // append observations.
  const entitiesById = new Map<string, { name: string; entityType: string; observations: string[] }>();
  for (const e of entities) {
    if (!e.id) continue;
    const existing = entitiesById.get(e.id);
    if (existing) {
      if (e.observation && !existing.observations.includes(e.observation)) {
        existing.observations.push(e.observation);
      }
    } else {
      entitiesById.set(e.id, {
        name: e.id,
        entityType: e.entity_type,
        observations: e.observation ? [e.observation] : [],
      });
    }
  }
  console.error(`  ${entitiesById.size} unique entities after dedup`);

  // Filter relations to only those whose endpoints exist in the entity set
  // (memory MCP otherwise complains about dangling refs).
  const validRels = rels.filter((r) => entitiesById.has(r.from_id) && entitiesById.has(r.to_id));
  console.error(`  ${validRels.length} valid relations (filtered ${rels.length - validRels.length} dangling)`);

  // Emit NDJSON: one entity per line, then one relation per line.
  const lines: string[] = [];
  for (const ent of entitiesById.values()) {
    lines.push(JSON.stringify({ type: "entity", ...ent }));
  }
  for (const r of validRels) {
    lines.push(JSON.stringify({
      type: "relation",
      from: r.from_id,
      to: r.to_id,
      relationType: r.rel_type,
    }));
  }

  await mkdir(dirname(outPath), { recursive: true });
  await writeFile(outPath, lines.join("\n") + "\n", "utf8");
  console.error(`wrote ${outPath} (${lines.length} lines)`);
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.stack ?? err.message : String(err));
  process.exit(1);
});
