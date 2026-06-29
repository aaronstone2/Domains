## Part I — Thesis & Epistemic Stance

This dissertation argues for a product, and the first thing it owes the reader is a confession about what kind of argument it is allowed to make. MetroGraph is a bet. The corpus assembled around it — 406 claims drawn from 4,436 sources and wired together by 2,095 typed relationships across nine domains — does not exist to prove the bet correct. It exists to compute, and then display, exactly how strong the bet is currently entitled to be called, and to hold that ceiling against every temptation to round it up. The thesis is therefore double: MetroGraph's wedge is *defensible-in-hypothesis*, and it is *capped at supported-by-proxy*. These two statements are not in tension; they are the same honest finding stated from two sides.

### What MetroGraph is, and what the bet is

MetroGraph is a metro-map-style database-visualization tool: a node-and-edge graph canvas that renders a database the way a transit map renders a city, with schematic, legible lines instead of the organic tangle of a force-directed layout. It is built on Angular 17 with SignalDB, a reactive local-first store, and its longer vision is a data-defined UI in which every component becomes live-editable JSON — an interface you can reshape from inside itself.

The bet — the *wedge* — is a claim about a specific gap: that there is room for a tool genuinely best-of-both on AI and UI at once, with a surface area small enough to learn without training, that never makes the user wonder whether they are talking to the agent or to the graph. The failure mode it is designed against is concrete and documented in the market corpus as the "flight to chat": when a direct-manipulation UI confuses people, they retreat to the conversational interface and the visualization's advantage evaporates [C:market.claim.flight-to-chat-when-ui-confuses-documented]. MetroGraph's pitch is that visible agent state plus a schematic, manipulable canvas resolves that confusion rather than papering over it.

That is the bet. It is attractive, it is specific, and — this is the entire point of the corpus — it is, as of this writing, unproven on MetroGraph itself. The product is pre-revenue. It carries no behavioral telemetry. Not one of its users has been run through a controlled task. Everything that follows is an attempt to say as much as can honestly be said in that condition, and not one word more.

### The epistemic contract

The corpus enforces a single contract that every chapter inherits: **a claim is only as strong as its derived, cross-domain evidence grade, and the corpus's job is to compute and display that grade rather than to assert a conclusion.** Three commitments make the contract real rather than rhetorical.

First, *verdicts are reported exactly as the gold layer records them*, across the full spectrum from supported through refuted; the synthesis never upgrades a refuted or disputed claim into a supported one to make the story flow. Second, *evidence grades are derived, not authored* — the flag for whether a claim is primary-backed is computed from the evidence junction, so secondary evidence cannot be dressed up as primary, and a claim that is merely "supported-by-proxy" cannot quietly present itself as measured. Third, and most distinctively, *dissent is retained, not deleted*: a claim the evidence refutes is not removed but kept and reframed as a hypothesis awaiting a named experiment. The corpus would be smaller and more flattering if it threw its losers away. It keeps them on purpose, because a strategy that has hidden its own counter-evidence cannot be audited.

The verdict vocabulary the chapters speak in is therefore wide. Across the 406 claims, the gold layer distributes as follows.

| Verdict | Claims | Reading |
| --- | ---: | --- |
| supported | 236 | Evidence backs the claim (mostly by secondary proxy; only HCI and VoC carry any primary backing) |
| speculative | 74 | Inferred or quarantined; awaits verification |
| refuted | 38 | Evidence contradicts the claim — retained as a hypothesis |
| disputed | 37 | Evidence cuts both ways |
| TRUE / CONFIRMED | 13 | Governance facts about the shipped product's gaps |
| mixed | 5 | HCI findings that depend on the task |
| equivalent | 3 | Market comparisons that wash out |

![Figure — The gold layer is honest about dissent: 406 claims span supported through refuted. Refuted/disputed claims are retained and reframed as hypotheses, not deleted.](figures/verdict_distribution.png)

The figure above is not a scorecard of wins; read it as the shape of an honest argument. Seventy-five of the 406 claims are refuted or disputed and *still in the corpus*, each one a place where the evidence pushed back and was allowed to. A document that wanted only to sell would show a verdict distribution that was almost all green. This one does not, and that is the feature.

### The central honesty mechanism: the derived ceiling

The wedge is not one claim but thirteen, collected in the `strategy.wedge_reeval` layer. Each began life as a market claim with a verdict assigned by the market corpus on the strength of secondary literature. The synthesis layer then does something the market corpus could not: it re-grades each wedge claim against *cross-domain* evidence — what the HCI literature grounds or contradicts, what the Voice-of-Customer review-mining weakly grounds — and assigns a **derived cross-domain ceiling**, the cap on how strong the claim is allowed to be called. That ceiling takes one of three values: `supported-by-proxy`, `weak-proxy`, or `contested`.

The word *derived* is load-bearing. The ceiling is computed from the evidence edges, not chosen by the author, and it can sit *below* the market verdict. The keystone claim — that AI-UI parity is an exclusive, defensible position — is the cleanest illustration. The market corpus rated it **supported**, but on pure secondary evidence with no primary study behind it. Re-graded across domains, its only cross-domain attachment is a weak grounding from VoC review-mining, so its derived ceiling falls to **weak-proxy** [C:market.claim.ai-ui-parity-exclusive-wedge]. A reader who saw only the market verdict would walk away with "supported"; the honest, derived answer is "weak-proxy." That gap — between what a single domain will say in isolation and what the cross-domain algebra will certify — is the machine the whole dissertation is built to run.

Crucially, **no wedge claim's ceiling reaches "supported," and none reaches anything experimental.** The very best a wedge claim achieves is *supported-by-proxy*: the surrounding literature backs the underlying principle, but no study has tested that principle *on MetroGraph*. The thirteen claims fall out as follows.

| Wedge claim | Market verdict | Derived ceiling | Conf. |
| --- | --- | --- | ---: |
| ai-ui-parity-exclusive-wedge | supported | weak-proxy | 0.30 |
| flight-to-chat-when-ui-confuses-documented | supported | weak-proxy | 0.30 |
| schematic-maps-outperform-force-directed-db-exploration | refuted | weak-proxy | 0.30 |
| direct-manipulation-outperforms-conversation-graph-exploration | refuted | supported-by-proxy | 0.50 |
| force-directed-dominant-but-unoptimized-for-schematic | supported | supported-by-proxy | 0.50 |
| graph-visualization-clutter-at-scale | disputed | supported-by-proxy | 0.50 |
| information-foraging-predicts-metro-map-adoption | refuted | supported-by-proxy | 0.50 |
| progressive-disclosure-unlocks-schema-acquisition | refuted | supported-by-proxy | 0.50 |
| wayfinding-in-schematic-maps-transfers-from-transit | refuted | supported-by-proxy | 0.50 |
| agent-observability-through-visualization-improves-trust | disputed | contested | 0.35 |
| mixed-initiative-parity-prevents-transparency-backfire | disputed | contested | 0.35 |
| mixed-initiative-requires-visualization-to-prevent-opacity | refuted | contested | 0.35 |
| visual-affordances-enable-interaction-without-training | refuted | contested | 0.35 |

![Figure — The 13 wedge claims re-graded against cross-domain evidence. None exceed supported-by-proxy; every one carries pending-experimental-validation, derived from the empty MetroGraph behavioral-data tables.](figures/wedge_ceiling.png)

Three of these claims deserve naming now, because later chapters return to each. The claim that schematic maps outperform force-directed layouts for database exploration — intuitively the most central thing MetroGraph is betting on — carries a market verdict of **refuted** and a derived ceiling of only **weak-proxy**, grounded weakly by VoC and nothing more [C:market.claim.schematic-maps-outperform-force-directed-database-exploration]. The claim that direct manipulation beats conversation for graph exploration is also **refuted** at the market level, though cross-domain grounding from HCI lifts its ceiling to **supported-by-proxy** [C:market.claim.direct-manipulation-outperforms-conversation-graph-exploration]. And the claim that agent observability through visualization improves trust is **disputed**, landing at **contested**, because the HCI literature both grounds *and* contradicts it [C:market.claim.agent-observability-through-visualization-improves-trust]. These are not failures of the project; they are the corpus doing its job, refusing to let an appealing hypothesis cash itself as a result.

### Why every wedge claim is pending-experimental

One flag attaches to every single one of the thirteen wedge claims, regardless of verdict or ceiling: `pending_experimental = TRUE`. The reason is structural, and it is the honest center of the document. A grade can never climb above its derived ceiling because **the experiment that would lift it has not been run** — and we know it has not been run because the tables it would land in are empty. The MetroGraph behavioral-intake tables — `voc.interviews`, `voc.surveys`, `voc.usability_sessions`, `voc.ab_experiments` — hold zero rows, and `market.primary_studies` holds zero rows. That emptiness is not an oversight to apologize for; it *is the marker*. The corpus reads the absence of a study as the standing, mechanized statement "this has not been tested on MetroGraph," and stamps it onto every wedge claim automatically. The path upward is therefore not more argument but the specific, pre-registered experiments named against each claim — controlled A/Bs of schematic versus force-directed layout, preference-and-task tests of visual versus conversational agent control, usability studies of progressive disclosure — each with a target sample size and a destination table that is, today, empty.

The companion to the wedge is a set of nine derived strategy claims, each marked **speculative** and quarantined, that record where the competitive-intelligence layer sees a wedge feature being eroded: the canvas contested by 19 dated competitor moves [C:strategy.claim.derived.contested-canvas], agent orchestration by 11 [C:strategy.claim.derived.contested-agent-orchestration], the agent-typed nodes by 20 [C:strategy.claim.derived.contested-nodes-agent-type]. These are inferences the engine *derived* and then deliberately refused to promote until verified — part of the same discipline: a machine-generated claim does not get to count as evidence simply because the machine generated it.

### The self-referential stance, and the road ahead

One last thing must be said plainly, because it shapes how the rest should be read. This is a strategy *about* MetroGraph, produced *by* an engine that MetroGraph's own owner built. The obvious failure mode of any founder's strategy document is that it launders the founder's optimism into the appearance of evidence. The engine is built to resist exactly that — its author. The derived-ceiling rule, the unauthored primary-backing flag, the retention of refuted claims, the empty-table marker that no amount of conviction can fill: each is a constraint the author imposed on the author. Whether it fully succeeds is itself a question the limitations chapter will hold to account. But the intent is on the record from the first page.

The chapters that follow are successive evidence passes over these same thirteen claims, each tightening the verdict and none permitted to inflate it. Part II explains *how* the grades are computed — the relationship algebra, the verification standards, the derivation of primary backing — satisfying the natural appetite this chapter is meant to leave. From there the wedge is weighed against market whitespace, against the HCI literature floor that both grounds and contradicts it, against the shipped reality of the product, against the customer voice that is mostly an absence, and against the competitive erosion eating at its features. The arc lands where the contract forces it to land: the ceiling is supported-by-proxy, the empty intake tables are the standing pending-experimental marker, and the only honest way up is the named roadmap of pre-registered studies — carried as forward work, never reported as done.
