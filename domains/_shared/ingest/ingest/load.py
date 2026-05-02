import json
from datetime import datetime, timezone
from pathlib import Path

import duckdb

from ingest.models import Document, Source
from ingest.paths import (
    DB_DIR,
    DB_PATH,
    DOMAIN_SCHEMAS,
    SHARED_QUERIES,
    SHARED_SCHEMA_SQL,
    STAGING_DIR,
)


def open_db(read_only: bool = False) -> duckdb.DuckDBPyConnection:
    DB_DIR.mkdir(parents=True, exist_ok=True)
    return duckdb.connect(str(DB_PATH), read_only=read_only)


def init_db() -> None:
    """Create all domain schemas + tables in the DuckDB file. Idempotent."""
    template = SHARED_SCHEMA_SQL.read_text(encoding="utf-8")
    cross_domain_sql = (SHARED_QUERIES / "cross_domain.sql").read_text(encoding="utf-8")
    con = open_db(read_only=False)
    try:
        for schema in DOMAIN_SCHEMAS:
            ddl = template.replace("{{schema}}", schema)
            con.execute(ddl)
        con.execute(cross_domain_sql)
    finally:
        con.close()


# ---------------------------------------------------------------- staging

def _staging_paths(domain: str) -> tuple[Path, Path]:
    STAGING_DIR.mkdir(parents=True, exist_ok=True)
    return (
        STAGING_DIR / f"{domain}.sources.jsonl",
        STAGING_DIR / f"{domain}.documents.jsonl",
    )


def clear_staging(domain: str) -> None:
    src_p, doc_p = _staging_paths(domain)
    src_p.write_text("", encoding="utf-8")
    doc_p.write_text("", encoding="utf-8")


def stage_source(src: Source) -> None:
    src_p, _ = _staging_paths(src.domain)
    row = {
        "id": src.id,
        "url": src.url,
        "title": src.title,
        "subdomain": src.subdomain,
        "tier": src.tier,
        "license_note": src.license_note,
        "fetched_at": (src.fetched_at or datetime.now(timezone.utc)).isoformat(),
        "content_hash": src.content_hash,
        "parser": src.parser,
        "notes": src.notes,
    }
    with src_p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")


def stage_document(doc: Document, domain: str) -> None:
    _, doc_p = _staging_paths(domain)
    row = {
        "source_id": doc.source_id,
        "section_path": doc.section_path,
        "content_md": doc.content_md,
    }
    with doc_p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")


# ------------------------------------------------------------------- load

def load_staged(con: duckdb.DuckDBPyConnection, domain: str) -> tuple[int, int]:
    """Read staged JSONL for `domain` and INSERT OR REPLACE into <domain>.sources / .documents.

    Returns (sources_loaded, documents_loaded). Caller owns the connection (which holds the DB
    write lock); this function does no commit/rollback management.
    """
    src_p, doc_p = _staging_paths(domain)
    s_n = _load_jsonl(con, src_p, f"{domain}.sources")
    d_n = _load_jsonl(con, doc_p, f"{domain}.documents")
    return s_n, d_n


def _load_jsonl(con: duckdb.DuckDBPyConnection, path: Path, table: str) -> int:
    if not path.is_file() or path.stat().st_size == 0:
        return 0
    posix = path.as_posix()
    con.execute(
        f"INSERT OR REPLACE INTO {table} BY NAME "
        f"SELECT * FROM read_json('{posix}', format='newline_delimited')"
    )
    return con.execute(
        f"SELECT count(*) FROM read_json('{posix}', format='newline_delimited')"
    ).fetchone()[0]


# ------------------------------------------------------ legacy direct upserts
# Retained for ad-hoc one-source flows; the standard path is stage_* + load_staged.

def upsert_source(con: duckdb.DuckDBPyConnection, src: Source) -> None:
    con.execute(
        f"""
        INSERT OR REPLACE INTO {src.domain}.sources
            (id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            src.id,
            src.url,
            src.title,
            src.subdomain,
            src.tier,
            src.license_note,
            src.fetched_at or datetime.now(timezone.utc),
            src.content_hash,
            src.parser,
            src.notes,
        ],
    )


def upsert_document(con: duckdb.DuckDBPyConnection, doc: Document, domain: str) -> None:
    con.execute(
        f"""
        INSERT OR REPLACE INTO {domain}.documents (source_id, section_path, content_md)
        VALUES (?, ?, ?)
        """,
        [doc.source_id, doc.section_path, doc.content_md],
    )
