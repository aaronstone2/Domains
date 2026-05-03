import { Database } from "duckdb-async";
import { dbPath } from "./paths.ts";

export const DOMAINS: readonly string[] = [
  "docker",
  "linux",
  "k8s",
  "devin",
  "methodology",
  "firecracker",
  "ecs",
] as const;

export async function openDb(): Promise<Database> {
  return Database.create(dbPath);
}

export type JsonScalar = string | number | boolean | null;
export type JsonValue = JsonScalar | JsonValue[] | { [k: string]: JsonValue };

export function bigintReplacer(_k: string, v: unknown): unknown {
  return typeof v === "bigint" ? Number(v) : v;
}
