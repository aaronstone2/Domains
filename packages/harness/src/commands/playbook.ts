import { openDb, DOMAINS } from "../db.ts";
import { println } from "../output.ts";
import {
  dim, red, green,
  header, section, talkTrack, stepLine, commandLine, expectLine,
  citationLine, confidenceChip, domainChip, hr,
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

interface FailureModeRow {
  domain: string;
  id: string;
  symptom: string;
  error_patterns: string[] | null;
  root_cause_class: string | null;
  affected_concepts: string[] | null;
  diagnostic_steps: Step[] | null;
  fix_steps: Step[] | null;
  confidence: number | null;
  last_verified: string | Date | null;
  source_ids: string[] | null;
}

function formatDate(d: string | Date): string {
  if (d instanceof Date) return d.toISOString().slice(0, 10);
  const s = String(d);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

export async function playbookCmd(args: string[]): Promise<void> {
  const id = args[0]?.trim();
  if (!id) {
    console.error(red("usage: harness playbook <failure-mode-id>"));
    process.exit(1);
  }
  const escaped = id.replace(/'/g, "''");
  const db = await openDb();
  try {
    const sql = DOMAINS.map(
      (d) => `SELECT '${d}' AS domain, * FROM ${d}.failure_modes WHERE id = '${escaped}'`,
    ).join("\nUNION ALL\n");
    const rows = (await db.all(sql)) as unknown as FailureModeRow[];
    if (rows.length === 0) {
      console.error(red(`failure mode not found: ${id}`));
      process.exit(2);
    }
    const fm = rows[0]!;

    println("");
    println(header(fm.id, fm.symptom));

    println(section("META"));
    const verified = fm.last_verified ? formatDate(fm.last_verified) : null;
    println(`  ${domainChip(fm.domain)}  ${confidenceChip(fm.confidence)}` + (verified ? `  ${dim("verified " + verified)}` : ""));
    println(`  ${red("Symptom:")} ${fm.symptom}`);
    if (fm.root_cause_class) println(`  ${dim("Root-cause class:")} ${fm.root_cause_class}`);
    if (fm.error_patterns?.length) {
      println(`  ${dim("Error patterns:")} ${fm.error_patterns.join(" | ")}`);
    }
    if (fm.affected_concepts?.length) {
      println(`  ${dim("Affects:")} ${fm.affected_concepts.join(", ")}`);
    }

    println("");
    println(talkTrack({
      symptom: fm.symptom,
      rootCauseClass: fm.root_cause_class,
      diagFirstAction: fm.diagnostic_steps?.[0]?.action ?? null,
      fixFirstAction: fm.fix_steps?.[0]?.action ?? null,
    }));

    println(section("DIAGNOSE"));
    if (!fm.diagnostic_steps?.length) {
      println(dim("  (no diagnostic steps recorded)"));
    } else {
      for (const s of fm.diagnostic_steps) {
        println(stepLine(s.step, s.action, "diag"));
        if (s.command) println(commandLine(s.command));
        if (s.expected) println(expectLine("expect", s.expected));
        if (s.source_id) println(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    println(section("FIX"));
    if (!fm.fix_steps?.length) {
      println(dim("  (no fix steps recorded)"));
    } else {
      for (const s of fm.fix_steps) {
        println(stepLine(s.step, s.action, "fix"));
        if (s.command) println(commandLine(s.command));
        if (s.validation) println(expectLine("validate", s.validation));
        if (s.rollback) println(expectLine("rollback", s.rollback));
        if (s.source_id) println(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    if (fm.source_ids?.length) {
      println(section("CITATIONS"));
      const inList = fm.source_ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
      const srcSql = DOMAINS.map(
        (d) => `SELECT '${d}' AS domain, id, title, url FROM ${d}.sources WHERE id IN (${inList})`,
      ).join("\nUNION ALL\n");
      interface SrcRow { domain: string; id: string; title: string | null; url: string | null }
      const srcs = (await db.all(srcSql)) as unknown as SrcRow[];
      for (const s of srcs) println(citationLine(s.id, s.title, s.url));
    }

    println(section("NEXT"));
    println(`  ${dim("Drill it:")}        ${green("pnpm harness drill " + fm.id)}`);
    println(`  ${dim("Walk concepts:")}   ${green("pnpm harness related " + fm.id)}`);
    println(`  ${dim("Capture diags:")}   ${green("pnpm harness capture --from-fm " + fm.id)}`);
    println("");
    println(hr());
  } finally {
    await db.close();
  }
}
