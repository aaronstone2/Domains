# market — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## Session 0 — 2026-06-25 — Domain bootstrap + scope discovery — DONE

Stood up the `market` domain: an exhaustive market-research corpus for **MetroGraph** (metro-map-style
DB-visualization graph tool; github.com/mark1russell7/Graph @ `fable`; Angular 17 + SignalDB; its OWN
product, NOT graph-studio/kraken — earlier conflation was context pollution, corrected).

**Setup**
- `pnpm domain add market`; authored `schema.market.sql` — 21 extension tables (entity spine, capability
  matrix, VPC, business model, UX teardown, theory, gold `claims`/`reports`/`market_metrics`), mirroring
  the `exercise` conventions. Validated in a throwaway DuckDB.
- `ingest init-db` → `market` schema = 28 tables; the 7 `meta.*` cross-domain views compile; auto-gen
  `cross_domain.sql` + `fts_index.sql` picked up the domain.
- Pulled MetroGraph product context from the `fable` branch via `gh` (Angular + SignalDB local-first;
  vision "every component becomes JSON"; the "everything is data" substrate IS the best-of-both wedge).

**Scope discovery (workflow `wk0zydy80`: 13 agents, 724K tokens, 376 tool calls, ~25 min)**
- 7 cartographers (analyst maps, funding DBs, review-mining, alternatives-to, awesome-lists, communities,
  direct graph/db-viz tools) → **182 companies** card-sorted into **10 archetypes**.
- 4 theory scholars decomposed the HCI/graph/RAG literature → the `theory-*` sub-leaves.
- Card-sort + synthesis → **73-leaf tree**, **14 cross-leaf contracts** (C1–C14), **6 dependency waves**,
  **11 charter questions**, **12 acceptance tests**. Artifacts in `_scope/{registry,theory-decomposition,leaf-tree}.json`.
- **Pain themes validated the wedge** with real evidence: "users fleeing the UI for AI chat (worst of both
  worlds)", surface-area bloat (Retool/n8n/Zapier/UiPath), complexity-ceiling/no-escape-hatch, agent-vs-UI
  confusion + MCP context bloat.

**Decisions (Aaron)**
- **Depth = exhaustive on ALL 73 leaves** (overrode the synthesizer's risk-weighted mix).
- **C1 refined → continuous company discovery**: any leaf may append newly-found company stubs (deterministic
  slugs = no PK collision); `companies` leaf enriches/dedups, doesn't gatekeep. The 182 registry is a floor.

**Scaffold**
- `pnpm leaf add market/<leaf>` for all **73 leaves** (idempotent). Set every `STATUS.yaml` `depth: exhaustive`;
  injected each leaf's Session-0 *Leaf spec* (cluster, scope, target tables, deps, claim categories) into its
  `PLAN.md`. Wrote master `domains/market/PLAN.md` (charter + algebra + tier rubric + leaf tree + contracts +
  waves + acceptance tests).
- Gotchas logged: Python-on-Windows leaf-name files carry trailing `\r` (strip with `tr -d '\r'`); `duckdb`
  CLI is a Windows binary (feed SQL via stdin, use `C:/` paths).

**Next:** Session 1 — Phase A (source survey) across all 73 leaves, breadth-first.

## Session 1 — 2026-06-25 — Phase A source survey across ALL 73 leaves — DONE

Breadth-first Phase A, run as 4 cluster-batched `market-phaseA` workflows (one exhaustive
source-discovery agent per leaf; `agentType: Explore` with web search). Merged each batch into
`_shared/sources.yaml` (idempotent append, per-leaf provenance in `extract/sources.json`), flipped
`a_survey -> done`.

| Batch | Leaves | Agents | Tokens | Sources |
|---|---:|---:|---:|---:|
| spine+market | 4 | 4 | 222K | 262 |
| theory | 29 | 29 | 1.80M | 1,743 |
| competitive | 24 | 24 | 1.40M | 1,735 |
| closing (customers/vpc/bmc/pricing/partners/ux×10/synthesis) | 16 | 16 | 958K | 1,003 |
| **TOTAL** | **73** | **73** | **~4.4M** | **4,743** |

**Result:** all 73 leaves `a_survey: done`; **4,743 market sources** in the registry (grand total 5,578).
Tiers T0 781 / T1 1,974 / T2 1,133 / T3 855. License reference-only 2,839 / redistribute-ok 1,904.
Parser trafilatura 3,626 / pdf 904 / github-md 213. 4,091 unique URLs (≈650 cross-leaf overlaps, distinct
per-leaf ids). `sources.yaml` valid; `ingest list --domain market` confirms.

**Tooling:** reusable `market-phaseA.js` workflow (parameterized by `args` = batch leaves; note: Workflow
`args` arrives as a JSON STRING — script JSON.parse-guards it) + `merge_phaseA.py` (dedup by url+id, append
to sources.yaml via pyyaml indented block, flip STATUS).

**Next:** Phase B (ingest → documents + FTS).

## Session 2 — 2026-06-25 — Phase B ingest (fetch → documents + FTS) — DONE (82%)

Full-corpus fetch per Aaron's directive ("everything, all 4,743"). Sequential `ingest fetch` would
take hours, so used a **parallel fetch driver** (`scratchpad/par_fetch.py`, 32 workers) that reuses the
pipeline's `fetch()`/`extract()` and serializes JSONL staging in the main thread — **4,743 URLs in ~6 min**.

- **3,898 ok / 845 failed (82%)** — all failures `RetryError` (paywalls / 403 / Cloudflare / dead links),
  expected for an open-web sweep; failure log in `scratchpad/fetch_fails.txt`. Blocked sources remain in
  `sources.yaml` for later retry (Playwright / archive.org) if a leaf needs them.
- `ingest load --domain market` → **3,898 sources + 3,898 documents** in DuckDB (~194M content chars,
  avg ~50K/doc, 123 thin <200-char extractions). Built BM25 FTS index `fts_market_documents`.
- Per-cluster docs: theory 1,412 · competitors 1,375 · ux 591 · market 212 · customers 65 · vpc 59 ·
  pricing 51 · partners 46 · companies 44 · business-model 43. All 73 leaves have documents.
- FTS verified: BM25 "cognitive load surface area panes" returns the right theory docs.
- All 73 leaves `b_ingest: partial` (none 100% due to web failures; lowest ~60%).

**Tooling note:** FTS index schema is `fts_market_documents` (not `fts_main_*`, since `market` isn't the
`main` schema). Query: `fts_market_documents.match_bm25(source_id, '<query>')`. Join docs↔sources on
`documents.source_id = sources.id`.

**Next:** Phase C (extract → entity tables) in dependency waves — Wave 1: `companies` (freeze company.id),
`market-landscape` (freeze feature taxonomy), all `theory-*` (theory_concepts), `market-trends`.
