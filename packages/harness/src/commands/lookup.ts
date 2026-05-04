import { openDb, DOMAINS } from "../db.ts";
import {
  bold, dim, red, green, cyan,
  header, section, hr, domainChip, confidenceChip,
} from "../output.ts";

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
    console.error(red("usage: harness lookup <query text>"));
    process.exit(1);
  }
  const escaped = text.replace(/'/g, "''");
  const db = await openDb();
  try {
    console.log("");
    console.log(header("harness lookup", `query: ${text}`));

    const STOPWORDS = new Set([
      "the", "and", "but", "for", "are", "you", "this", "that", "with", "have",
      "has", "had", "what", "when", "why", "how", "got", "get", "its", "from",
      "was", "were", "been", "into", "out", "all", "any", "can", "not", "one",
      "two", "his", "her", "she", "him", "they", "them", "our", "your", "their",
      "just", "yet", "now", "also", "only", "still", "very", "more", "most",
      "much", "some", "make", "made", "let", "see", "say", "said", "fine", "do",
      "does", "did", "doing", "doesnt", "thing", "things", "really", "feels",
      "look", "looks", "seem", "seems", "going", "goes", "went", "should",
      "would", "could", "may", "might", "must", "ago", "new", "old", "other",
      "another", "same", "different", "show", "shows", "shown", "tell", "tells",
      "told", "ask", "asked", "asking", "ive", "weve", "youre", "im", "isnt",
      "arent",
    ]);
    const words = Array.from(new Set(
      text
        .split(/\s+/)
        .map((w) => w.replace(/[^a-zA-Z0-9_-]/g, "").toLowerCase())
        .filter((w) => w.length >= 3 && !STOPWORDS.has(w)),
    ));
    const wordClauses = words.length > 0
      ? words
          .map((w) => `regexp_matches(LOWER(symptom), '\\b${w}\\b')
               OR regexp_matches(LOWER(id), '\\b${w}\\b')
               OR regexp_matches(LOWER(coalesce(root_cause_class, '')), '\\b${w}\\b')
               OR EXISTS (SELECT 1 FROM unnest(error_patterns) AS t(p) WHERE regexp_matches(LOWER(p), '\\b${w}\\b'))`)
          .join("\n            OR ")
      : `LOWER(symptom) LIKE LOWER('%${escaped}%')`;
    const matchExpr = words.length > 0
      ? `(${words.map((w) => `
        (CASE WHEN regexp_matches(LOWER(symptom),  '\\b${w}\\b') THEN 4 ELSE 0 END)
      + (CASE WHEN regexp_matches(LOWER(id),       '\\b${w}\\b') THEN 3 ELSE 0 END)
      + (CASE WHEN regexp_matches(LOWER(coalesce(root_cause_class, '')), '\\b${w}\\b') THEN 2 ELSE 0 END)
      + (CASE WHEN EXISTS (SELECT 1 FROM unnest(error_patterns) AS t(p) WHERE regexp_matches(LOWER(p), '\\b${w}\\b')) THEN 4 ELSE 0 END)`).join(" + ")})`
      : `0`;
    const fmSql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, id, symptom, root_cause_class, confidence,
        ${matchExpr} AS match_strength
      FROM ${d}.failure_modes
      WHERE ${wordClauses}`,
    ).join("\nUNION ALL\n") + " ORDER BY match_strength DESC, confidence DESC NULLS LAST";
    const fms = (await db.all(`${fmSql} LIMIT 8`)) as unknown as FailureHit[];

    if (fms.length > 0) {
      console.log(section("FAILURE MODES"));
      console.log(dim("  (rank by keyword match × confidence — try `harness playbook <id>`)"));
      console.log("");
      for (const f of fms) {
        console.log(`  ${domainChip(f.domain)} ${bold(f.id)}  ${confidenceChip(f.confidence)}`);
        console.log(`     ${f.symptom}`);
        if (f.root_cause_class) console.log(`     ${dim("class:")} ${f.root_cause_class}`);
      }
    } else {
      console.log(section("FAILURE MODES"));
      console.log(dim("  (no failure-mode matches)"));
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
      console.log(section("COMMANDS"));
      for (const c of cmds) {
        console.log(`  ${domainChip(c.domain)} ${green("$")} ${c.command}`);
        console.log(`     ${dim(c.purpose)}`);
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
      console.log(section("CONCEPTS"));
      for (const c of concepts) {
        console.log(`  ${domainChip(c.domain)} ${bold(c.id)}  ${dim("(" + c.kind + ")")}  ${c.name}`);
      }
    }

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
    const sql = `${unionSql}\nORDER BY score DESC NULLS LAST LIMIT 6`;
    const docs = (await db.all(sql)) as unknown as DocHit[];
    if (docs.length > 0) {
      console.log(section("DOCS (BM25)"));
      for (const r of docs) {
        const score = Number(r.score).toFixed(2);
        const snippet = String(r.snippet ?? "").replace(/\s+/g, " ").trim().slice(0, 180);
        console.log(`  ${domainChip(r.domain)} ${cyan(score)}  ${bold(r.source_id)}  ${dim(r.title ?? "")}`);
        console.log(`     ${dim(snippet)}`);
      }
    }

    if (fms.length === 0 && cmds.length === 0 && concepts.length === 0 && docs.length === 0) {
      console.log("");
      console.log(red(`no hits for "${text}"`));
    } else {
      console.log(section("NEXT"));
      if (fms.length > 0 && fms[0]) {
        console.log(`  ${dim("Open top playbook:")}  ${green("pnpm harness playbook " + fms[0].id)}`);
        console.log(`  ${dim("One-shot answer:")}    ${green("pnpm harness ask \"" + text + "\"")}`);
      }
      console.log("");
      console.log(hr());
    }
  } finally {
    await db.close();
  }
}
