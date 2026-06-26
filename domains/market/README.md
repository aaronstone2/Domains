# `market` domain — MetroGraph market-research corpus

An exhaustive, DuckDB-backed **algebra of facts** for the go-to-market of **MetroGraph** (a metro-map-style
database-visualization node/edge graph tool; repo: https://github.com/mark1russell7/Graph/tree/fable). Built
by the corpus engine across **73 leaves** and phases A–E, culminating in a fully-cited research paper.

## Start here

- **The paper** → [`market-synthesis/extract/paper.md`](market-synthesis/extract/paper.md) — ~20.8k words,
  10 sections + Methodology + a 161-claim ledger. Self-auditing: every `[C:slug]` citation carries its
  adversarial verdict (✓supported / ~disputed / ✗refuted). Now backed by a populated `funding_rounds`
  table (327 rounds, 103 funded companies) and 138/161 claims grounded in corpus sources.
- **The plan** → [`PLAN.md`](PLAN.md) — charter, the algebra, tier rubric, the 73-leaf tree, cross-leaf
  contracts (C1–C14), dependency waves, acceptance tests.
- **The log** → [`PROGRESS.md`](PROGRESS.md) — session-by-session build (Sessions 0–4).
- **The queries** → [`queries/insights.sql`](queries/insights.sql) — the 13 strategy queries (whitespace,
  segment attractiveness, differentiation matrix, pricing gap, …). Materialized to
  `market-synthesis/extract/figures/*.json`.
- **Session-0 artifacts** → `_scope/` (registry, theory decomposition, leaf tree).

## Query it

```sh
duckdb -readonly _db/knowledge.duckdb < domains/market/queries/insights.sql
duckdb -readonly _db/knowledge.duckdb "SELECT name,pain_score FROM market.features ORDER BY pain_score DESC LIMIT 20"
```

The DB is a regenerable build artifact (gitignored): `ingest init-db` → fetch → load rebuilds it from the
committed `sources.yaml` + each leaf's `extract/*.json`.

## The algebra (`schema.market.sql`)

21 extension tables on the 7 base tables: entity spine (companies/funding_rounds/products/people/competitors/
partners), capability matrix (features + product_features A–F), VPC (segments/personas/jobs_pains_gains),
business model (pricing_models/tiers/bmc_blocks), UX teardown (ux_screens/flows/patterns), theory
(theory_concepts), and the gold layer (claims/reports/market_metrics). IDs: `market.<entity>.<slug>`;
MetroGraph's own rows use `market.{company,product}.us` + `is_self=TRUE`.

See `domains/_shared/sessions/extend-playbook.md` for the depth-configurable, re-engageable research flow.
