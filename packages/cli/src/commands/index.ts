import { domainCommands } from "./domain/index.ts";
import { packageCommands } from "./package/index.ts";

export type CommandHandler = (args: string[]) => Promise<void> | void;
export type CommandGroup = Record<string, CommandHandler>;

export const commands: Record<string, CommandGroup> = {
  domain: domainCommands,
  package: packageCommands,
};
