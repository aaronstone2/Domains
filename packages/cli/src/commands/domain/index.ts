import type { CommandGroup } from "../index.ts";
import { addDomain } from "./add.ts";

export const domainCommands: CommandGroup = {
  add: addDomain,
};
