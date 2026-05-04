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

// Long-lived shared connection mode. When HARNESS_KEEPALIVE=1, openDb()
// returns a cached Database instance and close() is a no-op. Used by the MCP
// server (where rapid open/close on Windows hits file-lock conflicts) and by
// any other in-process integration. CLI keeps the per-call open/close model.
let sharedDb: Database | null = null;

function isKeepAlive(): boolean {
  return process.env["HARNESS_KEEPALIVE"] === "1";
}

export async function openDb(): Promise<Database> {
  if (isKeepAlive()) {
    if (!sharedDb) sharedDb = await Database.create(dbPath);
    // Wrap close as a no-op for shared mode so callers can call .close()
    // unconditionally without leaking.
    const originalClose = sharedDb.close.bind(sharedDb);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (sharedDb as any).close = async (): Promise<void> => { /* shared, do not close */ };
    // Stash original on the instance so explicit shutdown can use it.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (sharedDb as any).__originalClose = originalClose;
    return sharedDb;
  }
  return Database.create(dbPath);
}

// Optional: explicit shutdown of the shared connection (e.g. on MCP server
// SIGTERM). No-op if no shared connection.
export async function shutdownDb(): Promise<void> {
  if (sharedDb) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const close = (sharedDb as any).__originalClose as (() => Promise<void>) | undefined;
    if (close) await close();
    sharedDb = null;
  }
}

export type JsonScalar = string | number | boolean | null;
export type JsonValue = JsonScalar | JsonValue[] | { [k: string]: JsonValue };

export function bigintReplacer(_k: string, v: unknown): unknown {
  return typeof v === "bigint" ? Number(v) : v;
}
