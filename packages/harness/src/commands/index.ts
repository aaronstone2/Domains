import { queryCmd } from "./query.ts";

export type CommandHandler = (args: string[]) => Promise<void> | void;

export const commands: Record<string, CommandHandler> = {
  query: queryCmd,
};
