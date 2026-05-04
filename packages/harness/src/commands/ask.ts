// `harness ask "<symptom or error message>"` — one-shot entry point that
// demonstrates well-running MCP behavior during a screen-share interview.
//
// Pipeline: keyword search across failure_modes → pick top match → render
// polished playbook with talk-track on top. Falls back to lookup-style
// document/concept hits when no fm matches.

import { openDb, DOMAINS } from "../db.ts";
import {
  bold, dim, gray, red, yellow, cyan, green,
  header, section, talkTrack, stepLine, commandLine, expectLine,
  citationLine, chip, confidenceChip, domainChip, hr,
} from "../output.ts";

interface Step {
  step: number;
  action: string;
  command: string | null;
  expected?: string | null;
  validation?: string | null;
  rollback?: string | null;
  source_id?: string | null;
}
interface FmRow {
  domain: string;
  id: string;
  symptom: string;
  error_patterns: string[] | null;
  root_cause_class: string | null;
  affected_concepts: string[] | null;
  diagnostic_steps: Step[] | null;
  fix_steps: Step[] | null;
  confidence: number | null;
  source_ids: string[] | null;
  match_strength: number | bigint;
}
interface DocHit {
  domain: string;
  source_id: string;
  title: string | null;
  url: string | null;
  score: number;
  snippet: string | null;
}

export async function askCmd(args: string[]): Promise<void> {
  const text = args.join(" ").trim();
  if (!text) {
    console.error(red("usage: harness ask \"<symptom or error message>\""));
    console.error(dim("       harness ask \"OOMKilled in /var/log/messages\""));
    console.error(dim("       harness ask \"pod stuck in Pending\""));
    process.exit(1);
  }

  const escaped = text.replace(/'/g, "''");
  const words = text
    .split(/\s+/)
    .map((w) => w.replace(/[^a-zA-Z0-9_-]/g, "").toLowerCase())
    .filter((w) => w.length >= 3);

  const db = await openDb();
  try {
    console.log("");
    console.log(header("harness ask", `query: ${text}`));

    const fms = await rankFms(db, escaped, words);
    if (fms.length === 0) {
      console.log("");
      console.log(yellow("⚠  no failure modes matched. Falling back to BM25 doc search."));
      await fallbackDocs(db, escaped, text);
      return;
    }

    const top = fms[0]!;
    const topStrength = Number(top.match_strength);
    // Alternates must (a) be at least 50% as strong AND (b) share a substantive
    // token (>=4 chars) with the top fm's id, so the "also plausible" line names
    // genuine variants (e.g. docker oom vs k8s oom) rather than incidental
    // keyword overlap (e.g. ecs.awslogs matching on "logs").
    const topTokens = tokensFromId(top.id);
    const others = fms
      .slice(1, 5)
      .filter((f) => Number(f.match_strength) >= Math.max(topStrength * 0.5, 3))
      .filter((f) => tokensFromId(f.id).some((tok) => topTokens.includes(tok)))
      .slice(0, 2);

    console.log(section("MATCH"));
    console.log(`  ${domainChip(top.domain)} ${bold(top.id)}  ${confidenceChip(top.confidence)}  ${chip("match", String(Number(top.match_strength)), gray)}`);
    console.log(`  ${red("Symptom:")} ${top.symptom}`);
    if (top.root_cause_class) console.log(`  ${dim("Root-cause class:")} ${top.root_cause_class}`);
    if (top.error_patterns?.length) {
      console.log(`  ${dim("Error patterns:")} ${top.error_patterns.slice(0, 3).join(" | ")}`);
    }
    if (others.length > 0) {
      console.log(`  ${dim("Also plausible:")} ${others.map((f) => `${f.id}${f.confidence ? ` (${f.confidence})` : ""}`).join("  ·  ")}`);
    }

    console.log("");
    console.log(talkTrack({
      symptom: top.symptom,
      rootCauseClass: top.root_cause_class,
      diagFirstAction: top.diagnostic_steps?.[0]?.action ?? null,
      fixFirstAction: top.fix_steps?.[0]?.action ?? null,
      alternateFms: others.map((f) => f.id),
    }));

    console.log(section("DIAGNOSE"));
    if (!top.diagnostic_steps?.length) {
      console.log(dim("  (no diagnostic steps recorded — see citations)"));
    } else {
      for (const s of top.diagnostic_steps) {
        console.log(stepLine(s.step, s.action, "diag"));
        if (s.command) console.log(commandLine(s.command));
        if (s.expected) console.log(expectLine("expect", s.expected));
        if (s.source_id) console.log(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    console.log(section("FIX"));
    if (!top.fix_steps?.length) {
      console.log(dim("  (no fix steps recorded — see citations)"));
    } else {
      for (const s of top.fix_steps) {
        console.log(stepLine(s.step, s.action, "fix"));
        if (s.command) console.log(commandLine(s.command));
        if (s.validation) console.log(expectLine("validate", s.validation));
        if (s.rollback) console.log(expectLine("rollback", s.rollback));
        if (s.source_id) console.log(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    if (top.source_ids?.length) {
      console.log(section("CITATIONS"));
      const inList = top.source_ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
      const srcSql = DOMAINS.map(
        (d) => `SELECT '${d}' AS domain, id, title, url FROM ${d}.sources WHERE id IN (${inList})`,
      ).join("\nUNION ALL\n");
      interface Src { domain: string; id: string; title: string | null; url: string | null }
      const srcs = (await db.all(srcSql)) as unknown as Src[];
      for (const s of srcs) console.log(citationLine(s.id, s.title, s.url));
    }

    console.log(section("NEXT"));
    console.log(`  ${dim("Drill this scenario:")}    ${green("pnpm harness drill " + top.id)}`);
    console.log(`  ${dim("See more matches:")}      ${green("pnpm harness lookup \"" + text + "\"")}`);
    console.log(`  ${dim("Walk related concepts:")} ${green("pnpm harness related " + top.id)}`);
    console.log(`  ${dim("Capture diagnostics:")}   ${green("pnpm harness capture --from-fm " + top.id)}`);
    console.log("");
    console.log(hr());
  } finally {
    await db.close();
  }
}

function tokensFromId(id: string): string[] {
  return id
    .toLowerCase()
    .split(/[.\-_]+/)
    .filter((t) => t.length >= 4 && !["agent"].includes(t));
}

async function rankFms(db: import("duckdb-async").Database, escaped: string, words: string[]): Promise<FmRow[]> {
  if (words.length === 0) {
    const sql = DOMAINS.map(
      (d) => `
      SELECT '${d}' AS domain, id, symptom, error_patterns, root_cause_class,
             affected_concepts, diagnostic_steps, fix_steps, confidence, source_ids,
             1 AS match_strength
      FROM ${d}.failure_modes
      WHERE LOWER(symptom) LIKE LOWER('%${escaped}%')`,
    ).join("\nUNION ALL\n") + " ORDER BY confidence DESC NULLS LAST LIMIT 5";
    return (await db.all(sql)) as unknown as FmRow[];
  }
  const matchExpr = words.map((w) => `
      (CASE WHEN regexp_matches(LOWER(symptom),  '\\b${w}\\b') THEN 3 ELSE 0 END)
    + (CASE WHEN regexp_matches(LOWER(id),       '\\b${w}\\b') THEN 2 ELSE 0 END)
    + (CASE WHEN regexp_matches(LOWER(coalesce(root_cause_class, '')), '\\b${w}\\b') THEN 2 ELSE 0 END)
    + (CASE WHEN EXISTS (SELECT 1 FROM unnest(error_patterns)    AS t(p) WHERE regexp_matches(LOWER(p), '\\b${w}\\b')) THEN 4 ELSE 0 END)
    + (CASE WHEN EXISTS (SELECT 1 FROM unnest(affected_concepts) AS t(c) WHERE regexp_matches(LOWER(c), '\\b${w}\\b')) THEN 1 ELSE 0 END)
  `).join(" + ");
  const wheres = words.map((w) => `(
       regexp_matches(LOWER(symptom),  '\\b${w}\\b')
    OR regexp_matches(LOWER(id),       '\\b${w}\\b')
    OR regexp_matches(LOWER(coalesce(root_cause_class, '')), '\\b${w}\\b')
    OR EXISTS (SELECT 1 FROM unnest(error_patterns)    AS t(p) WHERE regexp_matches(LOWER(p), '\\b${w}\\b'))
    OR EXISTS (SELECT 1 FROM unnest(affected_concepts) AS t(c) WHERE regexp_matches(LOWER(c), '\\b${w}\\b'))
  )`).join(" OR ");
  const sql = DOMAINS.map(
    (d) => `
      SELECT '${d}' AS domain, id, symptom, error_patterns, root_cause_class,
             affected_concepts, diagnostic_steps, fix_steps, confidence, source_ids,
             (${matchExpr}) AS match_strength
      FROM ${d}.failure_modes
      WHERE ${wheres}`,
  ).join("\nUNION ALL\n") + " ORDER BY match_strength DESC, confidence DESC NULLS LAST LIMIT 5";
  return (await db.all(sql)) as unknown as FmRow[];
}

async function fallbackDocs(db: import("duckdb-async").Database, escaped: string, original: string): Promise<void> {
  const unionSql = DOMAINS.map(
    (d) => `
      SELECT '${d}' AS domain, d.source_id, s.title, s.url,
        fts_${d}_documents.match_bm25(d.source_id, '${escaped}') AS score,
        SUBSTRING(d.content_md, 1, 240) AS snippet
      FROM ${d}.documents d
      LEFT JOIN ${d}.sources s ON s.id = d.source_id
      WHERE fts_${d}_documents.match_bm25(d.source_id, '${escaped}') IS NOT NULL`,
  ).join("\nUNION ALL\n");
  const sql = `${unionSql} ORDER BY score DESC NULLS LAST LIMIT 8`;
  const rows = (await db.all(sql)) as unknown as DocHit[];
  console.log(section("TOP DOC HITS"));
  if (rows.length === 0) {
    console.log(dim("  (no hits)"));
    console.log("");
    console.log(yellow("Suggestion: rephrase with the literal error string, e.g. \"OOMKilled\", \"ImagePullBackOff\", \"connection refused\"."));
    return;
  }
  for (const r of rows) {
    const snippet = String(r.snippet ?? "").replace(/\s+/g, " ").trim().slice(0, 180);
    console.log(`  ${domainChip(r.domain)} ${cyan(Number(r.score).toFixed(2))}  ${bold(r.source_id)}  ${dim(r.title ?? "")}`);
    console.log(`     ${dim(snippet)}`);
  }
  console.log("");
  console.log(`${dim("Drill into a doc:")} ${green("pnpm harness cite <source-id>")}`);
  console.log(`${dim("Or look up by keyword:")} ${green("pnpm harness lookup \"" + original + "\"")}`);
}
