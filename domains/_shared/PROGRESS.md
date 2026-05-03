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

## Phase 1 — Per-domain source corpus build-out

### Session 1.1 — 2026-05-02 — methodology — DONE

Per-leaf detail: `domains/methodology/PROGRESS.md`.

**Outputs:**

- 44 methodology sources fetched + indexed (5 existing + 39 new). 1,270,471 chars total content; mean 28,874 chars/doc.
- BM25 FTS index `fts_methodology_documents` built. 7 verification queries pass; each subdomain represented in ≥2 query top-5s.
- Subdomain split: use-red-method 18, visual-zines 14, sre-debugging 12.

**Infra changes:**

- Added `pymupdf>=1.24` PDF parser to ingest pipeline.
- Refactored `extract.py` to dispatch on `Source.parser` (pdf / github-md / trafilatura).
- **Decoupled `ingest fetch` from the DB write lock** — `fetch` now writes JSONL staging to `_db/staging/<domain>.{sources,documents}.jsonl`; new `ingest load` command (or motherduck MCP) bulk-loads via `read_json` + `INSERT OR REPLACE BY NAME`. Resolves the long-standing motherduck-MCP / ingest-CLI lock conflict.

**Verified:**

- 0 fetch failures across 44 sources.
- 1 thin doc (`jvns-debugging-zine`, 0 chars) — image-only comic PDF, flagged for OCR follow-up. All other docs > 500 chars.
- BM25 sample queries return high-quality results (e.g. "four golden signals" → `sre-monitoring-signals` top-1 with 8.2 score).

**Deferred:** OCR for image-only PDFs; per-parser variants for `manpage` and `mintlify`; harvesting individual Wizard Zines comic URLs from the now-ingested comics-index page; PDF-only sources like Cindy Sridharan's O'Reilly chapter.

**Sequencing revision (2026-05-02):** revised the approach from horizontal-layered ("all domains Phase 1, then all domains Phase 3") to a hybrid: **Phase 1 + Phase 3 per domain (vertical pair)**, then **Phase 2 / 4 / 5 / 6+ horizontally** across all domains. Reasoning: P1 and P3 are tightly coupled (P3 surfaces source gaps that get patched back into P1 mid-session); P4 and P5 cite cross-domain `affected_concepts` so they need every domain's P3 done first to avoid revisits; P2 is devin-specific and timing-gated; P6+ are end-state assembly. Captured in `PREAMBLE.md` (Approach commitments) and `~/.claude/projects/.../memory/feedback_vertical_slices.md`. The original master plan and per-phase session prompts remain correct *per phase*; only the cross-phase sequencing changes.

**Next:** stay on methodology — Phase 3 (concepts/commands/config_keys extraction from the 1.27 MB we just landed). End condition for the methodology vertical: `pnpm harness <query>` returns concept rows with cited source_ids for the framework vocabulary (USE / RED / Four Golden Signals / off-CPU / postmortem template / etc.). Source gaps that surface get patched back into `sources.yaml`. After that, vertical pivots to docker (P1+P3 combined session).

## Phase 3 — Per-domain concept/command/config_keys extraction

### Session 3.1 — 2026-05-02 — methodology — DONE

Per-domain detail: `domains/methodology/PROGRESS.md`. Per-leaf detail under each leaf folder.

**Outputs:**

- 121 methodology concepts, 50 commands, 36 config_keys — all 3 leaves landed (use-red-method 77/50/0, sre-debugging 38/0/36, visual-zines 6/0/0).
- ID convention adopted: `<domain>.<kebab-name>` (concepts), `<domain>.cmd.<tool>.<form>` (commands), `<domain>.cfg.<scope>.<key>` (config_keys). Deterministic — re-extraction produces same IDs; cross-domain referenceable for Phase 4 `affected_concepts` linking.

**Verified:**

- 0 orphan `source_ids` references across all 3 tables.
- 24 canonical cross-domain hooks resolve (use-method, red-method, four-golden-signals, off-cpu-analysis, flame-graph, sli/slo/sla, error-budget, blameless-postmortem, incident-commander, cascading-failure, ebpf, kprobe, uprobe, tracepoint, usdt, ipc, etc.).
- Commands table: STRUCT-typed `flags[]` and `examples[]` arrays loaded correctly via `read_json(..., columns = {...})` with explicit schema spec.

**Infra changes (this session):**

- All 3 methodology leaf folders scaffolded via `pnpm leaf add methodology/<leaf>` — the new idempotent CLI subcommand added to `packages/cli` between sessions. Filled in README.md, PLAN.md (from `_shared/PLAN.template.md`), PROGRESS.md, `extract/`, `queries/` only when missing.
- A Python+Anthropic-SDK structured extractor was scaffolded at `domains/_shared/ingest/ingest/extract_structured.py` with three tool_use schemas matching the DDL, plus a new `ingest extract` CLI subcommand. **Reverted on user direction** — Claude Code Max means in-session extraction, not metered API calls. Design preserved in plan file `~/.claude/plans/groovy-yawning-raven.md` if needed for larger downstream corpora.
- Encountered orphan `mcp-server-motherduck` processes from earlier Claude Code sessions holding the DuckDB exclusive lock. Killed older instances by start-time; current session's MCP took the lock cleanly afterward. **Documented this as a recurring cleanup pattern** — diagnose via `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'mcp-server-motherduck' }`.

**Deferred:**

- Failure-modes + relationships tables stay empty — horizontal Phase 4 / Phase 5 after every domain has P3 (per PREAMBLE doctrine).
- Full BCC tool catalog walk; bpftrace stdlib detail; `bpftrace-oneliners` extraction; OCR for `jvns-debugging-zine`; Wizard Zines individual-comic URL harvest. All addable in follow-up sessions.

**Next:** **Methodology vertical complete.** Pivot to docker — Phase 1 + Phase 3 combined session. Domain order: methodology ✓ → docker → linux → devin → k8s. Start with `docker/engine` per the leaf priority order in `phase-3-deep-extraction.md`. New session prompt: pipe `domains/_shared/sessions/phase-1-source-corpus.md` first to seed the docker source list, then `phase-3-deep-extraction.md` for extraction.
