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
