import * as p from "@clack/prompts";
import { openDb } from "../db.ts";

export async function queryCmd(args: string[]): Promise<void> {
  const text = args.join(" ").trim();
  if (!text) {
    p.log.error("usage: harness query <text>");
    process.exit(1);
  }
  const db = await openDb();
  try {
    const rows = await db.all(
      "SELECT current_database() AS db, COUNT(*) AS n_documents FROM meta.all_documents",
    );
    const replacer = (_k: string, v: unknown): unknown =>
      typeof v === "bigint" ? Number(v) : v;
    p.log.info(JSON.stringify({ query: text, db_state: rows[0] }, replacer, 2));
  } finally {
    await db.close();
  }
}
