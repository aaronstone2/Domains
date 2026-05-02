import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here: string = dirname(fileURLToPath(import.meta.url));
export const repoRoot: string = resolve(here, "..", "..", "..");
export const dbPath: string = resolve(repoRoot, "_db", "knowledge.duckdb");
