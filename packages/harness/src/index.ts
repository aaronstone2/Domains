#!/usr/bin/env -S npx tsx
import * as p from "@clack/prompts";
import { commands } from "./commands/index.ts";

async function main(): Promise<void> {
  const [cmdName, ...rest] = process.argv.slice(2);

  if (!cmdName) {
    printHelp();
    process.exit(1);
  }

  const cmd = commands[cmdName];
  if (!cmd) {
    p.log.error(`Unknown subcommand: ${cmdName}`);
    printHelp();
    process.exit(1);
  }

  await cmd(rest);
}

function printHelp(): void {
  const lines: string[] = [
    "Usage: pnpm harness <subcommand> [args]",
    "",
    "Most-used:",
    "  ask \"<symptom>\"          one-shot: top failure mode + talk-track + diag/fix",
    "  lookup <query>            multi-section search across fms/cmds/concepts/docs",
    "  playbook <fm-id>          render a specific failure-mode runbook",
    "  drill <drill-id>          interactive practice REPL",
    "  capture <bundle|--list>   live diagnostic snapshot (or --from-fm <id>)",
    "",
    "Reference:",
    "  concept <id>              show concept + relationships",
    "  related <id> [depth]      walk the relationship graph (max depth 4)",
    "  cite <source-id>          show source URL + license + tier",
    "  stats                     corpus inventory + quality grades",
    "  query <sql>               raw DuckDB SQL",
  ];
  p.log.info(lines.join("\n"));
}

main().catch((err: unknown) => {
  p.log.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
