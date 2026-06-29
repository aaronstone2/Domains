## Part V — Product & the Wedge

Part IV left us with a precise, uncomfortable shape: the HCI literature *grounds* the wedge in some places and *contradicts* it in others, and where it grounds, it does so only by proxy — through laboratory tasks on other artifacts, never through MetroGraph itself. That proxy-support is real, but it is a floor, not a verdict. This chapter turns from the literature to the artifact. If the wedge is a bet about how a metro/schematic database visualization with visible agent state will behave in users' hands, the first honest question is not "does the literature agree?" but "does the thing even exist, and which parts of it?" We answer by code inspection — reading the MetroGraph repository and cataloguing what is implemented, what is partial, and what is only specified. The evidence grade for everything here is therefore *capability*, not *efficacy*: code-inspection and spec can tell us a feature is present in the source tree, never that it works well, and certainly never that the wedge effect it is meant to produce is real. Holding that distinction is the whole discipline of the chapter.

### What is actually shipped

The shipped surface is the dashboard-and-canvas core; across the feature taxonomy MetroGraph's status mix is 19 shipped, 6 planned, and 2 in-progress. What works today is a coherent editing surface — an interactive visual canvas with drag/drop layout, a typed node/container system with a creation palette and LeaderLine-rendered edges, a reactive data-binding spine, MongoDB data-source integration with schema introspection, and a multi-viewer properties inspector — sitting atop the two features the wedge leans on directly: a deterministic auto-layout engine built on a recursive rectangle-packing service tuned for 10/100/1000+ node counts [C:product.metrograph.auto-layout-shipped], itself instrumented by a render-time/plot service that tracks render lag and packing time across those scales [C:product.metrograph.render-metrics-shipped]. The table below carries the per-feature inventory; every row's grade is *capability* — present in the source tree — not efficacy.

| Feature (shipped) | Evidence grade | Market feature cell |
| --- | --- | --- |
| Visual Canvas & Editor | code | market.feature.canvas |
| Node System & Types | code | market.feature.nodes |
| Node Creation & Palette | code | market.feature.nodes-creation |
| Edges & Data-Flow Connections | code | market.feature.edges |
| Edge Creation / Connect Nodes | code | market.feature.edges-creation |
| Data Binding & Variable System | code | market.feature.data-binding |
| Data Source Integration | code | market.feature.data-source |
| Schema Introspection & Discovery | code | market.feature.schema-introspection |
| Node Properties / Inspector | code | market.feature.nodes-properties |
| Graph Navigation & Exploration | code | market.feature.graph-exploration |
| Manual Positioning & Snap-to-Grid | code | market.feature.graph-layout-manual |
| Pan, Zoom & Semantic Viewport | code (efficient) | market.feature.canvas-pan-zoom |
| Multi-Selection & Bulk Editing | code-inspection | market.feature.canvas-multi-select |
| Auto-Layout & Rectangle Packing | code-inspection | market.feature.canvas-grouping |

Two shipped items deserve emphasis because the wedge leans directly on them. Auto-layout via rectangle-packing is the closest thing in the current build to the "schematic" half of the metro thesis: deterministic, space-filling, non-overlapping placement — the antithesis of force-directed sprawl. The observability layer is the closest thing to the "visible agent state" half: an execution-logs and step-debugging feature with error tracking and summary visualization [C:claim.metrograph.observability-logs-inprogress], backed by stack-trace visualization, error grouping, and error-summary components [C:product.metrograph.error-logging-shipped]. But note the honest seam: the observability feature is classified *in-progress*, and what actually ships is error/execution logging, not the live agent-orchestration view the wedge ultimately requires.

### What is not shipped, and is wedge-critical

The six planned features and two in-progress ones are precisely the capabilities the bold bet most depends on, and every one carries an evidence grade of `pending-experimental` or sits unactivated in code. Agent and workflow orchestration — the execution engine that would make MetroGraph a control surface for live agents rather than a static graph editor — is *planned*. So is force-directed/organic layout, and so are accessibility (WCAG 2.1 AA), real-time collaboration, git integration with branch/merge, and a keyboard-shortcut/command palette. These are not peripheral polish. Agent orchestration is the entire "visible agent state" proposition; accessibility and keyboard control are the difference between a demo and a tool an analyst lives in all day; and collaboration plus git are table stakes for the enterprise segment the finance and governance chapters scope.

| Feature (not shipped) | Status | Evidence grade | Wedge role |
| --- | --- | --- | --- |
| Agent & Workflow Orchestration | planned | pending-experimental | the "visible agent state" half of the thesis |
| Force-Directed / Organic Layout | planned | pending-experimental | the comparison baseline metro layout must beat |
| Accessibility (WCAG 2.1 AA) | planned | pending-experimental | daily-driver / enterprise gate |
| Real-Time Collaboration | planned | pending-experimental | enterprise table stakes |
| Git Integration & Branch/Merge | planned | pending-experimental | versioning table stakes |
| Keyboard Shortcuts & Command Palette | planned | pending-experimental | power-user efficiency |
| Execution Logs & Step Debugging | in-progress | code | observability spine |
| Visual & Code Query Building | in-progress | code | data-access path |

That `pending-experimental` grade is not an accident of vocabulary. It is the same marker the corpus uses everywhere it has a hypothesis but no measurement, and here it tags the wedge-critical features twice over: they are neither shipped nor studied.

### The product vision: every component a live-editable JSON object

What exists beyond the feature list is an unusually coherent architectural vision, and the wedge's plausibility rests partly on it. The organizing idea is that every component is a live-editable JSON object whose position and size are governed by a signal-aware dimension system; editing the JSON at any level updates state reactively through Angular signals [C:vision-1]. The layout engine is a signal-backed StateService that maps `[entityID][key] → signal(value)`, with a DimensionService lens tracking width/height/top/left for every positioned element so that changes trigger `computed()` consumers and causality effects [C:vision-2]. Editability is declarative: a `ViewerMeta`/`FieldMeta` symbol attached to objects specifies field-level editors (text, number, toggle, select, readonly), and edits are recorded in an EditorService and propagated to parent object state [C:vision-3]. The thirty-component spine is internally consistent and, by the code-inspection grade, real — DashboardComponent at the root viewport, ContainerComponent as the stateful base class, DocumentComponent wrapping JSON objects, ObjectComponent and KeyValueViewerComponent rendering entries, the typed viewers, DragComponent/ResizeComponent wiring CDK gestures into DimensionService, and a CausalityService that uses a DAG to fire effects only after all upstream causes complete. This matters for the wedge because it is the substrate that *could* host the metro layout and the agent view. But the honesty flag stands: a coherent substrate is a capability claim. It says the architecture admits the wedge; it does not say the wedge works.

### Honest in-product gaps

Three gaps are visible in the code itself, and the corpus records them as such. Visual query building is *disputed*: the service infrastructure (MongoService) exists but the UI component is not activated [C:product.metrograph.query-building-partial], and even though the corresponding in-progress feature is recorded as supported at the spec level [C:claim.metrograph.query-building-inprogress], the honest read is partial. Export/download is *speculative-not-found*: no serialization or file-export mechanism appears anywhere in the codebase [C:product.metrograph.export-not-implemented]. Undo/redo is likewise absent, with no history management or transaction-reversal machinery [C:product.metrograph.undo-redo-not-implemented] — notable because the EditorService already records every change with path and previous value, so the substrate for undo exists even though the feature does not. These are reported as findings, not failures; they are the kind of gap that turns directly into roadmap.

### The `measures` edges: product features wired to market pain

The corpus does not leave the product and market chapters disconnected. Twenty-five `measures` edges, each at confidence 0.7, link a product feature node to the market feature-pain cell it is meant to address — `feat.canvas → market.feature.canvas`, `feat.edges → market.feature.edges`, `feat.agent-orchestration → market.feature.agent-orchestration`, `feat.force-layout → market.feature.graph-layout-force-directed`, and so on across the full taxonomy. The uniform 0.7 confidence is itself an honesty signal: it marks a design-time mapping ("this feature is intended to relieve this pain"), not a measured relief. Crucially, the edges run from *planned* features as readily as from shipped ones, so the mapping records intent independent of delivery — which is exactly why the wedge re-evaluation must gate on shipped status rather than on the existence of an edge.

### The wedge re-evaluation: thirteen claims, capped

Here the chapter's argument lands. The strategy layer takes the thirteen wedge claims — each of which entered the corpus with a *market* verdict derived from pure-secondary evidence — and re-grades each against the cross-domain algebra, producing a derived `cross_domain_ceiling` and, for every single one, `pending_experimental = TRUE`. The figure shows the result in full.

![Figure — The 13 wedge claims re-graded against cross-domain evidence. None exceed supported-by-proxy; every one carries pending-experimental-validation, derived from the empty MetroGraph behavioral-data tables.](figures/wedge_ceiling.png)

| Wedge claim | Market verdict | Cross-domain ceiling | Proxy support | Conf. |
| --- | --- | --- | --- | --- |
| agent-observability improves trust [C:market.claim.agent-observability-through-visualization-improves-trust] | disputed | contested | hci:grounds / hci:contradicts | 0.35 |
| AI-UI parity prevents transparency backfire [C:market.claim.mixed-initiative-design-ai-ui-parity-prevents-transparency-backfire] | disputed | contested | hci:grounds / hci:contradicts | 0.35 |
| mixed-initiative requires visualization vs opacity [C:market.claim.mixed-initiative-requires-visualization-to-prevent-agent-opacity] | refuted | contested | hci:grounds / hci:contradicts | 0.35 |
| visual affordances enable interaction without training [C:market.claim.visual-affordances-enable-interaction-without-training] | refuted | contested | hci:grounds / hci:contradicts | 0.35 |
| direct manipulation outperforms conversation [C:market.claim.direct-manipulation-outperforms-conversation-graph-exploration] | refuted | supported-by-proxy | hci:grounds | 0.50 |
| force-directed dominant but unoptimized for schemas [C:market.claim.force-directed-graph-layout-remains-dominant-but-unoptimized-for-schem] | supported | supported-by-proxy | voc:grounds_by_proxy | 0.50 |
| graph-viz clutter at scale [C:market.claim.graph-visualization-clutter-at-scale] | disputed | supported-by-proxy | hci:grounds / voc:weakly_grounds | 0.50 |
| information-foraging predicts metro adoption [C:market.claim.information-foraging-predicts-metro-map-adoption] | refuted | supported-by-proxy | hci:grounds | 0.50 |
| progressive disclosure unlocks schema acquisition [C:market.claim.progressive-disclosure-unlocks-schema-acquisition-in-graphs] | refuted | supported-by-proxy | hci:grounds | 0.50 |
| wayfinding transfers from transit knowledge [C:market.claim.wayfinding-in-schematic-maps-transfers-from-transit-knowledge] | refuted | supported-by-proxy | hci:grounds | 0.50 |
| AI-UI parity is an exclusive wedge [C:market.claim.ai-ui-parity-exclusive-wedge] | supported | weak-proxy | voc:weakly_grounds | 0.30 |
| flight-to-chat when UI confuses [C:market.claim.flight-to-chat-when-ui-confuses-documented] | supported | weak-proxy | voc:weakly_grounds | 0.30 |
| schematic maps outperform force-directed [C:market.claim.schematic-maps-outperform-force-directed-database-exploration] | refuted | weak-proxy | voc:weakly_grounds | 0.30 |

Read the table as the thesis in miniature. Four claims sit at *contested* — the HCI literature both grounds and contradicts them, so the honest ceiling reflects genuine dissent, not endorsement. Six reach *supported-by-proxy*, the highest grade any wedge claim attains; this is the cap, and it means strictly "other work on other artifacts points this way," never "demonstrated on MetroGraph." Three rest at *weak-proxy*, leaning only on review-mining where a user merely *said* something adjacent. The deliberate refusals to inflate are the tell: claims the market chapter marked *supported* — the exclusive-wedge claim and the flight-to-chat claim — are not waved through, because their only backing is weak VoC proxy, so cross-domain grading pulls them down to weak-proxy; and claims marked *refuted* are not deleted but reframed as hypotheses pending a named test. Every row, regardless of ceiling, carries `pending_experimental = TRUE`, because the mechanism that would lift any of them — a behavioral study run on MetroGraph — does not yet exist. Each row also names the specific experiment that would raise it: pre-registered A/Bs of metro vs. force-directed on schema-comprehension and path-finding (n≥40 within-subject), preference/task-success tests of visual vs. chat agent control (n≥40), and usability studies of progressive-disclosure variants (n≥30) — each annotated with the intake table it would land in (`voc.ab_experiments`, `voc.usability_sessions`, `hci.primary_studies`), every one of which is currently empty.

### The dormant benchmarks: emptiness as the marker

That emptiness is not a gap in the writing; it is recorded data. The product layer carries five dormant benchmark rows — click-depth for layout controls, an HCI cost grade for critical features, pane-count cognitive load, user-interaction-without-training success rate, and visual-surface-area reduction — each with `value = null`, `method = pending-experimental`, and `is_dormant = true`. These are the standing pending-experimental marker made concrete: placeholders for measurements not yet taken, not low or zero results. The contrast with what the codebase *can* measure is instructive. MetroGraph already emits code-measured constants — 30 Angular components, 10 production and 11 development dependencies, a 10-level max nesting depth, viewer widths bounded at 20–500px, bundle-size and component-style thresholds — and it carries live-but-unpopulated performance benchmarks (render-lag ratio, resize duration, packing time at 10/100/1000+ nodes). The product can count itself precisely. What it cannot yet do is observe a user. The dormant rows are exactly the variables the wedge's truth depends on, sitting empty, waiting for the named experiments.

### Handoff

This chapter confirms that the artifact admits the wedge — the canvas, the packing engine, the signal-backed JSON substrate, and an observability spine are shipped or coherent in spec — while the wedge-critical capabilities, agent orchestration above all, remain planned, and every one of the thirteen wedge claims is capped at supported-by-proxy or below with a pre-registered experiment named as the only path up. The shipped/planned status is now seeded into the synthesis layer as the gate on what may be recommended. But code inspection answers only the capability question. It cannot tell us whether the pains these features target are pains real users actually feel. That is the question Part VI must take up: do customers, in their own words, corroborate the problems MetroGraph is built to solve — and does the standing emptiness of the VoC intake tables leave even that corroboration at the level of proxy?
