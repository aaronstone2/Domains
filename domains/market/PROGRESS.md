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

**Next:** Phase C (extract → entity tables) in dependency waves.

## Session 3 — 2026-06-25 — Phase C extraction (Wave 1 in progress) — PARTIAL

Validate-one-then-fan-out (Aaron's directive). Extension tables load via the `duckdb` CLI
(`read_json_auto` + `INSERT BY NAME`), NOT the base `ingest load` (which only does sources/documents).

- **`companies` (spine) — DONE + FROZEN.** Mapped the Session-0 registry → `market.companies`: **183
  companies** (182 + MetroGraph self-row `market.company.us`, is_self=TRUE) across 11 archetype categories.
  **`company.id = market.company.<slug>` FROZEN** (contract C1). funding_rounds/people/per-company
  source_ids = later enrichment (c_extract: partial).
- **theory cluster (29 leaves) — DONE.** `market-phaseC-theory` workflow (29 agents, 1.5M tokens): each
  agent read its `extract/sources.json` + pulled doc text via `duckdb -readonly`, extracted
  `theory_concepts`. Merged/deduped by `market.theory.<slug>` (879 raw → **773 concepts**), loaded.
  Fields: hci 191 · interaction-design 182 · visualization 149 · cognitive-psych 142 · graph-theory 44 · … .
  1,174/1,521 citations resolve to ingested sources (~77%). All 29 `c_extract: done`.
  - Bug fixed: 10 agents returned `leaf` as `market/<name>` (prefix) → merge script now strips it; removed
    spurious `domains/market/market/*` dirs created by the first run.

## Session 4 — 2026-06-26 — Phase C (Waves 1-4) + Phase D + Phase E + the paper — DONE

Drove the rest on full autopilot ("don't stop till done"). Each phase = a workflow returning structured
rows; deterministic load scripts merge into DuckDB (extension tables via `read_json_auto` + `INSERT BY NAME`).

**Phase C (remaining waves):**
- `market-landscape` — FROZE the feature taxonomy (contract C3): **110 features / 20 capability areas**
  (2-proposer + synthesizer panel).
- competitors (24 leaves) — **187 products**, the **1,168-cell product×feature differentiation matrix**
  (A-F quality + hci_cost), **176 competitor roles**. 3 leaves hit the StructuredOutput size cap → re-run
  with tighter feature caps. **+36 companies discovered (continuous discovery C1): 183 → 213.**
- `customer-segments` (FROZE segment.id) — 12 segments, 12 personas, 40 jobs/pains/gains; `market-sizing` —
  66 market_metrics, 33 reports.
- `pricing` — 22 models / 45 tiers; `partners-integrations` — 28 partners (21 relevant_to_us).
- `value-prop` — MetroGraph self-row (`market.product.us`) + **35 self product_features** (A-grade wedge),
  value-map (jpg.our_relief), relationships; `business-model` — **9/9 BMC blocks**.
- `ux-teardown-*` (10 leaves) — **85 ux_screens, 50 ux_flows, 99 ux_patterns (79 antipatterns)** — the
  quantified "endless panes / flight-to-chat" evidence (e.g. n8n advanced-workflow flow = 52 clicks, F hci_cost).
- Validated the algebra: whitespace + differentiation queries return real strategy.

**Phase D — gold claims (adversarial):** D-1 generated **161 decision-grade claims** (8 cluster generators);
D-2 = **63 skeptics / 3.5M tokens / 2,549 corpus queries** refuting each against the ingested corpus.
Merged by agreement: **80 supported · 31 disputed · 49 refuted · 1 equivalent** (81 ≥ 0.66 agreement). The
verifier is calibrated strict (demands corpus-quotable evidence), so interpretive/strategic claims skew
disputed/refuted even when sound — recorded honestly, not dropped.

**Phase E — relationships:** derived **757 typed edges** (evidenced_by 193, has_product 187, competes_with
176, grounded_in 143, relieves 42, belongs_to_segment 12, substitute_for 4).

**The paper — `market-synthesis/extract/paper.md`:** 10-section writer panel → assembled to **~22,560 words /
1,443 lines**: exec thesis, market+sizing, HCI problem+theory, competitive landscape, UX evidence, whitespace
+differentiation, ICP+VPC, business model+pricing, GTM, risks — plus Methodology + a full **161-claim ledger**
appendix. Made **self-auditing**: every in-body `[C:slug]` is annotated with its verdict+agreement glyph
(✓supported / ~disputed / ✗refuted) + a citation-integrity legend, so no claim is overstated.

**The corpus is complete and queryable** via `duckdb -readonly _db/knowledge.duckdb` and
`domains/market/queries/insights.sql`. Floors, not ceilings — every leaf can be deepened further; companies
keep growing via continuous discovery; blocked sources can be re-fetched (Playwright/archive.org).

## Session 5 — 2026-06-26 — Verification audit + paper honesty revision — IN PROGRESS

Ran a full deterministic audit (algebra row counts, phase STATUS, citation resolution, git) +
an **independent adversarial reviewer** of the paper. Verified: all phases done; algebra populated
(funding_rounds + people intentionally empty); paper 22.8k words / 10 sections / 13 figures; committed
(91f5afa). Polish commit 6382e39 fixed 14 mis-tagged citations + flipped meta_research done + removed
two stray root scratch files.

**Reviewer's key finding (acted on):** the v1 paper's §1–§9 asserted corpus-REFUTED wedge claims
(metro-map superiority, flight-to-chat root cause, HCI-cost parity, market fragmentation) in declarative
voice, then §10 retracted them; plus a fabricated KG figure (used refuted 31.9% vs the real 14.2%), a
stitched $63.9B TAM, and ~46 citations using [C:] for non-claim entities. The honest, SUPPORTED thesis
(MetroGraph as a specialized tool; wedge = the supported *unserved* features) was buried in §10.

**Fix in progress:** regenerating the paper with hard verdict-discipline — assert only
supported/equivalent claims; frame refuted ones explicitly as hypotheses pending A/B validation; anchor on
the supported unserved-feature whitespace; verified numbers only; correct citation prefixes ([C:] claims,
[E:] entities). Then re-assemble + re-annotate + commit.

**Deferred (next):** populate funding_rounds (fix §4/§9 competitive-funding gap; people still deferred);
backfill source_ids on the 46 unsourced claims; retry 845 blocked sources; recalibrate verification for
interpretive claims (2-source cross-check vs strict refute-panel).
