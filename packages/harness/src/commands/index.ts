import { queryCmd } from "./query.ts";
import { lookupCmd } from "./lookup.ts";
import { playbookCmd } from "./playbook.ts";
import { conceptCmd } from "./concept.ts";
import { citeCmd } from "./cite.ts";
import { statsCmd } from "./stats.ts";
import { relatedCmd } from "./related.ts";
import { captureCmd } from "./capture.ts";
import { drillCmd } from "./drill.ts";
import { askCmd } from "./ask.ts";

export type CommandHandler = (args: string[]) => Promise<void> | void;

// Order matters — printed by `harness` with no args. Most-used first.
export const commands: Record<string, CommandHandler> = {
  ask: askCmd,
  lookup: lookupCmd,
  playbook: playbookCmd,
  drill: drillCmd,
  capture: captureCmd,
  concept: conceptCmd,
  related: relatedCmd,
  cite: citeCmd,
  stats: statsCmd,
  query: queryCmd,
};
