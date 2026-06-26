"""Layer 5 — causal / graph-reasoning over the typed relationships graph.

Rules live as committed YAML in domains/_shared/rules/*.yaml. Each rule DERIVES new edges (and/or
claims) from existing ones, recording provenance in `derivations` and marking derived rows
(relationships.derived = TRUE, claims.verdict = 'speculative'). Derived claims are quarantined as
speculative until Layer-6 verification promotes them — reasoning proposes, verification disposes.

Rule kinds:
  transitive — graph closure on a rel_type: A -r-> B -r-> C  ⇒  A -out_rel-> C, confidence decayed.
  sql_edge   — a SELECT returning (from_id, to_id, rel_type, confidence) → inserted as derived edges.
"""

import duckdb
import yaml

from ingest.paths import SHARED_DIR

RULES_DIR = SHARED_DIR / "rules"


def load_rules() -> list[dict]:
    if not RULES_DIR.is_dir():
        return []
    return [yaml.safe_load(p.read_text(encoding="utf-8")) for p in sorted(RULES_DIR.glob("*.yaml"))]


def _apply_transitive(con, domain, rule, dry_run) -> int:
    rel = rule["rel_type"]
    out_rel = rule.get("out_rel_type", rel)
    decay = float(rule.get("confidence_decay", 0.7))
    rows = con.execute(
        f"""
        SELECT r1.from_id, r2.to_id,
               COALESCE(r1.confidence,0.5) * COALESCE(r2.confidence,0.5) * {decay} AS c
        FROM {domain}.relationships r1
        JOIN {domain}.relationships r2 ON r1.to_id = r2.from_id
        WHERE r1.rel_type = ? AND r2.rel_type = ? AND r1.from_id <> r2.to_id
          AND NOT EXISTS (
            SELECT 1 FROM {domain}.relationships x
            WHERE x.from_id = r1.from_id AND x.to_id = r2.to_id AND x.rel_type = ?
          )
        """,
        [rel, rel, out_rel],
    ).fetchall()
    if dry_run:
        return len(rows)
    n = 0
    for f, t, c in rows:
        con.execute(
            f"INSERT INTO {domain}.relationships "
            f"(from_id, to_id, rel_type, source_id, confidence, derived, rule_id, valid_from) "
            f"VALUES (?,?,?,?,?,TRUE,?,CURRENT_DATE)",
            [f, t, out_rel, None, round(c, 3), rule["id"]],
        )
        con.execute(
            f"INSERT INTO {domain}.derivations "
            f"(id, derived_rel, rule_id, premise_rel_ids, confidence_out, created_at) "
            f"VALUES (?,?,?,?,?,CURRENT_DATE) ON CONFLICT (id) DO NOTHING",
            [f"{domain}.deriv.{rule['id']}.{f}.{t}", f"{f}|{out_rel}|{t}", rule["id"],
             [f"{f}->{t}"], round(c, 3)],
        )
        n += 1
    return n


def _apply_sql_edge(con, domain, rule, dry_run) -> int:
    sql = rule["sql"].replace("{domain}", domain)
    rows = con.execute(sql).fetchall()
    if dry_run:
        return len(rows)
    n = 0
    for row in rows:
        f, t, rel_type, c = row[0], row[1], row[2], (row[3] if len(row) > 3 else 0.5)
        con.execute(
            f"INSERT INTO {domain}.relationships "
            f"(from_id, to_id, rel_type, source_id, confidence, derived, rule_id, valid_from) "
            f"VALUES (?,?,?,?,?,TRUE,?,CURRENT_DATE)",
            [f, t, rel_type, None, c, rule["id"]],
        )
        n += 1
    return n


_KINDS = {"transitive": _apply_transitive, "sql_edge": _apply_sql_edge}


def reason(con: duckdb.DuckDBPyConnection, domain: str, only: str | None = None, dry_run: bool = False) -> dict:
    """Run all (or one) rule over a domain. Returns {rule_id: derived_count}."""
    out: dict[str, int] = {}
    for rule in load_rules():
        if only and rule.get("id") != only:
            continue
        fn = _KINDS.get(rule.get("kind", ""))
        if fn is None:
            continue
        out[rule["id"]] = fn(con, domain, rule, dry_run)
    return out
