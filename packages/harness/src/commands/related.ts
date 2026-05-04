import { println } from "../output.ts";
import { openDb, DOMAINS } from "../db.ts";

export async function relatedCmd(args: string[]): Promise<void> {
  const id = args[0]?.trim();
  if (!id) {
    println("usage: harness related <id> — walk relationships outward");
    process.exit(1);
  }
  const depthArg = args[1] ? Number(args[1]) : 2;
  const depth = Number.isFinite(depthArg) && depthArg > 0 ? Math.min(depthArg, 4) : 2;
  const escaped = id.replace(/'/g, "''");
  const db = await openDb();
  try {
    const allRelsSql = DOMAINS.map((d) => `SELECT * FROM ${d}.relationships`).join(
      "\nUNION ALL\n",
    );
    const sql = `
      WITH RECURSIVE
        rels AS (${allRelsSql}),
        edges AS (
          SELECT from_id AS a, to_id AS b, rel_type FROM rels
          UNION ALL
          SELECT to_id AS a, from_id AS b, rel_type FROM rels
        ),
        walk(id, depth, path) AS (
          SELECT '${escaped}' AS id, 0 AS depth, ['${escaped}'] AS path
          UNION ALL
          SELECT e.b, w.depth + 1, list_append(w.path, e.b)
          FROM edges e JOIN walk w ON w.id = e.a
          WHERE w.depth < ${depth} AND NOT list_contains(w.path, e.b)
        )
      SELECT id, MIN(depth) AS depth
      FROM walk
      GROUP BY id
      ORDER BY depth, id
      LIMIT 50`;
    interface WalkRow { id: string; depth: number | bigint }
    const rows = (await db.all(sql)) as unknown as WalkRow[];
    if (rows.length === 0) {
      println(`no related nodes for ${id}`);
      return;
    }
    println(`Reachable within depth ${depth} from ${id}:`);
    for (const r of rows) {
      const d = Number(r.depth);
      const indent = "  ".repeat(Math.max(d, 0));
      println(`${indent}[d=${d}] ${r.id}`);
    }
  } finally {
    await db.close();
  }
}
