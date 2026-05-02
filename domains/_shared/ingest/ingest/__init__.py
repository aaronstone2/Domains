"""Ingest pipeline: fetch sources, extract markdown, load DuckDB.

Public CLI:
    uv run python -m ingest <subcommand> [args]

Subcommands:
    init-db         create schemas + tables in _db/knowledge.duckdb
    list            print sources from sources.yaml (filterable by --domain/--subdomain)
    fetch           fetch + extract + load documents into <domain>.documents
"""
