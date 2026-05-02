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
    "Subcommands:",
  ];
  for (const name of Object.keys(commands)) {
    lines.push(`  ${name}`);
  }
  p.log.info(lines.join("\n"));
}

main().catch((err: unknown) => {
  p.log.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
