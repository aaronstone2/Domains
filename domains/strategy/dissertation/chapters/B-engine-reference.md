## Appendix B — Engine & CLI Reference

This appendix is a working reference for the Strategy-OS engine that produced the corpus behind this dissertation. It makes no strategic claims about MetroGraph; its sole purpose is reproducibility. A reader who clones the repository should be able to read this appendix, run the listed commands in order, and arrive at the same database, the same verdicts, and the same rendered artifacts the body argues from. Where the body asks the reader to *trust* a verdict, this appendix shows the machinery that *computes* it — and, just as important, the machinery that withholds upgrades the evidence has not earned. Two properties carry that guarantee throughout: the schema is domain-agnostic and auto-extending, and the entire artifact is regenerable from committed state.

### B.1 The shared base schema

Every domain folder under `domains/` (excluding `_shared`) is auto-discovered and provisioned with one identical base schema (`domains/_shared/schema.sql`), instantiated into a per-domain DuckDB schema namespace. That uniformity is what makes the rest of the engine possible: because column shapes are constant across domains, every cross-domain view, FTS index, and synthesis query can treat the corpus as a single algebra rather than a federation of bespoke tables. The base layer materializes the following tables in each domain namespace:

| Base table | Role in the engine |
| --- | --- |
| `sources` | Provenance records — the cited origin of every fact (URL, study, doc). |
| `documents` | Fetched/normalized source bodies, the raw substrate for extraction. |
| `concepts` | Named entities and ideas extracted from documents. |
| `commands` | Reproducible procedures/CLI invocations captured per domain. |
| `config_keys` | Configuration surface captured during research. |
| `failure_modes` | Documented ways a thing breaks — the negative-evidence ledger. |
| `relationships` | Typed edges (`grounds`, `contradicts`, `erodes`, `gates`, `measures`, …) — the algebra the synthesis layer reads. |
| `claims` | The uniform gold layer: one row per assertion with a verdict, feeding `meta.all_claims`. |
| `claim_evidence` | Junction linking claims to the studies/sources backing them. |
| `primary_studies` | Registered primary research; emptiness here is itself a signal. |
| `derivations` | Provenance for *machine-derived* claims and edges (which rule fired, on what inputs). |
| `forecast_log` | Datable predictions (predicted_prob, `resolves_by`) for later Brier scoring. |
| `model_assumptions` / `model_runs` | Monte-Carlo inputs and fixed-seed output draws. |
| `recommendations` | Action items with a derived priority score. |
| `red_team_findings` | Falsifiers wired to live competitive signals. |
| `wedge_reeval` | Each wedge claim re-graded to its honest cross-domain ceiling. |
| `render_blocks` / `artifact_blocks` | The non-divergence projection feeding rendered artifacts. |
| `claim_history` | SCD-2 change tracking between snapshot labels. |
| `embeddings` | Local fastembed vectors for hybrid search. |

The placement of `claims` in the base layer rather than among a domain's extras is deliberate: a uniform gold layer lets `meta.all_claims` union every domain without special-casing. The same holds for `wedge_reeval`, `recommendations`, and `red_team_findings` — keeping their shapes constant is exactly what lets the synthesis domain read the whole algebra without redefining structures per source.

### B.2 Tables per domain

On top of that constant base, a domain may declare additional tables in `domains/<d>/schema.<d>.sql` using the `{{schema}}` placeholder, which `init-db` applies over the base. The table counts below are therefore uneven by design: richer domains carry more extension tables — feature taxonomies, funding rounds, compliance gaps, dated competitor changes — while the gold/base layer stays identical across all of them.

| Domain | Tables |
| --- | --- |
| market | 36 |
| voc | 23 |
| strategy | 21 |
| product | 20 |
| finance | 20 |
| hci | 19 |
| governance | 19 |
| compintel | 19 |
| ecosystem | 19 |

Market's 36 tables reflect its extension load — companies, funding rounds, features, primary studies, and related taxonomies. The `voc` extension set includes the intake tables `interviews`, `surveys`, `usability_sessions`, and `ab_experiments`, whose *emptiness* functions as the corpus's standing pending-experimental marker rather than a defect to be hidden.

### B.3 The CLI subcommand reference

Every engine operation is an `ingest` subcommand (Python via `uv`, under `domains/_shared/ingest/`). The subcommands map onto the layered pipeline described in Part II — ingest, the gold/verification layer, evidence, persistence, retrieval, reasoning, modeling, and projection — and the table below lists them in roughly that order of execution.

| Subcommand | Layer | What it does |
| --- | --- | --- |
| `init-db` | bootstrap | Create per-domain schemas from base + extension SQL; regenerate `meta.*` cross-domain views and the FTS build script from the live domain list. |
| `list` | bootstrap/util | Enumerate the auto-discovered domains, leaves, and models available to the pipeline. |
| `fetch` | ingest | Retrieve sources into the raw cache (`_db/raw/<domain>/…`). |
| `load` | ingest | Normalize fetched docs into `sources`/`documents`. |
| `load-extract --domain [--leaf]` | ingest | Upsert `{table: rows}` extension-table JSON from `extract/*.json`. |
| `verify --domain` | L6 | Assign per-claim `verification_standard`; compute Wilson CIs (`confidence_low/high`) and freshness/`stale` decay. |
| `calibrate` | L6 | Brier-score predictions in `forecast_log` against resolved outcomes. |
| `evidence --domain [--audit]` | L1 | Build `claim_evidence` ⋈ `primary_studies`; expose the `v_claim_grade` view; **derive** `is_primary_backed`. |
| `snapshot --label <L>` | L2 | Write every data table to committed parquet under `_shared/snapshots/<L>/`. |
| `restore --label <L>` | L2 | Reload parquet FK-safely into a fresh DB. |
| `diff --since <L>` | L2 | Report SCD-2 change between labels via `claim_history`. |
| `embed --domain` | L4 | Compute local fastembed vectors into `embeddings`. |
| `search --hybrid` | L4 | BM25 + vector RRF retrieval over the corpus. |
| `gaps` | L4 | Surface dedup/whitespace and missing-coverage gaps. |
| `reason --domain [--commit]` | L5 | Apply inference rules (`_shared/rules/*.yaml`) to derive edges and speculative claims with `derivations` provenance. |
| `model run --domain --model <id>` | L3 | Fixed-seed NumPy Monte-Carlo from `_shared/models/*.yaml` into `model_runs`. |
| `sensitivity --domain --model <id>` | L3 | Spearman rank-correlation of each input with the output over the MC draws (tornado). |
| `forecast --domain [--horizon <days>]` | L6 | Register predictive/speculative claims as datable `forecast_log` rows. |
| `watch --since <DATE>` | L8 | Scan the temporal layer for moves that erode a wedge feature or fire a falsifier; raise alerts read-only. |
| `decide --budget <pts>` | L9 | Exact 0/1 knapsack over `recommendations` within an effort budget. |
| `render [--out <dir>]` | L7 | Project `render_blocks` ⋈ `artifact_blocks` into a non-divergent family of `.md` artifacts. |

### B.4 Derived, not authored

Two engine behaviors are load-bearing for the dissertation's honesty thesis, and both are computed rather than written by hand. The first is `is_primary_backed`, which the `evidence` step *derives* from the `claim_evidence`/`primary_studies` junction: secondary evidence cannot be relabeled as primary, so a claim that is well-argued but lacks a registered primary study reads as "supported-by-proxy," never as measured. In the current corpus only HCI (46 of 49 claims) and VoC review-mining (42 of 63) carry any primary backing — and VoC "primary" means a user *said* something in a mined review, not that MetroGraph measurably fixes it. Market, product, finance, governance, ecosystem, compintel, and strategy are 0 primary-backed by construction.

The second is quarantine of the speculative claims produced by `reason`. When an inference rule fires, it writes a claim with a `derivations` provenance row and a speculative verdict, and only the L6 `verify` step can promote it. The derived contested-wedge claims — for instance the canvas and agent-orchestration features, each marked CONTESTED from dated competitor moves [C:strategy.claim.derived.contested-canvas] [C:strategy.claim.derived.contested-agent-orchestration] — are engine output, not editorial assertion, and they stay speculative until evidence promotes them. This is the mechanism that holds the 13 wedge claims in `wedge_reeval` at their cross-domain ceiling with `pending_experimental = TRUE`: nothing in this appendix's tooling can lift a wedge claim to "validated on MetroGraph," because the experiment that would do so has not run.

### B.5 The regenerability guarantee

The database is a disposable artifact, and `snapshot` is what makes that true. It writes every base and domain-specific data table — excluding only the regenerable `embeddings` and `claim_history` — to parquet committed under `_shared/snapshots/<L>/`. The canonical reconstruction is therefore two commands:

```
ingest init-db
ingest restore --label 2026Q2-complete
```

This round-trip has been verified to reconstruct 298 tables / 15.6k rows. Because the schema, the rules (`_shared/rules/`), the models (`_shared/models/`), and the snapshots (`_shared/snapshots/`) are all committed, and because `render` output lands under `domains/strategy/render/` as read-only regenerable files, the entire corpus — facts, verdicts, models, and artifacts — is reproducible from version control with no hidden state.

### B.6 Adding a domain

Extending the corpus requires no engine edits at all. Dropping a folder under `domains/` registers a new domain everywhere: `init-db` discovers it, applies the base schema plus any `schema.<d>.sql` extension, and *regenerates* the cross-domain `meta.*` views (`queries/cross_domain.sql`) and the FTS build script (`queries/fts_index.sql`) from the live domain list. Both generated files must not be hand-edited. From that point the new domain participates in `verify`, `evidence`, `reason`, `search`, and the synthesis projection on equal footing — which is precisely why the cross-domain grade computed in Part II is a property of the engine, not of any one chapter's prose.
