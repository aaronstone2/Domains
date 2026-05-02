import { Database } from "duckdb-async";
import { dbPath } from "./paths.ts";

export async function openDb(): Promise<Database> {
  return Database.create(dbPath);
}
