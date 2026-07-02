# finance — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## 2026-06-26 — A–E: comps + unit-economics (Wave 1; Monte-Carlo deferred to Wave 2)

2-stage Explore (comps off the corpus's own funding_rounds → web ARR estimates; then unit-econ
benchmarks → p10/p50/p90 assumptions). Loaded **8 comps**, **20 unit-economics** rows, **10
Monte-Carlo assumptions**, 9 claims (8 comps/unit + 1 derived valuation-band).

**Comps valuation band (derived):** graph-db/viz/workflow/lowcode comparables trade at **9.5x–37.4x
revenue (median 17.5x, n=8)** — Neo4j 11x, Retool 26.7x, Airtable 23x, n8n 62.5x (outlier). 8
`benchmarks` edges wire comps → market.companies.

**Honesty:** every figure is a comps/benchmark ESTIMATE; MetroGraph has **no revenue**, so the
valuation-band claim explicitly states a pre-revenue MetroGraph is an *option on reaching the SOM band*
($37.6M–$226.3M), not a multiple-based mark. All forward unit-econ (CAC $180/320/580, ARPU
$450/1200/3600, NRR 1.08/1.18/1.28, conversion 0.045) carry p10/p50/p90 + low confidence + basis=
'assumption'. The 10 assumptions feed the **Wave-2 Layer-3 Monte-Carlo** (`ingest model run`).

`ingest verify` (9 descriptive-standard claims) + `embed` (9 vectors) run.
