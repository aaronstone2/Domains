import * as p from "@clack/prompts";
import { openDb, DOMAINS } from "../db.ts";

export async function statsCmd(_args: string[]): Promise<void> {
  const db = await openDb();
  try {
    const sql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain,
        (SELECT COUNT(*) FROM ${d}.sources) AS sources,
        (SELECT COUNT(*) FROM ${d}.documents) AS documents,
        (SELECT COUNT(*) FROM ${d}.concepts) AS concepts,
        (SELECT COUNT(*) FROM ${d}.commands) AS commands,
        (SELECT COUNT(*) FROM ${d}.config_keys) AS config_keys,
        (SELECT COUNT(*) FROM ${d}.failure_modes) AS failure_modes,
        (SELECT COUNT(*) FROM ${d}.relationships) AS relationships`,
    ).join("\nUNION ALL\n");
    const rows = (await db.all(sql)) as Array<Record<string, unknown>>;
    p.log.info("Corpus stats:");
    const cols = [
      "domain",
      "sources",
      "documents",
      "concepts",
      "commands",
      "config_keys",
      "failure_modes",
      "relationships",
    ];
    console.log(cols.join("\t"));
    for (const r of rows) {
      console.log(
        cols
          .map((c) => {
            const v = r[c];
            return typeof v === "bigint" ? Number(v) : v;
          })
          .join("\t"),
      );
    }
    const totals: Record<string, number> = {};
    for (const c of cols.slice(1)) {
      totals[c] = rows.reduce((acc, r) => acc + Number(r[c] ?? 0), 0);
    }
    console.log(["TOTAL", ...cols.slice(1).map((c) => totals[c])].join("\t"));
  } finally {
    await db.close();
  }
}
