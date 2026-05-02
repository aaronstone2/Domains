# Phase 0 — Foundation setup

> **Status:** Executed in Session 0.1. This doc is for reference / re-init only. Skip to [`phase-1-source-corpus.md`](./phase-1-source-corpus.md) for the next session.

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md) — universal context

## What this phase produced

- `_db/knowledge.duckdb` — DuckDB file with schemas `meta`, `devin`, `docker`, `linux`, `k8s`, `methodology` and the base tables in each (`sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`, `relationships`). Cross-domain views in `meta`.
- `domains/_shared/schema.sql` — base DDL (templated `{{schema}}`).
- `domains/_shared/queries/cross_domain.sql` — `meta.all_*` views.
- `domains/_shared/queries/fts_index.sql` — BM25 FTS PRAGMAs per domain.
- `domains/_shared/sources.yaml` — seeded global tiered source registry (~50 entries).
- `domains/_shared/PLAN.template.md` — per-leaf plan template.
- `domains/_shared/README.md` — corpus convention summary.
- `domains/_shared/ingest/` — Python pipeline (`uv`-managed): `fetch`, `extract`, `load` with CLI `python -m ingest`.
- `domains/_shared/sessions/` — these phase docs (you are reading one).
- `packages/harness/` — TS scaffold for the interview-day debugging harness, root script `pnpm harness`.
- `.mcp.json` — motherduck flipped to `--read-write`.
- `.gitignore` — added `domains/**/raw/`, `*.token`, `*sensitive*`.
- `CLAUDE.md` — added the corpus convention paragraph pointing at `domains/_shared/sessions/`.

## Re-init (if you ever need to rebuild from scratch)

```powershell
# 1. Schemas + tables
cd domains\_shared\ingest
uv sync
uv run python -m ingest init-db

# 2. Smoke-test source registry
uv run python -m ingest list --domain devin

# 3. (Optional) Trial fetch + load
uv run python -m ingest fetch --source-id oci-runtime-spec-gh
duckdb ..\..\..\_db\knowledge.duckdb -c "SELECT count(*) FROM docker.documents"

# 4. Build FTS indexes (only after sources are loaded)
duckdb ..\..\..\_db\knowledge.duckdb ".read ..\queries\fts_index.sql"

# 5. Verify the harness opens the DB
cd ..\..\..
pnpm install
pnpm harness query "test"
```

## Verification checklist

- [ ] `_db\knowledge.duckdb` exists and has 6 schemas (5 domains + meta).
- [ ] `meta.all_sources`, `meta.all_documents`, `meta.all_failure_modes` views exist and queryable.
- [ ] `domains\_shared\ingest` has `pyproject.toml`, `ingest\` package, `uv.lock` after `uv sync`.
- [ ] `packages\harness` has `package.json` (`@domains/harness`), `tsconfig.json` extending `cue/ts/config/node.json`, `src\index.ts` with the subcommand router.
- [ ] Root `package.json` has the `harness` script.
- [ ] `.mcp.json` motherduck has `--read-write`. **Restart Claude Code** for the MCP arg change to take effect.
