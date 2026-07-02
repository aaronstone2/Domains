## Appendix C — Glossary

This appendix fixes the controlled vocabulary that runs through every preceding chapter. The dissertation's recurring discipline is that a claim is only as strong as its derived, cross-domain evidence grade, and that the corpus computes and displays that grade rather than asserting a conclusion. That discipline only works if the words are exact: a verdict is not a mood, a ceiling is not a verdict, an evidence grade is not the same as the verdict it informs, and a relationship type is the unit of the algebra from which all three are derived. Each term below is defined as the engine uses it — drawn from the live vocabularies in `meta.all_claims`, `strategy.wedge_reeval`, `v_claim_grade`, and `meta.all_relationships` — with the exemplar claim the body uses to illustrate it.

The glossary is organized in five registers, in the order a single claim flows through them. First comes the **verdict** it carries in its home domain; then the **cross-domain ceiling** that caps how far that verdict may travel once other domains weigh in; then the **evidence grade** that records what kind of support stands behind it; then the **relationship types**, the typed edges from which verdicts and ceilings are computed; and finally the two **honesty primitives**, `pending_experimental` and `is_primary_backed`, the mechanized guards that keep the whole apparatus from inflating itself.

### Verdict vocabulary

A *verdict* is the gold-layer adjudication a claim carries inside its home domain. It is authored or derived once and then retained — refuted and disputed claims are kept in the corpus and reframed, never deleted, because the record of what failed is part of the evidence. The 406 claims in `meta.all_claims` distribute across eight verdict values. The descriptive, evaluative, and predictive cases use lowercase verdicts; a small set of governance and HCI claims use the uppercase `TRUE`/`CONFIRMED` register reserved for facts established by direct inspection or settled law.

| Verdict | Count | What it asserts |
| --- | --- | --- |
| supported | 236 | The evidence on balance backs the claim within its domain; the default for a well-grounded but not directly-measured assertion. |
| speculative | 74 | A forward or inferred claim held open pending evidence; includes engine-derived claims quarantined until verified. |
| refuted | 38 | The evidence on balance overturns the claim; retained as a recorded negative, not erased. |
| disputed | 37 | The evidence is genuinely two-sided; neither support nor refutation dominates. |
| TRUE | 9 | A directly-inspected fact about the product or its legal obligations, true by observation. |
| mixed | 5 | The claim holds under some conditions and fails under others; context decides. |
| CONFIRMED | 4 | A fact confirmed by code/spec inspection or settled regulation; the inspection-grade analogue of TRUE. |
| equivalent | 3 | The two things the claim compares are, on the evidence, on par — neither wins. |

The honesty load these verdicts carry is best seen at the edges. `supported` is real but modest: `market.claim.ai-ui-parity-exclusive-wedge` [C:market.claim.ai-ui-parity-exclusive-wedge] is supported in the market domain on a high pain score and an empty competitor field, but — as the ceiling register below makes precise — supported-in-domain does not survive intact into a cross-domain verdict. `disputed` and `refuted` are retained, not softened: the cloud-data-platform co-GTM thesis is `disputed` [C:market.claim.databricks-snowflake-co-gtm-cloud-data-warehouse-wedge], and the metro-map-as-emerging-pattern aesthetic claim is `refuted` [C:market.claim.wedge-low-surface-area-aesthetic-emerging-pattern]; the body reframes both as hypotheses pending a named experiment rather than upgrading them. `equivalent` marks a genuine tie, as in affordance-visibility being on par with competing determinants of exploration confidence [C:market.claim.affordance-visibility-determines-exploration-confidence]. The uppercase register is reserved for inspection-grade fact: that MetroGraph lacks comprehensive audit logging is `TRUE` by code inspection [C:claim.metro.audit-logging-absent], and that eleven compliance gaps gate enterprise adoption is `CONFIRMED` [C:governance.claim.11-blocking-gaps]. `mixed` covers the context-dependent finding — schematic maps outperform force-directed layouts for some database-exploration tasks but not all [C:hci.claim.schematic-maps-outperform-force-directed-database-exploration].

### Cross-domain ceiling vocabulary

A *cross-domain ceiling* is not a verdict; it is a **derived cap** on how strong a claim is allowed to read once the synthesis layer weighs it against every other domain — market whitespace, the HCI literature floor, the product's shipped reality, customer voice, and competitive erosion. The ceiling lives in `strategy.wedge_reeval`, applies to the thirteen wedge claims, and is computed, never authored. Crucially, it can only ever lower a claim toward honesty; it never raises one. The vocabulary has three values.

| Ceiling | Meaning | Why it is a cap, not a measurement |
| --- | --- | --- |
| supported-by-proxy | Supported by analogy, comparable, or literature transfer — NOT measured on MetroGraph itself. | This is the wedge's hard ceiling. No wedge claim may read stronger than "the literature/comps make this plausible." |
| weak-proxy | Backed only by a distant or thin analogy; the proxy is present but strained. | The proxy exists but transfers weakly; the cap sits below supported-by-proxy. |
| contested | Cross-domain signals actively pull against the claim; competitive erosion or contradiction is live. | The cap reflects open dispute — e.g. dated competitor moves on the same feature. |

The single most important definition in this glossary is **supported-by-proxy**: a claim supported by analogy or transferable literature and explicitly *not* measured on MetroGraph. It is the ceiling of the entire wedge bet. Every one of the thirteen wedge claims tops out here or below, and the dissertation's thesis is precisely that this ceiling is defensible to argue and dishonest to exceed. `contested` is the live-dispute cap, derived from dated competitor moves: the agent-node-type wedge feature is pushed against by twenty dated moves [C:strategy.claim.derived.contested-nodes-agent-type] and the canvas feature by nineteen [C:strategy.claim.derived.contested-canvas]. A schema-first surface-area claim that rests on a design argument rather than a measurement sits at the proxy ceiling as a `speculative` verdict [C:market.claim.schema-first-surface-area-reduction-wedge]. Ceiling and verdict are independent axes: a claim can be `supported` in its home domain yet capped at supported-by-proxy across domains, and that gap is the honesty the corpus exists to display.

### Evidence grades

An *evidence grade* records the kind of support behind a claim — what was actually examined to assert it. The grade is orthogonal to the verdict (you can be `supported` on weak evidence or `refuted` on strong), and it is the input the verification layer uses, alongside the relationship graph, to derive `is_primary_backed`. The corpus carries a long, domain-specific grade vocabulary; the families that matter for reading the body are these.

| Grade family | Example values | What was examined |
| --- | --- | --- |
| code / inspection | `code`, `code-inspection`, `spec`, `source-docs` | The MetroGraph source, schema, or specification, read directly. |
| literature / primary | `literature`, `peer-reviewed`, `RCT`, `controlled-exp`, `primary` | Published, peer-reviewed empirical work — the only path to genuine primary backing in this corpus. |
| analyst / market | `analyst-report`, `market_research`, `market_analysis`, `survey`, `vendor-surveys` | Third-party analyst, survey, or market-sizing material — secondary by construction. |
| changelog / competitive | `changelog-derived`, `industry-signals`, `product_release`, `acquisition`, `license_change` | Dated competitor changelogs and corporate events feeding the erosion layer. |
| modeled / derived | `derived`, `monte-carlo`, `comps-derived`, `technical-feasibility` | Engine-computed: inference rules, Monte-Carlo models, or comps math — provenance-tracked, not observed. |
| review-mining | `review-mining` | Customer reviews mined for voice — a user *said* something (see the primary-backing caveat below). |
| regulatory | `regulatory-current`, `regulatory-pending`, `regulatory-trend`, `established-law` | Statute and enforcement posture, current or anticipated. |

These families map directly onto the trust gradient the dissertation argues from. `code-inspection` and `spec` certify what MetroGraph *is*; `literature`/`primary` certify what the field has *measured elsewhere*; `analyst` and `market_research` size an opportunity without proving a behavior; `changelog-derived` dates a competitor's move; and `derived`/`monte-carlo` mark figures the engine computed from committed assumptions, which is why every financial number is an estimate with a p10/p50/p90 spread rather than a mark.

### Relationship types

A *relationship type* is the label on a typed edge between two corpus entities. The 2,095 edges across 21 types in `meta.all_relationships` are the algebra the synthesis layer reads to derive verdicts, ceilings, and primary backing — the edge, not the claim text, is the computable object. The load-bearing types are these.

| Relationship | Direction / meaning |
| --- | --- |
| grounds / grounded_in | Evidence empirically supports a claim (strongest support edge). |
| grounds_by_proxy / proxy_supported_by | Evidence supports a claim by analogy/transfer — the edge that produces a supported-by-proxy ceiling. |
| weakly_grounds | Support edge of strained transfer — produces a weak-proxy ceiling. |
| empirically_grounded_by / evidenced_by | A claim is attached to a specific study or source as its backing. |
| contradicts | Evidence pulls against a claim (the refutation edge). |
| erodes | A dated competitor move degrades a feature MetroGraph claims (the contested-ceiling driver). |
| gates | A blocker (e.g. a governance gap) conditions a downstream outcome. |
| measures | A product capability or metric measures a feature/claim. |
| benchmarks / competes_with / substitute_for | Comparative edges among products in the competitive set. |
| about_feature / belongs_to_segment / has_product / integrates / satisfies / relieves / threatens_via_feature | Structural and taxonomic edges that wire claims to features, segments, products, and pains. |

The distinction between `grounds` and `grounds_by_proxy` is the whole mechanism in miniature: a `grounds` edge can lift a claim toward primary backing, whereas a `grounds_by_proxy` or `weakly_grounds` edge structurally cannot — it can only ever sustain a proxy ceiling. `erodes` is the competitive-intel edge that fires the contested ceiling, and `gates` is the governance edge that turns a compliance gap into a roadmap blocker.

### The honesty primitives

Two derived flags are the load-bearing guards of the entire corpus, and both are computed, never authored.

**`pending_experimental`** is `TRUE` on all thirteen wedge claims in `strategy.wedge_reeval`. It is the standing marker that no MetroGraph-on-MetroGraph experiment has been run, and it is grounded in fact, not editorial caution: the behavioral-intake tables are empty (`voc.interviews`, `voc.surveys`, `voc.usability_sessions`, and `voc.ab_experiments` all at 0; `market.primary_studies` at 0). The emptiness *is* the pending-experimental signal. Because the flag is true everywhere on the wedge, no wedge claim may be described as validated, measured, proven, or demonstrated on MetroGraph; its ceiling is the cap, and the named pre-registered studies are forward work.

**`is_primary_backed`** is derived from the relationship graph: a claim is primary-backed only if a genuine `grounds`/`empirically_grounded_by` edge attaches it to a primary study, so secondary evidence can never masquerade as primary. In this corpus only HCI (46 of 49) and VoC review-mining (42 of 63) carry any primary backing; market, product, finance, governance, ecosystem, compintel, and strategy are zero primary-backed by construction. Two caveats complete the definition. First, VoC "primary" means *review-mining*: a user **said** something, which is evidence that a pain exists — not evidence that MetroGraph measurably fixes it. Second, primary backing is about the *kind* of evidence, not the *direction* of the verdict: a primary-backed claim can still be `refuted`. Together, `pending_experimental` and `is_primary_backed` are why the dissertation can argue the wedge boldly and still land, honestly, at supported-by-proxy.
