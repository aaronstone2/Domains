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

# The "fact" tables worth versioning. documents/embeddings are big + derivable, so excluded.
SNAPSHOT_TABLES: tuple[str, ...] = (
    "claims",
    "sources",
    "relationships",
    "claim_evidence",
    "primary_studies",
    "forecast_log",
)


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
        for t in SNAPSHOT_TABLES:
            # table exists for every domain (all base); guard anyway
            exists = con.execute(
                "SELECT 1 FROM information_schema.tables WHERE table_schema=? AND table_name=?",
                [d, t],
            ).fetchone()
            if not exists:
                continue
            pq = (out / f"{d}.{t}.parquet").as_posix()
            con.execute(f"COPY (SELECT * FROM {d}.{t}) TO '{pq}' (FORMAT parquet)")
            written += 1
        if prev:
            archived += _archive_changed_claims(con, d, prev_label=prev, new_label=label)
    _write_manifest(label, domains, written, archived)
    return {"label": label, "tables_written": written, "claims_archived": archived, "prev": prev}


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
        "tables": list(SNAPSHOT_TABLES),
        "files_written": written,
        "claims_archived": archived,
    }
    (_label_dir(label) / "manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
