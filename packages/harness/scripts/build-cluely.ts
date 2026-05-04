#!/usr/bin/env -S npx tsx
// Generate cluely/02-symptom-to-fm.md, 03-top-failure-modes.md, 04-diagnostic-commands.md
// from current DB state. Re-run after corpus changes to keep Cluely uploads in sync.
//
// Run: pnpm cluely

import { Database } from "duckdb-async";
import { writeFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..", "..");
const dbPath = resolve(repoRoot, "_db", "knowledge.duckdb");
const cluelyDir = resolve(repoRoot, "cluely");

const DOMAINS = ["docker", "linux", "k8s", "devin", "methodology", "firecracker", "ecs"] as const;

interface FmRow {
  domain: string;
  id: string;
  symptom: string;
  root_cause_class: string | null;
  error_patterns: string[] | null;
  diagnostic_steps: Step[] | null;
  fix_steps: Step[] | null;
  confidence: number | null;
  source_ids: string[] | null;
}
interface Step {
  step: number;
  action: string;
  command: string | null;
  expected?: string | null;
  validation?: string | null;
  rollback?: string | null;
  source_id?: string | null;
}
interface CmdRow {
  domain: string;
  id: string;
  command: string;
  purpose: string | null;
}

async function main(): Promise<void> {
  await mkdir(cluelyDir, { recursive: true });
  const db = await Database.create(dbPath);

  // ---------- 02-symptom-to-fm.md ----------
  // Take the highest-confidence fm per "category" (heuristic: cluster by
  // distinct first-keyword in symptom). Keep it small (~80 entries).
  const fmsAll = (await db.all(
    DOMAINS.map((d) => `
      SELECT '${d}' AS domain, id, symptom, root_cause_class, error_patterns,
             diagnostic_steps, fix_steps, confidence, source_ids
      FROM ${d}.failure_modes
      WHERE confidence >= 0.85`).join(" UNION ALL ") +
    " ORDER BY confidence DESC, id"
  )) as unknown as FmRow[];

  // Group by domain for the symptom→fm doc
  const byDomain = new Map<string, FmRow[]>();
  for (const f of fmsAll) {
    if (!byDomain.has(f.domain)) byDomain.set(f.domain, []);
    byDomain.get(f.domain)!.push(f);
  }

  const sym = `# 02 — Symptom → fm-id mapping

> When the user describes a symptom, find it here, then \`ha "<keyword>"\` or \`hp <fm-id>\` directly.
>
> Auto-generated from \`_db/knowledge.duckdb\` — re-run \`pnpm cluely\` after corpus changes.

This doc lists ${fmsAll.length} high-confidence (≥ 0.85) failure modes grouped by domain. For full diag + fix per fm, see [03-top-failure-modes.md](03-top-failure-modes.md). For the commands cited, see [04-diagnostic-commands.md](04-diagnostic-commands.md).

`;

  const symParts: string[] = [sym];
  for (const dom of ["docker", "linux", "k8s", "devin", "methodology", "firecracker", "ecs"]) {
    const fms = byDomain.get(dom);
    if (!fms || fms.length === 0) continue;
    symParts.push(`## ${dom} (${fms.length} fms)\n\n| Symptom | fm-id | call |\n|---|---|---|`);
    for (const f of fms.slice(0, 25)) { // top 25 per domain
      const symShort = f.symptom.replace(/\|/g, "\\|").slice(0, 100);
      const askKw = bestAskKeyword(f);
      symParts.push(`| ${symShort} | \`${f.id}\` | \`ha "${askKw}"\` |`);
    }
    symParts.push("");
  }

  await writeFile(resolve(cluelyDir, "02-symptom-to-fm.md"), symParts.join("\n"), "utf8");
  console.error(`wrote 02-symptom-to-fm.md (${fmsAll.length} fms)`);

  // ---------- 03-top-failure-modes.md ----------
  // Top 50 fms by confidence, with full diag + fix inline.
  const top = fmsAll.slice(0, 50);

  const fmParts: string[] = [
    `# 03 — Top failure modes (50 highest-confidence, full diag/fix inline)\n\n` +
    `> When you've identified an fm-id from [02](02-symptom-to-fm.md) but the harness isn't to hand, the runbook is here.\n>\n> Auto-generated. Re-run \`pnpm cluely\` after corpus changes.\n\n` +
    `Each entry: symptom, root cause, 3+ diagnostic steps, 2+ fix steps. Cross-reference command details in [04-diagnostic-commands.md](04-diagnostic-commands.md).\n`,
  ];

  for (const f of top) {
    fmParts.push(`\n---\n\n## \`${f.id}\` ${f.confidence ? `(conf ${f.confidence})` : ""}\n`);
    fmParts.push(`**Symptom:** ${f.symptom}\n`);
    if (f.root_cause_class) fmParts.push(`**Class:** ${f.root_cause_class}\n`);
    if (f.error_patterns?.length) fmParts.push(`**Error patterns:** ${f.error_patterns.slice(0, 3).map((p) => `\`${p}\``).join(" \\| ")}\n`);

    fmParts.push(`\n### Diagnose`);
    for (const s of f.diagnostic_steps ?? []) {
      fmParts.push(`${s.step}. **${s.action}**`);
      if (s.command) fmParts.push("   ```\n   " + s.command.split("\n").join("\n   ") + "\n   ```");
      if (s.expected) fmParts.push(`   _expect:_ ${s.expected}`);
    }
    fmParts.push(`\n### Fix`);
    for (const s of f.fix_steps ?? []) {
      fmParts.push(`${s.step}. **${s.action}**`);
      if (s.command) fmParts.push("   ```\n   " + s.command.split("\n").join("\n   ") + "\n   ```");
      if (s.validation) fmParts.push(`   _validate:_ ${s.validation}`);
      if (s.rollback) fmParts.push(`   _rollback:_ ${s.rollback}`);
    }
  }

  await writeFile(resolve(cluelyDir, "03-top-failure-modes.md"), fmParts.join("\n") + "\n", "utf8");
  console.error(`wrote 03-top-failure-modes.md (${top.length} fms)`);

  // ---------- 04-diagnostic-commands.md ----------
  // Group commands by inferred category (containers / k8s / network / disk
  // / process / certs / systemd) based on the command text.
  const cmds = (await db.all(
    DOMAINS.map((d) => `SELECT '${d}' AS domain, id, command, purpose FROM ${d}.commands`).join(" UNION ALL ")
  )) as unknown as CmdRow[];

  const buckets: Record<string, CmdRow[]> = {
    "Container runtime (docker, runc, containerd)": [],
    "Kubernetes (kubectl, crictl)": [],
    "Process & cgroups (ps, top, /proc, cgroup)": [],
    "Networking (ss, ip, iptables, tcpdump, dig, conntrack)": [],
    "Disk & filesystem (df, du, lsof, mount, blkid)": [],
    "systemd (systemctl, journalctl, systemd-analyze)": [],
    "Certs / TLS (openssl, curl --cert, update-ca-certificates)": [],
    "Performance / tracing (perf, strace, ltrace, bpf, ftrace)": [],
    "AWS / ECS (aws ecs, aws ec2)": [],
    "Other": [],
  };

  for (const c of cmds) {
    const cmd = c.command.toLowerCase();
    if (/^docker |^runc |^containerd|^crictl |^ctr /.test(cmd)) buckets["Container runtime (docker, runc, containerd)"].push(c);
    else if (/^kubectl |^helm /.test(cmd)) buckets["Kubernetes (kubectl, crictl)"].push(c);
    else if (/^ps |^top |^pidstat|^cat \/proc|^cat \/sys\/fs\/cgroup/.test(cmd)) buckets["Process & cgroups (ps, top, /proc, cgroup)"].push(c);
    else if (/^ss |^ip |^iptables|^nft |^tcpdump|^dig |^nslookup|^conntrack|^getent|^nmap/.test(cmd)) buckets["Networking (ss, ip, iptables, tcpdump, dig, conntrack)"].push(c);
    else if (/^df |^du |^lsof |^mount|^blkid|^lsblk|^cat \/etc\/fstab/.test(cmd)) buckets["Disk & filesystem (df, du, lsof, mount, blkid)"].push(c);
    else if (/^systemctl|^journalctl|^systemd-/.test(cmd)) buckets["systemd (systemctl, journalctl, systemd-analyze)"].push(c);
    else if (/^openssl|^curl.*--cert|^update-ca-certificates|^keytool/.test(cmd)) buckets["Certs / TLS (openssl, curl --cert, update-ca-certificates)"].push(c);
    else if (/^perf |^strace|^ltrace|^bpftrace|^trace-cmd|^ftrace/.test(cmd)) buckets["Performance / tracing (perf, strace, ltrace, bpf, ftrace)"].push(c);
    else if (/^aws ecs|^aws ec2/.test(cmd)) buckets["AWS / ECS (aws ecs, aws ec2)"].push(c);
    else buckets["Other"].push(c);
  }

  const cmdParts: string[] = [
    `# 04 — Diagnostic commands (grouped by category)\n\n` +
    `> The actual commands you'll type. Grouped by tool family. \`ha "..."\` returns these embedded in fm playbooks; this is the flat browseable list.\n>\n> Auto-generated. Re-run \`pnpm cluely\` after corpus changes.\n\n` +
    `Total: ${cmds.length} commands across ${Object.keys(buckets).length} categories.\n`,
  ];
  for (const [cat, arr] of Object.entries(buckets)) {
    if (arr.length === 0) continue;
    cmdParts.push(`\n## ${cat} (${arr.length})\n`);
    // Limit to first 30 per category so the doc stays scannable
    const sorted = arr.sort((a, b) => a.command.localeCompare(b.command)).slice(0, 30);
    for (const c of sorted) {
      const cmdEsc = c.command.replace(/\|/g, "\\|").split("\n")[0]?.slice(0, 110);
      const purpose = (c.purpose ?? "").replace(/\|/g, "\\|").split("\n")[0]?.slice(0, 80);
      cmdParts.push(`- \`${cmdEsc}\` — ${purpose}`);
    }
    if (arr.length > 30) cmdParts.push(`  _... +${arr.length - 30} more in corpus; query via \`hl "${cat.split(" ")[0]}"\`_`);
  }

  await writeFile(resolve(cluelyDir, "04-diagnostic-commands.md"), cmdParts.join("\n") + "\n", "utf8");
  console.error(`wrote 04-diagnostic-commands.md (${cmds.length} commands)`);

  await db.close();
  console.error("done");
}

function bestAskKeyword(f: FmRow): string {
  // Pick the most distinctive 3-5 word phrase from the symptom for `ha "..."`
  const sym = f.symptom.toLowerCase().replace(/[`'"]/g, "");
  // Use error_patterns[0] if it's distinctive (e.g. an error string)
  if (f.error_patterns?.[0] && f.error_patterns[0].length < 40) {
    return f.error_patterns[0].toLowerCase().replace(/[`'"]/g, "");
  }
  // Else first ~6 words of symptom
  return sym.split(/\s+/).slice(0, 6).join(" ");
}

main().catch((e) => {
  console.error(e instanceof Error ? e.stack : String(e));
  process.exit(1);
});
