import { openDb, DOMAINS } from "../db.ts";
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

    console.log("");
    console.log(header(fm.id, fm.symptom));

    console.log(section("META"));
    const verified = fm.last_verified ? formatDate(fm.last_verified) : null;
    console.log(`  ${domainChip(fm.domain)}  ${confidenceChip(fm.confidence)}` + (verified ? `  ${dim("verified " + verified)}` : ""));
    console.log(`  ${red("Symptom:")} ${fm.symptom}`);
    if (fm.root_cause_class) console.log(`  ${dim("Root-cause class:")} ${fm.root_cause_class}`);
    if (fm.error_patterns?.length) {
      console.log(`  ${dim("Error patterns:")} ${fm.error_patterns.join(" | ")}`);
    }
    if (fm.affected_concepts?.length) {
      console.log(`  ${dim("Affects:")} ${fm.affected_concepts.join(", ")}`);
    }

    console.log("");
    console.log(talkTrack({
      symptom: fm.symptom,
      rootCauseClass: fm.root_cause_class,
      diagFirstAction: fm.diagnostic_steps?.[0]?.action ?? null,
      fixFirstAction: fm.fix_steps?.[0]?.action ?? null,
    }));

    console.log(section("DIAGNOSE"));
    if (!fm.diagnostic_steps?.length) {
      console.log(dim("  (no diagnostic steps recorded)"));
    } else {
      for (const s of fm.diagnostic_steps) {
        console.log(stepLine(s.step, s.action, "diag"));
        if (s.command) console.log(commandLine(s.command));
        if (s.expected) console.log(expectLine("expect", s.expected));
        if (s.source_id) console.log(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    console.log(section("FIX"));
    if (!fm.fix_steps?.length) {
      console.log(dim("  (no fix steps recorded)"));
    } else {
      for (const s of fm.fix_steps) {
        console.log(stepLine(s.step, s.action, "fix"));
        if (s.command) console.log(commandLine(s.command));
        if (s.validation) console.log(expectLine("validate", s.validation));
        if (s.rollback) console.log(expectLine("rollback", s.rollback));
        if (s.source_id) console.log(`       ${dim("[src: " + s.source_id + "]")}`);
      }
    }

    if (fm.source_ids?.length) {
      console.log(section("CITATIONS"));
      const inList = fm.source_ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
      const srcSql = DOMAINS.map(
        (d) => `SELECT '${d}' AS domain, id, title, url FROM ${d}.sources WHERE id IN (${inList})`,
      ).join("\nUNION ALL\n");
      interface SrcRow { domain: string; id: string; title: string | null; url: string | null }
      const srcs = (await db.all(srcSql)) as unknown as SrcRow[];
      for (const s of srcs) console.log(citationLine(s.id, s.title, s.url));
    }

    console.log(section("NEXT"));
    console.log(`  ${dim("Drill it:")}        ${green("pnpm harness drill " + fm.id)}`);
    console.log(`  ${dim("Walk concepts:")}   ${green("pnpm harness related " + fm.id)}`);
    console.log(`  ${dim("Capture diags:")}   ${green("pnpm harness capture --from-fm " + fm.id)}`);
    console.log("");
    console.log(hr());
  } finally {
    await db.close();
  }
}
