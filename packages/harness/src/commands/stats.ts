import { openDb, DOMAINS } from "../db.ts";
import {
  bold, dim, header, section, table, hr, domainChip,
} from "../output.ts";

interface Row { [k: string]: unknown }

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
    const rows = (await db.all(sql)) as Row[];

    console.log("");
    console.log(header("harness stats", "corpus inventory by domain"));

    const cols = [
      { header: "domain" },
      { header: "sources",       align: "right" as const },
      { header: "documents",     align: "right" as const },
      { header: "concepts",      align: "right" as const },
      { header: "commands",      align: "right" as const },
      { header: "config_keys",   align: "right" as const },
      { header: "failure_modes", align: "right" as const },
      { header: "relationships", align: "right" as const },
    ];

    const numCols = cols.slice(1).map((c) => c.header);
    const totals: Record<string, number> = {};
    for (const c of numCols) totals[c] = 0;
    for (const r of rows) for (const c of numCols) totals[c] = (totals[c] ?? 0) + Number(r[c] ?? 0);

    const tableRows: string[][] = rows.map((r) => [
      domainChip(String(r["domain"])),
      ...numCols.map((c) => String(Number(r[c] ?? 0))),
    ]);
    tableRows.push([
      bold("TOTAL"),
      ...numCols.map((c) => bold(String(totals[c] ?? 0))),
    ]);

    console.log("");
    console.log(table(cols, tableRows));

    // Failure-mode quality summary — depth grading.
    console.log(section("FAILURE-MODE QUALITY"));
    const qSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain,
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE len(diagnostic_steps) < 3 OR len(fix_steps) < 2) AS thin,
        ROUND(AVG(len(diagnostic_steps)), 2) AS avg_diag,
        ROUND(AVG(len(fix_steps)), 2) AS avg_fix
      FROM ${d}.failure_modes`,
    ).join("\nUNION ALL\n");
    const qRows = (await db.all(qSql)) as Array<Record<string, unknown>>;
    const qCols = [
      { header: "domain" },
      { header: "fms",      align: "right" as const },
      { header: "thin",     align: "right" as const },
      { header: "% thin",   align: "right" as const },
      { header: "avg diag", align: "right" as const },
      { header: "avg fix",  align: "right" as const },
    ];
    let totalFms = 0; let totalThin = 0;
    for (const r of qRows) {
      totalFms += Number(r["total"] ?? 0);
      totalThin += Number(r["thin"] ?? 0);
    }
    const qTableRows: string[][] = qRows.map((r) => {
      const total = Number(r["total"] ?? 0);
      const thin = Number(r["thin"] ?? 0);
      const pct = total > 0 ? Math.round((thin / total) * 100) : 0;
      const pctStr = pct === 0 ? bold("0%") : pct >= 50 ? `${pct}%` : `${pct}%`;
      return [
        domainChip(String(r["domain"])),
        String(total),
        String(thin),
        pctStr,
        String(r["avg_diag"] ?? "0"),
        String(r["avg_fix"] ?? "0"),
      ];
    });
    qTableRows.push([
      bold("TOTAL"),
      bold(String(totalFms)),
      bold(String(totalThin)),
      bold(totalFms > 0 ? `${Math.round((totalThin / totalFms) * 100)}%` : "0%"),
      "—",
      "—",
    ]);
    console.log("");
    console.log(table(qCols, qTableRows));

    console.log("");
    console.log(dim("  thin = <3 diag steps OR <2 fix steps. Lower % thin = more interview-ready."));
    console.log("");
    console.log(hr());
  } finally {
    await db.close();
  }
}
