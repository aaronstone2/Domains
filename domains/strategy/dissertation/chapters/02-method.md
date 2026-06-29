## Part II — Method: The Strategy-OS Engine

Part I promised that in this corpus a grade is *derived*, never asserted — that the line between what evidence supports by proxy and what only a not-yet-run experiment could prove would be mechanized rather than left to the author's discretion. This chapter describes the machine that keeps that promise. It is not a metaphor but a regenerable DuckDB database, a set of typed tables, a handful of idempotent pipeline commands, and a sequence of derivation steps that together compute every verdict and every figure the rest of the dissertation displays. A reader who finishes this chapter should be able to open any downstream chart — a market-whitespace bar, an HCI grounding edge, a wedge-ceiling glyph — and read it as the output of a function whose inputs and rules are inspectable, not as a conclusion the author wished to reach. The engine exists precisely to deny the author the ability to assert; it can only compute, grade, and surface.

### The corpus as a regenerable artifact

The substrate is a single DuckDB file, `_db/knowledge.duckdb`, populated by a Python ingest pipeline under `domains/_shared/ingest/`. The principle that governs everything else is that the database is a *build product*, not a source of truth. Truth lives in committed text — domain folders, extraction JSON, rule YAML, model YAML — and in committed parquet snapshots. Running `init-db` followed by `restore --label 2026Q2-complete` reconstructs the entire corpus from that committed state; the round-trip has been verified at 298 tables and roughly 15.6k rows. Nothing in the analysis depends on a database that exists on only one machine: delete the file and it rebuilds byte-for-byte from version control. This matters for honesty as much as for engineering, because a reviewer can regenerate the corpus and recompute every grade independently, so no verdict can quietly drift from its evidence between readings.

The architecture is domain-agnostic and auto-discovering. A "domain" is simply a folder under `domains/`, and dropping one in registers it everywhere — `init-db` creates its schema, regenerates the cross-domain `meta.*` views, and rebuilds the full-text-search index from the live domain list. Every domain inherits the same base schema (`sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`, `relationships`, and crucially `claims`) and may declare extra tables of its own. The corpus spans nine analytical domains, whose table counts track how much structured machinery each required:

| Domain | Tables |
| --- | ---: |
| market | 36 |
| voc | 23 |
| strategy | 21 |
| finance | 20 |
| product | 20 |
| ecosystem | 19 |
| compintel | 19 |
| hci | 19 |
| governance | 19 |

Because `claims` is a *base* table present in every domain, the engine projects a single cross-domain view, `meta.all_claims`, that unions all 406 graded claims into one queryable gold layer. The synthesis domain, `strategy`, reads this union — and the relationship algebra below — strictly read-only; it never mutates another domain's verdicts. The conflation guard is enforced structurally, and the `market.claims` snapshot diff stays 0/0/0 across synthesis runs. The strategist may *read* the algebra and *re-grade against it* but cannot reach back to edit the evidence to suit a conclusion.

### The nine engine layers

On top of this substrate sit nine engine layers, each a set of `ingest` subcommands. All are backward-compatible and idempotent, so re-running them never corrupts state. The table names them in order; later sections deep-dive the layers that do the heavy lifting for the rest of the dissertation.

| Layer | Command(s) | What it computes |
| ---: | --- | --- |
| 1 | `evidence` | Builds the `claim_evidence` junction and `primary_studies`, then exposes the `v_claim_grade` view; `is_primary_backed` is computed here, never written by hand. |
| 2 | `snapshot` / `restore` / `diff` | Writes every data table to committed parquet, reloads it FK-safely, and tracks SCD-2 change between labels. |
| 3 | `model` / `sensitivity` / `forecast` | Runs fixed-seed NumPy Monte-Carlo from `_shared/models/*.yaml` into `model_runs`, with a Spearman tornado and forecast registration. |
| 4 | `embed` / `search` / `gaps` | Local fastembed vectors, an HNSW index, and BM25+vector hybrid retrieval with RRF fusion for dedup and gap-finding. |
| 5 | `reason` | Applies inference rules from `_shared/rules/*.yaml` to derive new relationship edges and new *speculative* claims carrying `derivations` provenance. |
| 6 | `verify` / `calibrate` | Assigns each claim a `verification_standard`, a Wilson confidence interval, and a freshness decay; scores predictive claims by Brier loss against the forecast log. |
| 7 | `render` | Projects `render_blocks ⋈ artifact_blocks` into a non-divergent family of Markdown artifacts. |
| 8 | `watch` | Scans the temporal layer for post-cutoff competitor moves that erode a wedge feature, raising alerts without mutating the synthesis. |
| 9 | `decide` | Solves an exact 0/1 knapsack over recommendations within an effort budget, producing a committed action set rather than a ranking. |

Every figure in this dissertation is a query against the outputs of these layers. No slide exists outside the machine.

### The typed relationship graph as algebra

The single most important structure for reading the rest of the work is the relationship graph. Across the corpus the engine holds 2,095 typed edges spanning 21 relationship types, and this graph is exactly the algebra the synthesis layer reads when it re-grades a claim.

![Figure — The typed relationship graph (2,095 edges, 21 types) is the algebra the synthesis layer reads: grounds/contradicts from HCI, erodes from competitive intel, gates from governance, measures from product.](figures/relationship_graph.png)

The edge *types* carry the argument's logical connectives. A `grounds` edge from the HCI literature attaches empirical support to a market or wedge claim; a `contradicts` edge attaches refutation; an `erodes` edge from competitive intelligence records a dated competitor move against a feature MetroGraph claims as differentiation; a `gates` edge from governance marks a compliance blocker between the product and a segment; a `measures` edge from product ties a claim to a shipped capability. Because the relationships are typed and directional, the synthesis does more than count citations — it can ask whether a claim is grounded but also eroded, supported by literature but gated by compliance, and let those forces net out into a verdict. This is what it means to say a claim is only as strong as its derived, cross-domain evidence grade: the grade is literally a function over the edges incident to the claim.

### Evidence grading: is_primary_backed is derived, never authored

The keystone of mechanized honesty is the rule that a claim cannot declare its own evidentiary tier. The `v_claim_grade` view computes `is_primary_backed` from the `claim_evidence` junction: a claim reads as primary-backed only when it connects to an actual primary study. Secondary evidence cannot masquerade as primary, and a claim that is well-supported but lacks any primary link reads honestly as *supported-by-proxy* — the wedge honesty cap. The author can pile up secondary citations and the grade will not rise above proxy, because the function that sets the tier does not read the author's confidence; it reads the evidence table.

![Figure — Claims with derived primary backing (green) vs proxy/secondary support (grey), by domain. Only HCI (46/49) and VoC review-mining (42/63) carry primary backing; market/product/finance are secondary by construction.](figures/evidence_grade.png)

The result is stark, and the engine surfaces the starkness rather than hiding it. Only two domains carry any primary backing at all: HCI, where 46 of 49 claims are primary-backed by 21 catalogued primary studies, and VoC, where 42 of 63 claims rest on review-mining. Everywhere else — market, product, finance, ecosystem, compintel, governance, and strategy — the primary-studies count is effectively zero and claims are secondary by construction. The evidence-class tallies make the same point from the raw side: HCI contributes 85 primary and 74 secondary evidence rows and VoC 42 primary, while market contributes 240 secondary rows and zero primary, and product just 17 secondary. The corpus-wide near-emptiness of `primary_studies` is not a defect to paper over; it is the finding. And the VoC "primary" tier carries its own caveat the engine respects: review-mining establishes that a *user said* something, not that MetroGraph measurably fixes it. The standing pending-experimental marker is the set of empty intake tables — `voc.interviews`, `voc.surveys`, `voc.usability_sessions`, `voc.ab_experiments`, and `market.primary_studies` all sit at zero rows. Those zeros are visible, queryable, and load-bearing: they are what cap the wedge.

### Confidence, freshness, and the forecast loop

Layer 6 attaches three quantitative disciplines to each claim. A Wilson confidence interval converts the supporting-evidence ratio into `confidence_low`/`confidence_high` bounds, so a claim backed by two sources and one backed by twenty do not read as equally certain. A freshness decay marks claims `stale` as their evidence ages, so the corpus cannot quietly coast on dated sources. And each claim is tagged with a `verification_standard` — *descriptive* (what is), *evaluative* (how good), or *predictive* (what will happen) — because the bar for "supported" differs by kind.

Predictive and speculative claims feed the forecast loop. The engine registers each as a datable `forecast_log` row, deriving a predicted probability from confidence and a `resolves_by` horizon. Sixty-five forecasts are currently logged and — honestly — zero are resolved, so the mean Brier score is null. The corpus is not yet calibrated because the future it predicts has not yet arrived; outcomes will be filled in by `resolve`, never auto-assumed. This is the same emptiness as the intake tables in a different register: the apparatus to score predictions exists and is wired up, but it has nothing to score yet, and it says so.

### Reasoning: quarantined, speculative derivations

The reasoning layer is where the engine generates new claims, and also where the honesty discipline is most easily mistaken. Rules in `_shared/rules/*.yaml` derive edges (`transitive`, `sql_edge`) and claims (`sql_claim`) from existing structure, attaching a `derivations` provenance record to each. The `derive-contested-wedge` rule, for instance, reads the compintel erosion edges and emits a contested-wedge claim for each wedge feature under sustained competitive attack. It produced nine such claims, each with a `confidence_out` between 0.40 and 0.50 — exactly the band of an inference, not a finding.

Two are featured here. The rule infers that the canvas wedge is contested because nineteen dated competitor moves erode it [C:strategy.claim.derived.contested-canvas], and that agent orchestration is contested because eleven dated moves erode it [C:strategy.claim.derived.contested-agent-orchestration]. Both carry the verdict *speculative*. They are not findings but quarantined hypotheses the engine generated and then refused to promote. A derived claim stays speculative until Layer 6 verification independently promotes it on its own evidence — derivation buys a claim a place in the queue, not a grade. The reader should treat every `claim.derived.*` id throughout this dissertation the same way: as the machine reasoning aloud under quarantine, never as a result.

### Models are estimates, not measurements

Layer 3 runs Monte-Carlo simulations with a fixed seed of 42 over 10,000 draws, so any reader can rerun and reproduce the distribution exactly. Two runs anchor the financial and market chapters:

| Model | Output | p10 | p50 | p90 |
| --- | --- | ---: | ---: | ---: |
| `finance-ltv-cac` | LTV:CAC ratio | 2.56× | 8.47× | 28.2× |
| `market-som` | SOM (USD) | $37.6M | $93.6M | $226.3M |

The width of these intervals is the point. MetroGraph is pre-revenue with no behavioral telemetry, so every model input is a comparable or an assumption carrying its own uncertainty, and the Monte-Carlo propagates that uncertainty into honestly wide outputs. The LTV:CAC median clears the 3× SaaS-health line but the p10 tail does not — and the engine prints both. These are option-value bounds, not marks or guarantees, and the named experiments that would replace assumptions with measurements are roadmap items, not inputs that will inevitably arrive.

### Render and the self-auditing glyph

The final discipline is presentational. The render layer projects shared metrics into a non-divergent family of artifacts, so a figure that appears in both the investor deck and the strategy memo is byte-identical — there is no opportunity to quietly soften a number for one audience. More important, every rendered figure carries a verdict glyph encoding its evidence tier: a proxy-only wedge cannot render as measured, and a modeled estimate cannot render as observed. The glyph is computed from `v_claim_grade`, not chosen by the author. This is why the same thirteen wedge claims can be carried through ten downstream chapters and tightened against market, literature, product, voice, and competition without ever inflating: at each pass the grade is recomputed by the machine, and the machine is built so that *supported-by-proxy* is the ceiling until an empty intake table fills. The rest of the dissertation is the reading of that machine's output.
