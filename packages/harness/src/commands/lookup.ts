import * as p from "@clack/prompts";
import { openDb, DOMAINS } from "../db.ts";

interface DocHit {
  domain: string;
  source_id: string;
  section_path: string | null;
  title: string | null;
  url: string | null;
  score: number;
  snippet: string | null;
}
interface ConceptHit {
  domain: string;
  id: string;
  name: string;
  kind: string;
  description: string;
}
interface CommandHit {
  domain: string;
  id: string;
  command: string;
  purpose: string;
}
interface FailureHit {
  domain: string;
  id: string;
  symptom: string;
  root_cause_class: string | null;
  confidence: number | null;
  match_strength: number | bigint;
}

export async function lookupCmd(args: string[]): Promise<void> {
  const text = args.join(" ").trim();
  if (!text) {
    p.log.error("usage: harness lookup <query text>");
    process.exit(1);
  }
  const escaped = text.replace(/'/g, "''");
  const db = await openDb();
  try {
    const unionSql = DOMAINS.map(
      (d) => `
      SELECT
        '${d}' AS domain,
        d.source_id,
        d.section_path,
        s.title,
        s.url,
        fts_${d}_documents.match_bm25(d.source_id, '${escaped}') AS score,
        SUBSTRING(d.content_md, 1, 240) AS snippet
      FROM ${d}.documents d
      LEFT JOIN ${d}.sources s ON s.id = d.source_id
      WHERE fts_${d}_documents.match_bm25(d.source_id, '${escaped}') IS NOT NULL`,
    ).join("\nUNION ALL\n");
    const sql = `${unionSql}\nORDER BY score DESC NULLS LAST LIMIT 12`;
    const rows = (await db.all(sql)) as unknown as DocHit[];
    if (rows.length === 0) {
      p.log.warn(`no document hits for "${text}"`);
    } else {
      p.log.info(`top BM25 hits for "${text}":`);
      for (const r of rows) {
        const score = Number(r.score).toFixed(3);
        const snippet = String(r.snippet ?? "").replace(/\s+/g, " ").trim();
        console.log(
          `  [${r.domain}] ${score}  ${r.source_id}  ${r.title ?? ""}\n    ${snippet}`,
        );
      }
    }
    const conceptSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, id, name, kind, description
      FROM ${d}.concepts
      WHERE LOWER(name) LIKE LOWER('%${escaped}%')
         OR LOWER(id) LIKE LOWER('%${escaped}%')
         OR LOWER(description) LIKE LOWER('%${escaped}%')`,
    ).join("\nUNION ALL\n");
    const concepts = (await db.all(`${conceptSql} LIMIT 8`)) as unknown as ConceptHit[];
    if (concepts.length > 0) {
      p.log.info("matching concepts:");
      for (const c of concepts) {
        console.log(`  [${c.domain}] ${c.id}  (${c.kind})  — ${c.name}`);
      }
    }
    const cmdSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, id, command, purpose
      FROM ${d}.commands
      WHERE LOWER(command) LIKE LOWER('%${escaped}%')
         OR LOWER(purpose) LIKE LOWER('%${escaped}%')`,
    ).join("\nUNION ALL\n");
    const cmds = (await db.all(`${cmdSql} LIMIT 8`)) as unknown as CommandHit[];
    if (cmds.length > 0) {
      p.log.info("matching commands:");
      for (const c of cmds) {
        console.log(`  [${c.domain}] ${c.command}  — ${c.purpose}`);
      }
    }
    const words = text
      .split(/\s+/)
      .map((w) => w.replace(/[^a-zA-Z0-9_-]/g, ""))
      .filter((w) => w.length >= 3);
    const wordClauses = words.length > 0
      ? words
          .map((w) => `LOWER(symptom) LIKE LOWER('%${w}%')
               OR LOWER(id) LIKE LOWER('%${w}%')
               OR LOWER(root_cause_class) LIKE LOWER('%${w}%')
               OR EXISTS (SELECT 1 FROM unnest(error_patterns) AS t(p) WHERE LOWER(p) LIKE LOWER('%${w}%'))`)
          .join("\n            OR ")
      : `LOWER(symptom) LIKE LOWER('%${escaped}%')`;
    const matchExpr = words.length > 0
      ? `(${words.map((w) => `(CASE WHEN LOWER(symptom) LIKE LOWER('%${w}%') OR LOWER(id) LIKE LOWER('%${w}%') THEN 1 ELSE 0 END)`).join(" + ")})`
      : `0`;
    const fmSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, id, symptom, root_cause_class, confidence,
        ${matchExpr} AS match_strength
      FROM ${d}.failure_modes
      WHERE ${wordClauses}`,
    ).join("\nUNION ALL\n") + " ORDER BY match_strength DESC";
    const fms = (await db.all(`${fmSql} LIMIT 8`)) as unknown as FailureHit[];
    if (fms.length > 0) {
      p.log.info("matching failure modes (use `harness playbook <id>`):");
      for (const f of fms) {
        console.log(`  [${f.domain}] ${f.id}  (conf=${f.confidence})  — ${f.symptom}`);
      }
    }
  } finally {
    await db.close();
  }
}
