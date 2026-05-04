import { println } from "../output.ts";
import { openDb, DOMAINS } from "../db.ts";

interface ConceptRow {
  domain: string;
  id: string;
  name: string;
  kind: string;
  description: string;
  source_ids: string[] | null;
  aliases: string[] | null;
}

interface RelRow {
  domain: string;
  from_id: string;
  to_id: string;
  rel_type: string;
}

export async function conceptCmd(args: string[]): Promise<void> {
  const id = args[0]?.trim();
  if (!id) {
    println("usage: harness concept <concept-id>");
    process.exit(1);
  }
  const escaped = id.replace(/'/g, "''");
  const db = await openDb();
  try {
    const conceptSql = DOMAINS.map(
      (d) => `SELECT '${d}' AS domain, * FROM ${d}.concepts WHERE id = '${escaped}'`,
    ).join("\nUNION ALL\n");
    const rows = (await db.all(conceptSql)) as unknown as ConceptRow[];
    if (rows.length === 0) {
      println(`concept not found: ${id}`);
      process.exit(2);
    }
    const c = rows[0]!;
    println(`\n=== ${c.id}  [${c.domain}] ===`);
    println(`Name: ${c.name}`);
    println(`Kind: ${c.kind}`);
    if (c.aliases && c.aliases.length > 0) {
      println(`Aliases: ${c.aliases.join(", ")}`);
    }
    println(`\n${c.description}`);
    if (c.source_ids && c.source_ids.length > 0) {
      println(`\nSources: ${c.source_ids.join(", ")}`);
    }
    const relSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, from_id, to_id, rel_type
      FROM ${d}.relationships
      WHERE from_id = '${escaped}' OR to_id = '${escaped}'`,
    ).join("\nUNION ALL\n");
    const rels = (await db.all(relSql)) as unknown as RelRow[];
    if (rels.length > 0) {
      println("\n-- Relationships --");
      for (const r of rels) {
        const arrow = r.from_id === id ? "->" : "<-";
        const other = r.from_id === id ? r.to_id : r.from_id;
        println(`  ${arrow} ${r.rel_type}  ${other}  [${r.domain}]`);
      }
    }
    println("");
  } finally {
    await db.close();
  }
}
