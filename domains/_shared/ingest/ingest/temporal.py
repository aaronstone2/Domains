"""Layer 2 — temporal. Snapshots, diffs, and SCD-2 claim history.

The corpus is a *snapshot* by default. This module makes it a *time-series* without disrupting the
upsert hot path: `snapshot` writes the fact tables to committed parquet under
domains/_shared/snapshots/<label>/, records claim_history rows for any claim whose verdict/agreement
changed since the previous snapshot, and `diff` reports what changed between two labels.

"Commit the inputs, regenerate everything else" still holds — except snapshots, which are the one
genuinely irreproducible state (you cannot reconstruct last quarter's numbers from today's sources).
So the parquet is small and committed; claim_history is replayable from it.
"""

import json
from pathlib import Path

import duckdb

from ingest.paths import SNAPSHOTS_DIR

# Tables NOT snapshotted: `embeddings` (large FLOAT[384], fully regenerable via `ingest embed`) and
# `claim_history` (the SCD-2 audit, replayed from the parquet sequence itself). Everything else in each
# domain schema — base AND domain-specific entity tables — is captured, so snapshot+restore round-trips
# the entire corpus from committed state (the regenerable-artifact guarantee, Part 7).
_SNAPSHOT_EXCLUDE: frozenset[str] = frozenset({"embeddings", "claim_history"})

# FK-safe ordering: parents restored first, junctions last. Tables not listed go in the middle.
_RESTORE_FIRST: tuple[str, ...] = ("sources", "claims", "primary_studies", "documents", "concepts")
_RESTORE_LAST: tuple[str, ...] = ("claim_evidence", "relationships", "derivations", "forecast_log")


def _data_tables(con: duckdb.DuckDBPyConnection, domain: str) -> list[str]:
    """Every base table in the domain schema worth versioning (excludes embeddings/claim_history)."""
    rows = con.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema=? AND table_type='BASE TABLE' ORDER BY table_name",
        [domain],
    ).fetchall()
    return [r[0] for r in rows if r[0] not in _SNAPSHOT_EXCLUDE]


def _restore_order(tables: list[str]) -> list[str]:
    """Parents first, junctions last — so FK-constrained restore into a fresh DB succeeds."""
    mid = [t for t in tables if t not in _RESTORE_FIRST and t not in _RESTORE_LAST]
    return ([t for t in _RESTORE_FIRST if t in tables] + sorted(mid)
            + [t for t in _RESTORE_LAST if t in tables])


def _label_dir(label: str) -> Path:
    return SNAPSHOTS_DIR / label


def snapshot(con: duckdb.DuckDBPyConnection, domains: tuple[str, ...], label: str) -> dict:
    """COPY each domain's fact tables to parquet under snapshots/<label>/, and archive changed claims.

    Backfills claims.as_of := last_verified where NULL first, so every snapshot is time-stamped.
    Returns a summary {tables_written, claims_archived}.
    """
    out = _label_dir(label)
    out.mkdir(parents=True, exist_ok=True)
    written = 0
    archived = 0
    prev = _latest_label_before(label)
    for d in domains:
        con.execute(f"UPDATE {d}.claims SET as_of = COALESCE(as_of, last_verified)")
        for t in _data_tables(con, d):
            pq = (out / f"{d}.{t}.parquet").as_posix()
            con.execute(f"COPY (SELECT * FROM {d}.{t}) TO '{pq}' (FORMAT parquet)")
            written += 1
        if prev:
            archived += _archive_changed_claims(con, d, prev_label=prev, new_label=label)
    _write_manifest(label, domains, written, archived)
    return {"label": label, "tables_written": written, "claims_archived": archived, "prev": prev}


def restore(con: duckdb.DuckDBPyConnection, domains: tuple[str, ...], label: str) -> dict:
    """Reload the full corpus from a committed parquet snapshot into a fresh (init-db'd) database.

    `init-db` + `restore --label <L>` deterministically reconstructs every domain's data from committed
    state — the regenerability guarantee for domains whose research was loaded ad-hoc. Clears each table
    (children first) then INSERTs BY NAME (parents first) so FK constraints hold. Skips embeddings
    (regenerate with `ingest embed`). Idempotent.
    """
    try:
        con.execute("INSTALL vss; LOAD vss;")  # in case any indexed table sneaks in
    except Exception:
        pass
    base = _label_dir(label)
    if not base.is_dir():
        return {"error": f"no snapshot {label} at {base}"}
    loaded = 0
    rows_total = 0
    for d in domains:
        present = [t for t in _data_tables(con, d) if (base / f"{d}.{t}.parquet").is_file()]
        # clear children-first
        for t in reversed(_restore_order(present)):
            con.execute(f"DELETE FROM {d}.{t}")
        # load parents-first
        for t in _restore_order(present):
            pq = (base / f"{d}.{t}.parquet").as_posix()
            con.execute(f"INSERT INTO {d}.{t} BY NAME SELECT * FROM read_parquet('{pq}')")
            rows_total += con.execute(f"SELECT count(*) FROM {d}.{t}").fetchone()[0]
            loaded += 1
    return {"label": label, "tables_loaded": loaded, "rows_total": rows_total}


def _archive_changed_claims(
    con: duckdb.DuckDBPyConnection, domain: str, prev_label: str, new_label: str
) -> int:
    """Write claim_history rows for claims whose verdict/agreement changed since prev snapshot."""
    prev_pq = (_label_dir(prev_label) / f"{domain}.claims.parquet").as_posix()
    if not Path(prev_pq).is_file():
        return 0
    rows = con.execute(
        f"""
        WITH prev AS (SELECT * FROM read_parquet('{prev_pq}'))
        SELECT c.id, p.verdict, p.agreement_score, p.as_of, p.valid_from
        FROM {domain}.claims c JOIN prev p ON p.id = c.id
        WHERE c.verdict IS DISTINCT FROM p.verdict
           OR c.agreement_score IS DISTINCT FROM p.agreement_score
        """
    ).fetchall()
    n = 0
    for cid, pverdict, pagree, pas_of, pvalid_from in rows:
        hid = f"{cid}@{prev_label}"
        rowjson = json.dumps(
            {"verdict": pverdict, "agreement_score": pagree, "snapshot": prev_label}, default=str
        )
        con.execute(
            f"INSERT INTO {domain}.claim_history "
            f"(history_id, claim_id, verdict, agreement_score, as_of, valid_from, valid_to, "
            f"superseded_at, supersede_reason, row_json) "
            f"VALUES (?,?,?,?,?,?,NULL,CURRENT_DATE,?,?) ON CONFLICT (history_id) DO NOTHING",
            [hid, cid, pverdict, pagree, pas_of, pvalid_from, f"changed by {new_label}", rowjson],
        )
        n += 1
    return n


def diff(con: duckdb.DuckDBPyConnection, domain: str, since: str, table: str = "claims") -> dict:
    """Report added / removed / changed rows in <domain>.<table> vs the `since` snapshot."""
    pq = (_label_dir(since) / f"{domain}.{table}.parquet").as_posix()
    if not Path(pq).is_file():
        return {"error": f"no snapshot {since} for {domain}.{table}"}
    con.execute(f"CREATE OR REPLACE TEMP VIEW _prev AS SELECT * FROM read_parquet('{pq}')")
    added = con.execute(
        f"SELECT count(*) FROM {domain}.{table} c WHERE c.id NOT IN (SELECT id FROM _prev)"
    ).fetchone()[0]
    removed = con.execute(
        f"SELECT count(*) FROM _prev p WHERE p.id NOT IN (SELECT id FROM {domain}.{table})"
    ).fetchone()[0]
    changed = 0
    if table == "claims":
        changed = con.execute(
            f"""SELECT count(*) FROM {domain}.claims c JOIN _prev p ON p.id=c.id
                WHERE c.verdict IS DISTINCT FROM p.verdict
                   OR c.agreement_score IS DISTINCT FROM p.agreement_score"""
        ).fetchone()[0]
    return {"since": since, "table": f"{domain}.{table}", "added": added, "removed": removed, "changed": changed}


def _latest_label_before(label: str) -> str | None:
    if not SNAPSHOTS_DIR.is_dir():
        return None
    labels = sorted(p.name for p in SNAPSHOTS_DIR.iterdir() if p.is_dir() and p.name != label)
    return labels[-1] if labels else None


def _write_manifest(label: str, domains: tuple[str, ...], written: int, archived: int) -> None:
    manifest = {
        "label": label,
        "domains": list(domains),
        "excluded_tables": sorted(_SNAPSHOT_EXCLUDE),
        "files_written": written,
        "claims_archived": archived,
    }
    (_label_dir(label) / "manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
