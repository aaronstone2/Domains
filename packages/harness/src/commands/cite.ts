import * as p from "@clack/prompts";
import { openDb, DOMAINS } from "../db.ts";

interface SourceRow {
  domain: string;
  id: string;
  url: string;
  title: string;
  subdomain: string;
  tier: string;
  license_note: string;
  notes: string | null;
}

export async function citeCmd(args: string[]): Promise<void> {
  const id = args[0]?.trim();
  if (!id) {
    p.log.error("usage: harness cite <source-id>");
    process.exit(1);
  }
  const escaped = id.replace(/'/g, "''");
  const db = await openDb();
  try {
    const sql = DOMAINS.map(
      (d) => `SELECT '${d}' AS domain, * FROM ${d}.sources WHERE id = '${escaped}'`,
    ).join("\nUNION ALL\n");
    const rows = (await db.all(sql)) as unknown as SourceRow[];
    if (rows.length === 0) {
      p.log.error(`source not found: ${id}`);
      process.exit(2);
    }
    const s = rows[0]!;
    console.log(`\n${s.id}  [${s.domain}/${s.subdomain}]`);
    console.log(`Title: ${s.title}`);
    console.log(`URL:   ${s.url}`);
    console.log(`Tier:  ${s.tier}   License: ${s.license_note}`);
    if (s.notes) console.log(`Notes: ${s.notes}`);
  } finally {
    await db.close();
  }
}
