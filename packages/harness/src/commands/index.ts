import { queryCmd } from "./query.ts";
import { lookupCmd } from "./lookup.ts";
import { playbookCmd } from "./playbook.ts";
import { conceptCmd } from "./concept.ts";
import { citeCmd } from "./cite.ts";
import { statsCmd } from "./stats.ts";
import { relatedCmd } from "./related.ts";
import { captureCmd } from "./capture.ts";
import { drillCmd } from "./drill.ts";

export type CommandHandler = (args: string[]) => Promise<void> | void;

export const commands: Record<string, CommandHandler> = {
  query: queryCmd,
  lookup: lookupCmd,
  playbook: playbookCmd,
  concept: conceptCmd,
  cite: citeCmd,
  stats: statsCmd,
  related: relatedCmd,
  capture: captureCmd,
  drill: drillCmd,
};
