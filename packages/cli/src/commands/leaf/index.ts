import type { CommandGroup } from "../index.ts";
import { addLeaf } from "./add.ts";

export const leafCommands: CommandGroup = {
  add: addLeaf,
};
