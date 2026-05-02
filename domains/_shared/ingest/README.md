# `_shared/ingest/` — Python ingest pipeline

Fetch → extract → load. Reads `domains/_shared/sources.yaml`, writes rows into `_db/knowledge.duckdb`.

## Setup (one time)

```powershell
cd domains/_shared/ingest
uv sync
uv run python -m ingest init-db
```

## Commands

```powershell
# Show all sources matching a filter:
uv run python -m ingest list --domain devin
uv run python -m ingest list --domain docker --subdomain engine

# Fetch + extract + load. Same filter args.
uv run python -m ingest fetch --source-id oci-runtime-spec-gh
uv run python -m ingest fetch --domain linux --subdomain primitives
```

Raw HTML lands in `_db/raw/<domain>/<subdomain>/<source-id>.html` (gitignored).
Parsed markdown lands in `_db/knowledge.duckdb` → `<domain>.documents`.
Source metadata lands in `<domain>.sources` (URL, hash, fetched_at, parser).

## After ingest: build FTS

```powershell
duckdb ../../../_db/knowledge.duckdb -c ".read ../queries/fts_index.sql"
```

## Layout

```
ingest/
  pyproject.toml
  ingest/
    __init__.py
    __main__.py     # python -m ingest entrypoint
    cli.py          # argparse + subcommands
    paths.py        # locate repo root, _db, sources.yaml
    models.py       # pydantic Source / Document / SourcesFile
    fetch.py        # httpx + tenacity retries
    extract.py      # trafilatura HTML→MD
    load.py         # init_db, upsert_source, upsert_document
```

## Adding parsers

V1 uses `trafilatura` for everything. When trafilatura output is unusable for a category (e.g. man pages with structured DIAGNOSTICS sections), add a `parser: <name>` value to entries in `sources.yaml` and dispatch in `extract.extract()`.
