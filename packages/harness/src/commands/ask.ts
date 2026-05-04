// `harness ask "<symptom or error message>"` — one-shot entry point that
// demonstrates well-running MCP behavior during a screen-share interview.
//
// Pipeline: keyword search across failure_modes → pick top match → render
// polished playbook with talk-track on top. Falls back to lookup-style
// document/concept hits when no fm matches.

import { openDb, DOMAINS } from "../db.ts";
import { println } from "../output.ts";
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

  const db = await openDb();
  try {
    println("");
    println(header("harness ask", `query: ${text}`));

    const fms = await rankFms(db, escaped, words);
    // Make sure curated shortcut targets are always in the candidate pool —
    // they may not have any keyword matches against the user's natural-language
    // input, but the shortcut bonus elevates them once present.
    const shortcutPromotions = SHORTCUTS
      .filter((s) => s.when.every((rx) => rx.test(text.toLowerCase())))
      .map((s) => s.promote);
    if (shortcutPromotions.length > 0) {
      const missing = shortcutPromotions.filter((id) => !fms.some((f) => f.id === id));
      if (missing.length > 0) {
        const extras = await fetchFmsByIds(db, missing);
        for (const e of extras) fms.push(e);
      }
    }
    if (fms.length === 0) {
      println("");
      println(yellow("⚠  no failure modes matched. Falling back to BM25 doc search."));
      await fallbackDocs(db, escaped, text);
      return;
    }

    // Apply curated shortcuts: if the input matches a well-known phrase pattern,
    // give the canonical fm a heavy bonus so it overrides incidental keyword
    // matches. Keeps the top-30 most-common debugging queries deterministic.
    applyShortcuts(text.toLowerCase(), fms);
    fms.sort((a, b) => Number(b.match_strength) - Number(a.match_strength)
      || (Number(b.confidence ?? 0) - Number(a.confidence ?? 0)));

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

    println(section("MATCH"));
    println(`  ${domainChip(top.domain)} ${bold(top.id)}  ${confidenceChip(top.confidence)}  ${chip("match", String(Number(top.match_strength)), gray)}`);
    println(`  ${red("Symptom:")} ${top.symptom}`);
    if (top.root_cause_class) println(`  ${dim("Root-cause class:")} ${top.root_cause_class}`);
    if (top.error_patterns?.length) {
      println(`  ${dim("Error patterns:")} ${top.error_patterns.slice(0, 3).join(" | ")}`);
    }
    if (others.length > 0) {
      println(`  ${dim("Also plausible:")} ${others.map((f) => `${f.id}${f.confidence ? ` (${f.confidence})` : ""}`).join("  ·  ")}`);
    }

    println("");
    println(talkTrack({
      symptom: top.symptom,
      rootCauseClass: top.root_cause_class,
      diagFirstAction: top.diagnostic_steps?.[0]?.action ?? null,
      fixFirstAction: top.fix_steps?.[0]?.action ?? null,
      alternateFms: others.map((f) => f.id),
    }));

    println(section("DIAGNOSE"));
    if (!top.diagnostic_steps?.length) {
      println(dim("  (no diagnostic steps recorded — see citations)"));
    } else {
      for (const s of top.diagnostic_steps) {
        println(stepLine(s.step, s.action, "diag"));
        if (s.command) println(commandLine(s.command));
        if (s.expected) println(expectLine("expect", s.expected));
        if (s.source_id) println(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    println(section("FIX"));
    if (!top.fix_steps?.length) {
      println(dim("  (no fix steps recorded — see citations)"));
    } else {
      for (const s of top.fix_steps) {
        println(stepLine(s.step, s.action, "fix"));
        if (s.command) println(commandLine(s.command));
        if (s.validation) println(expectLine("validate", s.validation));
        if (s.rollback) println(expectLine("rollback", s.rollback));
        if (s.source_id) println(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    if (top.source_ids?.length) {
      println(section("CITATIONS"));
      const inList = top.source_ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
      const srcSql = DOMAINS.map(
        (d) => `SELECT '${d}' AS domain, id, title, url FROM ${d}.sources WHERE id IN (${inList})`,
      ).join("\nUNION ALL\n");
      interface Src { domain: string; id: string; title: string | null; url: string | null }
      const srcs = (await db.all(srcSql)) as unknown as Src[];
      for (const s of srcs) println(citationLine(s.id, s.title, s.url));
    }

    println(section("NEXT"));
    println(`  ${dim("Drill this scenario:")}    ${green("pnpm harness drill " + top.id)}`);
    println(`  ${dim("See more matches:")}      ${green("pnpm harness lookup \"" + text + "\"")}`);
    println(`  ${dim("Walk related concepts:")} ${green("pnpm harness related " + top.id)}`);
    println(`  ${dim("Capture diagnostics:")}   ${green("pnpm harness capture --from-fm " + top.id)}`);
    println("");
    println(hr());
  } finally {
    await db.close();
  }
}

// Curated shortcut patterns — when a user input matches one of these, the named
// fm gets +25 added to its match_strength. Keeps the most-common queries
// deterministic and prevents accidentally-similar fms from winning.
//
// Pattern semantics: ALL keywords/regexes must match the (lowercased) input.
// Use word-boundary regexes for narrower matches.
const SHORTCUTS: Array<{ when: RegExp[]; promote: string }> = [
  { when: [/\boom(killed)?\b/i, /\bcontainer\b|\bdocker\b/i], promote: "docker.fm.exit-137-oomkilled" },
  { when: [/\boom(killed)?\b/i, /\bpod\b|\bk8s\b|\bkube/i],   promote: "k8s.fm.oomkilled" },
  { when: [/\bexit (code )?137\b/i],                          promote: "docker.fm.exit-137-oomkilled" },
  { when: [/\bpending\b/i, /\bpod\b/i],                       promote: "k8s.fm.pod-pending-failedscheduling" },
  { when: [/\bdns\b/i, /\bslow\b|\b3 ?second|\b3s\b|\b5 ?second\b/i, /\bpod\b|\bcontainer\b/i], promote: "k8s.fm.dns-pod-search-too-many" },
  { when: [/\bndots\b/i],                                     promote: "k8s.fm.dns-pod-search-too-many" },
  { when: [/\bkill -9\b/i, /\b(stuck|frozen|hung)\b/i],       promote: "linux.fm.process-stuck-d-state" },
  { when: [/\bd[- ]state\b/i],                                promote: "linux.fm.process-stuck-d-state" },
  { when: [/\buninterruptible\b/i],                           promote: "linux.fm.process-stuck-d-state" },
  { when: [/\bsystemd\b/i, /\b(unit|service)\b/i, /\b(restart|loop|fail|wont|won't)\b/i], promote: "linux.fm.systemd-unit-restart-loop" },
  { when: [/\bcurl\b|\bping\b/i, /\bcontainer\b/i, /\b(hang|fail|timeout|refuse)/i], promote: "docker.fm.container-no-egress-umbrella" },
  { when: [/\bumbrella\b|\bcisco\b/i],                        promote: "docker.fm.container-no-egress-umbrella" },
  { when: [/\bdrain\b/i, /\bk8s\b|\bnode\b|\bkubectl\b/i, /\bhang|\bstuck/i], promote: "k8s.fm.pdb-blocks-drain" },
  { when: [/\bpdb\b|\bpoddisruption/i],                       promote: "k8s.fm.pdb-blocks-drain" },
  { when: [/\bimage pull\b|\bimagepullbackoff\b/i, /\bauth|\bunauthorized|\bdenied|\bregistry\b/i], promote: "docker.fm.image-pull-private-registry-auth" },
  { when: [/\bpull access denied\b/i],                        promote: "docker.fm.image-pull-private-registry-auth" },
  { when: [/\btoomanyrequests\b|\brate ?limit\b/i, /\bdocker hub\b|\bregistry\b|\bpull\b/i], promote: "docker.fm.image-pull-rate-limit" },
  { when: [/\bdevin\b/i, /\b(internal|private|corporate)\b/i, /\b(reach|connect|access|service)\b/i], promote: "devin.fm.session-cant-reach-internal-svc" },
  { when: [/\bdevin\b/i, /\bvpn\b/i],                         promote: "devin.fm.vpn-not-engaging" },
  { when: [/\bcpu\b/i, /\b(low|idle)\b/i, /\bslow\b/i],       promote: "methodology.fm.cpu-utilization-misleading" },
  { when: [/\b(blame|trial)\b/i, /\b(postmortem|retro|incident)\b/i], promote: "methodology.fm.retro-becomes-trial" },
  { when: [/\b(zombie|defunct)\b/i, /\bcontainer\b/i],        promote: "docker.fm.zombie-processes-leaking" },
  { when: [/\biptables\b/i, /\b-f\b|flush(ed)?\b/i],          promote: "docker.fm.iptables-docker-chain-flushed" },
  { when: [/\bcontainer\b/i, /\bzombie|\bdefunct/i],          promote: "docker.fm.zombie-processes-leaking" },
  { when: [/\bevicted\b/i, /\bpod\b|\bnode\b/i],              promote: "k8s.fm.evicted-by-node-pressure" },
  { when: [/\bcrashloopbackoff\b/i],                          promote: "k8s.fm.crashloopbackoff-app-crash" },
  { when: [/\binit container\b|\binitcontainer\b/i, /\bfail|\berror|\bstuck/i], promote: "k8s.fm.init-container-failed" },
  { when: [/\bwebhook\b/i, /\b(timeout|fail|denied|reject)/i], promote: "k8s.fm.validating-webhook-policy-rejects" },
  { when: [/\bovermount(ed)?\b|\bmount\b.*\boverlay\b|\boverlay\b.*\bmount\b/i], promote: "linux.fm.bind-mount-shadows-files" },
  { when: [/\bnetfilter\b/i, /\b(rule|order|jump)\b/i],       promote: "linux.fm.netfilter-rule-order" },
];

function applyShortcuts(input: string, fms: FmRow[]): void {
  for (const shortcut of SHORTCUTS) {
    if (shortcut.when.every((rx) => rx.test(input))) {
      const target = fms.find((f) => f.id === shortcut.promote);
      if (target) {
        // Bump strongly so curated answer overrides incidental keyword matches.
        // Use 50 (vs typical natural-language scores of 8–30) so a curated hit
        // always wins, even if a thematically-adjacent fm has more keyword overlap.
        target.match_strength = Number(target.match_strength) + 50;
      }
    }
  }
}

async function fetchFmsByIds(db: import("duckdb-async").Database, ids: string[]): Promise<FmRow[]> {
  if (ids.length === 0) return [];
  const inList = ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
  const sql = DOMAINS.map(
    (d) => `
      SELECT '${d}' AS domain, id, symptom, error_patterns, root_cause_class,
             affected_concepts, diagnostic_steps, fix_steps, confidence, source_ids,
             0 AS match_strength
      FROM ${d}.failure_modes
      WHERE id IN (${inList})`,
  ).join("\nUNION ALL\n");
  return (await db.all(sql)) as unknown as FmRow[];
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
  // Symptom is the most "intentful" field — it's a deliberate one-line summary
  // of the problem. Weight it highest. Error patterns are second-most reliable
  // (they're the literal strings users see in logs).
  const matchExpr = words.map((w) => `
      (CASE WHEN regexp_matches(LOWER(symptom),  '\\b${w}\\b') THEN 5 ELSE 0 END)
    + (CASE WHEN regexp_matches(LOWER(id),       '\\b${w}\\b') THEN 3 ELSE 0 END)
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
  ).join("\nUNION ALL\n") + " ORDER BY match_strength DESC, confidence DESC NULLS LAST LIMIT 25";
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
  println(section("TOP DOC HITS"));
  if (rows.length === 0) {
    println(dim("  (no hits)"));
    println("");
    println(yellow("Suggestion: rephrase with the literal error string, e.g. \"OOMKilled\", \"ImagePullBackOff\", \"connection refused\"."));
    return;
  }
  for (const r of rows) {
    const snippet = String(r.snippet ?? "").replace(/\s+/g, " ").trim().slice(0, 180);
    println(`  ${domainChip(r.domain)} ${cyan(Number(r.score).toFixed(2))}  ${bold(r.source_id)}  ${dim(r.title ?? "")}`);
    println(`     ${dim(snippet)}`);
  }
  println("");
  println(`${dim("Drill into a doc:")} ${green("pnpm harness cite <source-id>")}`);
  println(`${dim("Or look up by keyword:")} ${green("pnpm harness lookup \"" + original + "\"")}`);
}
