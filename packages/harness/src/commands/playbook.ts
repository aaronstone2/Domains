import * as p from "@clack/prompts";
import { openDb, DOMAINS } from "../db.ts";

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

export async function playbookCmd(args: string[]): Promise<void> {
  const id = args[0]?.trim();
  if (!id) {
    p.log.error("usage: harness playbook <failure-mode-id>");
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
      p.log.error(`failure mode not found: ${id}`);
      process.exit(2);
    }
    const fm = rows[0]!;
    console.log(`\n=== ${fm.id}  [${fm.domain}] ===`);
    console.log(`Symptom: ${fm.symptom}`);
    if (fm.root_cause_class) console.log(`Root cause class: ${fm.root_cause_class}`);
    if (fm.confidence !== null) console.log(`Confidence: ${fm.confidence}`);
    if (fm.last_verified) console.log(`Last verified: ${fm.last_verified}`);
    if (fm.error_patterns?.length) {
      console.log(`Patterns: ${fm.error_patterns.join(" | ")}`);
    }
    if (fm.affected_concepts?.length) {
      console.log(`Affects: ${fm.affected_concepts.join(", ")}`);
    }
    console.log("\n-- Diagnostic steps --");
    for (const s of fm.diagnostic_steps ?? []) {
      console.log(`  ${s.step}. ${s.action}`);
      if (s.command) console.log(`     $ ${s.command}`);
      if (s.expected) console.log(`     expect: ${s.expected}`);
      if (s.source_id) console.log(`     [src: ${s.source_id}]`);
    }
    console.log("\n-- Fix steps --");
    for (const s of fm.fix_steps ?? []) {
      console.log(`  ${s.step}. ${s.action}`);
      if (s.command) console.log(`     $ ${s.command}`);
      if (s.validation) console.log(`     validate: ${s.validation}`);
      if (s.rollback) console.log(`     rollback: ${s.rollback}`);
      if (s.source_id) console.log(`     [src: ${s.source_id}]`);
    }
    if (fm.source_ids?.length) {
      console.log("\n-- Citations --");
      const inList = fm.source_ids.map((s) => `'${s.replace(/'/g, "''")}'`).join(",");
      const srcSql = DOMAINS.map(
        (d) => `SELECT '${d}' AS domain, id, title, url FROM ${d}.sources WHERE id IN (${inList})`,
      ).join("\nUNION ALL\n");
      interface SrcRow { domain: string; id: string; title: string; url: string }
      const srcs = (await db.all(srcSql)) as unknown as SrcRow[];
      for (const s of srcs) {
        console.log(`  - ${s.id}: ${s.title}`);
        console.log(`    ${s.url}`);
      }
    }
    console.log("");
  } finally {
    await db.close();
  }
}
