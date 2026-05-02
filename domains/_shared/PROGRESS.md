# Corpus PROGRESS log

Top-level log across all phases / sessions. Per-leaf detail lives at `domains/<domain>/<leaf>/PROGRESS.md`.

## Phase 0 — Foundation

### Session 0.1 — 2026-05-02 — DONE

**Output:**
- `_db/knowledge.duckdb` initialized with schemas `meta`, `devin`, `docker`, `linux`, `k8s`, `methodology` and 7 tables/views per schema.
- `domains/_shared/schema.sql`, `queries/cross_domain.sql`, `queries/fts_index.sql`.
- `domains/_shared/sources.yaml` seeded with ~50 tiered entries spanning all 5 domains.
- `domains/_shared/ingest/` Python pipeline (uv-managed) with `init-db`, `list`, `fetch` subcommands. Built locally (`uv sync`).
- `domains/_shared/sessions/` populated with `PREAMBLE.md`, `HOWTO.md`, and `phase-0` through `phase-7` pipe-able session prompts.
- `domains/_shared/PLAN.template.md` and `README.md` written.
- `packages/harness/` (`@domains/harness`) scaffolded — `pnpm harness query "<text>"` opens DuckDB and returns state. Stubbed; full subcommands come in Phase 5.
- Root `package.json` has `harness` script wired via `tsx`.
- `pnpm-workspace.yaml` updated with `duckdb`/`duckdb-async`/`esbuild` in `onlyBuiltDependencies`.
- `.mcp.json` motherduck flipped to `--read-write` (was malformed by user, fixed). **Restart Claude Code for the change to take effect on the motherduck MCP**.
- `.gitignore` extended (`domains/**/raw/`, `*.token`, `*sensitive*`).
- `CLAUDE.md` extended with a Knowledge corpus section pointing at `domains/_shared/sessions/`.

**Verified:**
- DuckDB schemas created (6 schemas × 7 tables/views each).
- `pnpm harness query "test"` returns `{db: "knowledge", n_documents: 0}` against the empty DB.
- Sample fetch: `uv run python -m ingest fetch --source-id oci-runtime-spec-gh` ingested the OCI runtime-spec into `docker.sources` + `docker.documents` (3370 chars).
- After ingest: `pnpm harness query "after ingest"` correctly reports `n_documents: 1` via the `meta.all_documents` view.
- Direct DuckDB query confirms the `docker.sources` row + linked `docker.documents` row.

**Deferred:**
- FTS index build (waiting until Phase 1 has more docs).
- `ingest load --table <t>` subcommand for JSON-from-extract loads (Phase 3 dependency — not needed yet).
- Custom parsers (`manpage`, `mintlify`) — defer until trafilatura output is verified inadequate for those source types.
- Memory MCP graph population — Phase 4.

**Next:** Phase 1 (per-domain source corpus build-out). Pick a domain and pipe `domains/_shared/sessions/phase-1-source-corpus.md` into a fresh session. Recommended order: methodology (smallest, validates pipeline at scale) → docker → linux → devin → k8s.
