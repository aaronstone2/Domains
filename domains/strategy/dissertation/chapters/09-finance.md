## Part IX — Financial Model

The enterprise gate of Part VIII bounds *when* revenue can begin: until the compliance blockers clear, the obtainable market is the self-serve and team tiers, not the regulated accounts that anchor the largest comps [C:claim.metrograph.no-soc2-path-without-audit]. This chapter takes that timing as given and asks the next question — *if* revenue begins, what do the unit economics and the valuation look like? The honest answer is a distribution, not a point. MetroGraph is pre-revenue: no ARR to multiply, no measured CAC, no observed churn curve, no telemetry of any kind. Every number below is an industry benchmark or a comparable-company multiple, pushed through a fixed-seed Monte-Carlo so that the *width* of our ignorance is visible rather than hidden behind a single confident figure. The comps bound an option value on reaching scale; they are not a mark on a thing that exists today. That caveat is not a footnote to this chapter — it is its spine.

### The benchmark unit-economics model

The model is built bottom-up from a single ICP cohort and a set of developer-infrastructure SaaS benchmarks, then assigned MetroGraph-specific p50 estimates that sit deliberately near, not above, the industry medians. The central assumptions are summarized below; each is a benchmark-anchored estimate, and none reflects a MetroGraph observation.

| Driver | MetroGraph p50 | Benchmark anchor | Basis |
| --- | --- | --- | --- |
| ARPU | $1,200/yr | $348/yr (dev-tools median) | SMB + mid-market tier blend |
| CAC | $320 | $248 (dev-tools cohort, n=1,420) | PLG-weighted, sales-assisted expansion |
| CAC payback | 10.2 mo | 9.4 mo (dev-tools median) | hybrid PLG/sales motion |
| Gross margin | 79% | 77% overall / 81% subscription | pure software, no services |
| NRR | 1.18× | 1.25× (infra/DevOps) / 1.01× (B2B median) | land-and-expand across tiers |
| Logo churn | 3.5% / yr | 3.5% (B2B median) / 1.8% (infra) | balanced SMB/mid-market |
| Conversion | 4.5% | 9% (PLG freemium avg) | conservative early-funnel |

These figures cash out in claim [C:claim.metrograph.unit-econ.01], which holds that MetroGraph can reach a 3.0–3.8× LTV:CAC ratio if NRR sustains 115%+ while keeping payback under twelve months, and in [C:claim.metrograph.unit-econ.03], which positions the $320 PLG-weighted CAC and 10.2-month payback as 8–15% more efficient than the dev-tools median. Both carry the verdict **speculative** and zero primary backing — the entire finance domain is zero primary-backed by construction, because the only evidence that could raise the ceiling is a study no one has run. The supporting logic is sound and benchmark-consistent; it is not measured. Claim [C:claim.metrograph.unit-econ.04] extends the same conditional reasoning to self-sustaining economics — 79% gross margin and 1.18× NRR funding acquisition out of expansion revenue, *contingent on* holding logo churn below 4% — and is likewise speculative.

These assumptions sit against a macro headwind worth registering, because the benchmarks themselves are under pressure. Median CAC payback extended from 14 to 18 months between 2023 and 2024 [C:finance.claim.cac-payback-extension-2024]; the 75th percentile of SaaS companies spent $2.82 per $1 of new ARR in Q4 2024 — negative unit economics, the worst in the dataset's history [C:finance.claim.ltv-cac-deterioration-q4-2024]; and cohort NRR compressed roughly 4% from its 2021 peak [C:finance.claim.nrr-compression-2021-2024]. Against that backdrop, a 120%-NRR floor is precisely the line that separates structural margin pressure from sustainable growth [C:finance.claim.enterprise-nrr-floor-120pct], and MetroGraph's 1.18× p50 sits *just below* it. The PLG motion is the partial answer: product-led companies post a median Rule-of-40 score of 34 against 20 for sales-led peers [C:finance.claim.plg-rule40-outperformance] — though that signal only becomes discriminating above $20M ARR, below which growth is universally expected to outrun profitability [C:finance.claim.rule40-20m-arr-threshold]. MetroGraph would spend its entire early life below that threshold.

### LTV:CAC as a distribution, not a number

Collapsing those assumptions into a single LTV:CAC ratio would be the dishonest move. Instead the corpus runs a three-year bounded Monte-Carlo (`finance-ltv-cac`, seed 42, n=10,000), drawing ARPU, CAC, gross margin, and logo churn from their benchmark-anchored distributions and propagating the joint uncertainty. The result is claim [C:finance.claim.ltv-cac-band]:

| Percentile | LTV:CAC | Reading |
| --- | --- | --- |
| p10 | 2.56× | below the 3× venture floor |
| p50 | 8.47× | clears 3× with headroom |
| p90 | 28.2× | optimistic expansion cohort |
| mean | 13.3× (σ = 16.5) | right-skewed, long tail |

![Figure — Modeled LTV:CAC distribution: p10 2.56×, p50 8.47×, p90 28.2×. The wide spread reflects pre-revenue assumption uncertainty; the median clears the 3× SaaS-health line but the p10 tail does not.](figures/ltv_cac.png)

The median clears the 3× SaaS-health line comfortably, and the right tail is genuinely attractive. But the honest sentence is the one about the left tail: **the p10 outcome of 2.56× sits below the 3× floor.** The economics are *plausible*, not *proven* — roughly one modeled draw in ten breaks the line that venture underwriting treats as the minimum. The enormous standard deviation (16.5 against a mean of 13.3) is not noise to be smoothed away; it is the faithful report of how little we know when every input is an assumption and none is an observation. A single headline "8.5× LTV:CAC" would be a category error. The distribution is the claim.

### The comparables band and the valuation question

Because there is no ARR, a revenue multiple cannot produce a valuation — it can only describe the neighborhood MetroGraph would enter if it arrived. The corpus indexes thirty financing comps across graph-DB, visualization, workflow-automation, and low-code categories (median 33.0×, range 6.0×–80.0×). A representative slice of the named comps:

| Company | Stage | Revenue multiple |
| --- | --- | --- |
| Temporal | Series B | 66.7× |
| n8n | Series C | 62.5× |
| Mage | Series A | 50.0× |
| Dagster | Series C | 50.0× |
| Graphistry | Series C | 41.7× |
| Retool | Series C | 26.7× |
| Airtable | Series F | 24.5× / 23.0× |
| Webflow | Series B | 18.8× |
| Grafana Labs | growth | 16.7× |
| Figma | IPO | 16.7× |
| Zapier | secondary | 16.1× |
| Neo4j | Series F / PE | 13.3× / 11.0× |
| Creatio | Series B | 6.0× |

![Figure — Revenue multiples of graph-DB / viz / workflow / low-code comparables (n=30, median 33.0×). Each point is a public/known financing comp; MetroGraph is pre-revenue, so these bound an option value, not a mark.](figures/comps_multiples.png)

The spread is the story. The high end is dominated by recent rounds carrying an AI-narrative premium — n8n's 62.5×, Temporal's 66.7×, the Series-A and -C estimates near 80× — while the durable, post-maturation multiples cluster far lower: Stripe normalized to 17.9× as developer infrastructure matured [C:finance.claim.stripe-17.9x-multiple-2025], and dev-tool/analytics multiples broadly compressed from the 14–26× of the 2019–2021 era to roughly 10–17× by 2024–2025 [C:finance.claim.revenue-multiple-compression-devtools]. Claim [C:finance.claim.valuation-band] takes the conservative, tightened cut — a curated n=8 of the closest comparables trading at 9.5×–37.4× (median 17.5×) — and draws the only honest conclusion: a pre-revenue MetroGraph has no ARR to multiply, so any valuation is **an option on reaching the SOM band, not a multiple-based mark**.

That SOM band is the modeled serviceable-obtainable market carried forward from the market chapter: at 18% SAM penetration (p50), $1,200 ARPU, 1.18× NRR, and 3.5% churn, the cohort math yields a $37.6M–$226.3M ARR band with a p50 near $93.6M [C:claim.metrograph.unit-econ.02] — itself among the lowest-graded of the unit-econ claims (**speculative**, evidence grade *low*, tied with [C:claim.metrograph.unit-econ.04]), because it stacks the SAM-penetration assumption on top of all the unit-economics assumptions. The valuation is therefore an option on an estimate built on estimates. The corpus reports it as exactly that.

One comps claim must be flagged explicitly. Claim [C:finance.claim.metrograph.revenue-multiple-band] — which argues a 15–22× multiple is defensible at scale against a 6–27× comps range, discounting n8n's 62× as an AI-pivot artifact — carries the verdict **disputed**, and it is reported here as disputed, not quietly upgraded. The dispute is real: the same n=30 set has a *median* of 33.0×, well above the claim's 6–27× framing, so whether the relevant band is the conservative low-teens or the inflated high-30s is genuinely contested by the data. We surface the disagreement rather than resolve it by assertion.

The valuation-stage claims around this band are all speculative and serve as orientation, not targets: a $15–50M seed band benchmarked to Memgraph's early ~$19M [C:finance.claim.metrograph.seed-valuation], a $100–300M Series-A band conditional on traction matching workflow-automation entrants [C:finance.claim.metrograph.series-a-band], and a market-tailwind argument resting on a graph-DB market growing 14–16% and a diagramming segment projected from $2.17B to $12.07B by 2035 [C:finance.claim.metrograph.market-tailwind]. The tailwind cuts both ways as precedent: Supabase's 11.7× valuation run was *earned by* a 10.6× ARR expansion from $16M to $170M [C:finance.claim.supabase-valuation-acceleration], and Zapier reached $310M ARR on $1.4M of capital [C:finance.claim.zapier-capital-efficiency-1.4m-310m] — proof that the multiples follow revenue, which MetroGraph does not yet have. The comps describe where the door leads; they say nothing about whether MetroGraph walks through it.

### Sensitivity: which assumptions own the spread

If the outputs are distributions, the right diagnostic question is *which inputs drive the width*. Two views answer it. The first simply records how wide each input assumption is — its p10-to-p90 range and p50 — since an input the model barely varies cannot move the output much. To keep the two diagnostics reconcilable, the rows below are **exactly the inputs of the two runs decomposed in the next table**: the three drivers of the market `som` run (the source of the $37.6M–$226.3M SOM band) and the four drivers of the `finance-ltv-cac` run, each taken from the same assumption rows that produced the reported distributions:

| Model | Driver | p10 | p50 | p90 | spread (p90/p10) |
| --- | --- | --- | --- | --- | --- |
| SOM | obtained penetration (`som_share`) | 0.2% | 0.5% | 1.0% | 5.0× |
| SOM | serviceable share of envelope (`sam_share`) | 12% | 18% | 25% | 2.1× |
| SOM | addressable envelope (`tam_usd`) | $90B | $100B | $120B | 1.3× |
| LTV:CAC | ARPU (`arpu`) | $450 | $1,200 | $3,600 | 8.0× |
| LTV:CAC | CAC (`cac`) | $180 | $320 | $580 | 3.2× |
| LTV:CAC | logo churn (`logo_churn`) | 1.5% | 3.5% | 5.5% | 3.7× |
| LTV:CAC | gross margin (`gross_margin`) | 72% | 79% | 86% | — |

Input width alone, though, does not establish influence — a wide input the output happens to be insensitive to still contributes little. The genuine diagnostic is a *variance decomposition*: the Spearman rank-correlation of each input with the model output across all 10,000 draws (seed 42), reported alongside its squared, normalized share of the output's explained rank-variance. Unlike the input ranges above, this **is** an empirical attribution of where the output spread comes from — computed from the simulated draws themselves by the engine's `ingest sensitivity` pass (reproducible at seed 42, n=10,000), not asserted:

| Model | Driver | Spearman ρ | Share of variance |
| --- | --- | --- | --- |
| SOM (`som_usd`) | obtained penetration of SAM (`som_share`) | +0.88 | ~61% |
| SOM (`som_usd`) | serviceable share of envelope (`sam_share`) | +0.39 | ~27% |
| SOM (`som_usd`) | addressable envelope (`tam_usd`) | +0.16 | ~11% |
| LTV:CAC (`ltv_cac_ratio`) | ARPU (`arpu`) | +0.86 | ~60% |
| LTV:CAC (`ltv_cac_ratio`) | CAC (`cac`) | −0.47 | ~33% |
| LTV:CAC (`ltv_cac_ratio`) | gross margin (`gross_margin`) | +0.07 | ~5% |
| LTV:CAC (`ltv_cac_ratio`) | logo churn (`logo_churn`) | −0.02 | ~1% |

![Figure — Genuine variance decomposition: the Spearman rank-correlation of each input with the model output over 10,000 Monte-Carlo draws (seed 42). SOM is dominated by obtained penetration (som_share, ρ = +0.88, ~61%); LTV:CAC by ARPU (ρ = +0.86, ~60%) and CAC (ρ = −0.47, ~33%, negative because higher CAC lowers the ratio). This shows where the output variance actually comes from, not the input ranges.](figures/sensitivity_tornado.png)

The decomposition is unambiguous about where the spread lives. The SOM band is **~61% determined by a single input** — `som_share`, the obtained penetration of the serviceable market (ρ = +0.88) — with serviceable share (~27%) and the addressable envelope (~11%) trailing; the entire SOM distribution effectively turns on the one assumption MetroGraph has no data behind. The LTV:CAC band is **~60% ARPU and ~33% CAC** (the CAC correlation is negative, exactly as it should be — higher acquisition cost lowers the ratio), with gross margin and logo churn together under 6%. Both headline spreads therefore collapse to two pre-revenue assumptions — obtained penetration and ARPU — which is precisely why the financial figures in this chapter are option-value bounds, not marks: tighten those two inputs with real cohort data and most of the width disappears, but only telemetry can tighten them, and there is none.

One caveat survives the upgrade. This is a variance decomposition of the **model**, computed from its own assumption-driven draws — it faithfully reports which inputs the *model* is most sensitive to, not which factors will move a real revenue line. MetroGraph is pre-revenue: there are no realized outcomes to regress against. The decomposition tells us where to look first the moment data exists — `som_share` and `arpu` — and nothing about what those values actually turn out to be.

### What the model does and does not say

Three threads pull together honestly. First, the financial uncertainty here is not ordinary forecasting noise — it is the propagated uncertainty of a model with **zero observed inputs**, and the p10 tail that breaks the 3× line [C:finance.claim.ltv-cac-band] is the standing reminder that the median case is not the only case. Second, this financial risk *compounds* the wedge risk argued throughout the dissertation: the revenue model implicitly assumes that the metro/agent-state differentiation earns the $1,200 ARPU and 1.18× NRR premiums over the dev-tools benchmark, yet that differentiation is itself capped at supported-by-proxy and carries pending-experimental-validation. Betting ARPU and retention on an unproven wedge adds a layer of risk the Monte-Carlo cannot quantify, because the distributions are drawn from *generic* SaaS benchmarks, not from MetroGraph's unvalidated premium. The model prices the category; it cannot price the bet.

Third, the empty intake — no ARR, no CAC observation, no churn curve, no telemetry — is not a gap to be apologized for but the load-bearing honesty of this chapter. The comps bound an option value; the Monte-Carlo widths report what we don't know; the disputed revenue-multiple band is flagged disputed; and the path to a tighter model is not more assumptions but the first cohort of real customers. What Part X receives is therefore explicitly a band, never a mark: the SOM range ($37.6M–$226.3M, p50 $93.6M), the LTV:CAC distribution (p10 2.56× / p50 8.47× / p90 28.2×), and the comps band (9.5×–37.4×, median 17.5×) — three distributions for the synthesis to render non-divergently into the decision artifacts, each carrying its uncertainty intact.
