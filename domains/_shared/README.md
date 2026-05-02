# `_shared/` — corpus conventions and shared tooling

This directory holds the cross-cutting machinery used by every domain leaf:

- **`schema.sql`** — base DDL applied to each domain schema in `_db/knowledge.duckdb`. Tables: `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`, `relationships`. The `{{schema}}` placeholder is filled per-domain by the ingest pipeline's `init-db` command.
- **`sources.yaml`** — global tiered source registry (T0 = primary live capture, T1 = official docs, T2 = respected secondary, T3 = high-quality blogs). Per-leaf filtering by `domain` + `subdomain`.
- **`queries/cross_domain.sql`** — `meta.all_*` views unioning across all domain schemas.
- **`queries/fts_index.sql`** — BM25 FTS index build, per-domain.
- **`ingest/`** — Python pipeline (uv-managed) that fetches sources, extracts markdown, loads DuckDB. CLI: `uv run python -m ingest <subcommand>` from inside `ingest/`.
- **`PLAN.template.md`** — copy this into each leaf's `PLAN.md` to bootstrap a domain plan.

## Conventions

Every domain leaf (e.g. `domains/docker/engine/`) follows the same structure:

```
<leaf>/
  README.md       # 1-page domain summary
  PLAN.md         # multi-session plan, copied from _shared/PLAN.template.md
  PROGRESS.md     # running log of sessions
  sources.yaml    # OPTIONAL leaf-local sources (if registry filtering insufficient)
  raw/            # gitignored — fetched HTML/MD per source (hash-keyed)
  extract/        # committed — extracted JSON entities (concepts.json, commands.json, ...)
  queries/        # committed — leaf-scoped useful SQL
```

`raw/` is gitignored (large, rebuildable). `extract/` is committed (the corpus is reproducible from JSON without re-fetching).

## Init flow (first time only)

```powershell
cd domains/_shared/ingest
uv sync
uv run python -m ingest init-db          # creates schemas + tables in _db/knowledge.duckdb
uv run python -m ingest list --domain devin   # smoke-test the source registry loader
```

## Daily flow

```powershell
# After editing sources.yaml or adding a leaf:
uv run python -m ingest fetch --domain docker --subdomain engine
duckdb ../../../_db/knowledge.duckdb < ../queries/fts_index.sql

# Query from the harness package:
pnpm harness query "container exits 137"
```
