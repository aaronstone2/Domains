# Plan — `market/competitors-workflow-automation-ipaas`

## Leaf spec (Session 0)

- **Cluster:** competitive
- **Depth:** exhaustive (Session-0 risk-weighted suggestion was `exhaustive`; overridden to exhaustive per directive)
- **Scope:** Mainstream node-based iPaaS (canonical surface-area-bloat set): Zapier, Make, n8n, Workato, Tray.ai, Pipedream.
- **Primary tables:** `products`, `product_features`, `competitors`
- **Depends on:** `companies`, `market-landscape`
- **Claim categories (owned):** `competition:comp.wfa-ipaas.*`, `feature:comp.wfa-ipaas.feat.*`
- **Row estimate:** 6 products, ~60 product_features
- **Why this is its own leaf:** workflow-automation (12) > cap; mainstream iPaaS vs OSS/embedded split. Exhaustive: wedge-target HCI evidence.


> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> Set **depth** (`scout` | `standard` | `exhaustive`) in `STATUS.yaml` — it governs how wide each
> phase fans out and how hard the gold layer (Phase D) is verified. See
> `domains/_shared/sessions/depth-profiles.md`. The re-engagement contract (how a future session
> resumes this leaf) is `domains/_shared/sessions/extend-playbook.md`.

## Context

Why this leaf exists: <one paragraph — what this leaf covers, why it matters, and what kind of
question/answer the corpus must be able to serve from it>.

How it composes: <which leaves/domains it underpins or draws on. Cross-domain links are wired in
Phase E *as you discover them*, not deferred to a final pass>.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus any domain-specific tables declared in `domains/<domain>/schema.<domain>.sql`.

<List the tables this leaf actually fills and the rough row target per depth profile.>

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — sitemaps, ToCs, repo
trees, the authorities; (2) **Plan** agent(s) design the per-leaf extraction — which sources, which
tables, what verification looks like; (3) `AskUserQuestion` on high-leverage forks (scope, depth);
(4) write this PLAN + `STATUS.yaml`; (5) `ExitPlanMode`.

The irreducible work is the **gold layer (Phase D)**. Everything before it is mechanical (find URLs,
fetch, parse). The meta-research exists to protect the expensive layer from being spent on the wrong
sources.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to this leaf.

- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` (or a leaf-local `sources.yaml`).
- [ ] For each: `tier` (T0–T3 = evidence/authority grade), `license_note`, `parser`. Skim once; drop redundancy.
- [ ] Width scales with depth (see depth-profiles): `scout` ~top sources only · `exhaustive` full sweep + reference-chasing.
- [ ] **Verify:** `uv run python -m ingest list --domain <d> --subdomain <s>` shows N rows; eyeball pass.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain <d> --subdomain <s>` → fills `sources`/`documents`, caches raw under `_db/raw/`.
- [ ] `uv run python -m ingest load --domain <d>` (close the motherduck MCP first — it holds a read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Verify:** doc count + mean length match expectations; spot-check 3 random docs render as clean markdown.

## Phase C — Extract → entity tables

Goal: structured rows for the lookup-able entities in this leaf.

- [ ] Extract into the leaf's target tables; land via JSON in `extract/<table>.json`, then `ingest load`.
- [ ] **Verify:** counts within the depth-profile order-of-magnitude; sampled rows have resolvable `source_ids`.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: the queryable, **evidence-graded** layer — the part a human couldn't get from one search.

- For debugging-style domains this is `failure_modes` (symptom → diagnostic → fix → cite). For
  evidence-style domains it's the claims/constraints layer (a recommendation → what the literature
  actually shows → verdict → cite).
- [ ] Each fact: the statement, supporting/contradicting `source_ids`, an evidence/confidence grade.
- [ ] **Verification scales with depth:** `scout` none · `standard` single spot-check ·
      `exhaustive` **N independent skeptics per claim, each prompted to refute; keep only majority-survivors, record the dissent.**
- [ ] **Verify:** sample facts re-derive from their cited sources; contradictions are recorded, not silently dropped.

## Phase E — Relationships → typed graph

- [ ] Wire `affects`, `depends-on`, `substitutes`, `targets`, `evidenced-by`, etc. within and across leaves.
- [ ] **Verify:** a graph walk from a seed node reaches ≥3 sensible hops.

## On completion

- [ ] Update `STATUS.yaml` (phase → `done`, `updated:` date) and append a session entry to `PROGRESS.md`.

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- Sibling leaves under this domain — copy their `extract/*.json` shape as a starting point.

## Open questions

- <Track unresolved decisions here so the next session picks them up.>
