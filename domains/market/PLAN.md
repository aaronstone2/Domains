# Plan -- `market` domain (MetroGraph market-research corpus)

> **Master plan.** The single source for the whole `market` corpus. Per-leaf plans live in each `<leaf>/PLAN.md` (each carries its Session-0 *Leaf spec*); machine-readable phase state in each `<leaf>/STATUS.yaml`; narrative in `PROGRESS.md`. Re-engagement contract: `domains/_shared/sessions/extend-playbook.md`; depth semantics: `.../depth-profiles.md`.

## What this is

An exhaustive, DuckDB-backed **algebra of facts** for the go-to-market of **MetroGraph** -- a metro-map-style database-visualization node/edge graph tool (repo: https://github.com/mark1russell7/Graph/tree/fable; Angular 17 + SignalDB local-first; vision: *every component becomes JSON*). MetroGraph is its OWN product (NOT graph-studio / kraken-unchained). Its wedge: fix the HCI failure of RAG / workflow-graph / agent-builder / low-code tools (surface-area bloat; users fleeing the UI for AI chat = "worst of both worlds"; agent-vs-graph-chat confusion) -- deliver best-of-both AI + UI. The corpus researches the whole competitive/theory landscape, lands it as typed rows (every row cites `source_ids`), adversarially verifies the gold `claims` layer, and **culminates in one rich, fully-cited research paper** (the `market-synthesis` leaf) that serves rigorous report + internal strategy + investor pitch simultaneously.

**Depth:** `exhaustive` on **every** leaf (per directive) -- full multi-hop source sweep + 3-5 adversarial skeptics per decision-grade claim. **Sequencing:** breadth-first (Phase A across all leaves), then deepen B->E in dependency waves.

## Charter -- questions the finished corpus must answer

1. Who are MetroGraph's direct, adjacent/foundational, and wedge-target competitors, and how do the ~158 registry companies cluster across the 11 archetypes (which are direct DB/graph-viz threats vs partnership/ICP-stack adjacencies)?
2. What is the canonical, frozen capability/feature taxonomy for DB & graph visualization tools, and how does every product score on support_level, quality_grade, and HCI cost (A-F) against it?
3. Where is the defensible whitespace — specifically, does any incumbent combine graph/DB-schema visualization + agent-workflow orchestration in a single low-surface-area (metro-map) view, or do they all specialize in graph-viz OR workflow OR schema OR notebooks?
4. How large is the market (TAM/SAM/SOM, CAGR) for DB-visualization aimed at noSQL/SQL startups + data engineers, and which segments score highest on attractiveness (WTP, accessibility, competition density, our_fit)?
5. Who is the ICP (segments + personas), what are their jobs/pains/gains, and which pains does MetroGraph's wedge (low surface area, best-of-both AI+UI, no agent-vs-graph-chat confusion) actually relieve and how strongly?
6. What is MetroGraph's value proposition versus each direct competitor (we_win_on / they_win_on / wedge_vs_them / their moat)?
7. How do competitors price (model types, tiers, free tiers, transparency), and where are the exploitable pricing gaps?
8. What is MetroGraph's Business Model Canvas, and which GTM channels and integration/partnership surfaces (Figma, Google Drive, the graph-DB engines, the modern data stack) should it build?
9. What does an exhaustive UX teardown reveal about the 'endless folders/panes/configs/popups' surface-area bloat (pane counts, click depths, time-to-value, drop-off risk, antipatterns) and the 'flee-to-AI-chat' / agent-vs-graph-chat confusion across the wedge-target categories?
10. What HCI, cognitive-science, graph-visualization, and RAG/agent-UX theory grounds the wedge — i.e., the evidence base for why reduced cognitive load, strong information scent, direct manipulation, metro-map metaphor, and copilot-first hybrid interaction win?
11. Which strategic, competitive, and demand claims survive adversarial verification (supported vs disputed vs refuted), with explicit theory grounding and recorded nuance, so the synthesis paper never over-flattens a contested verdict?

## The algebra of facts (`schema.market.sql`)

21 extension tables on the 7 base tables. Layers: **entity spine** (`companies`, `funding_rounds`, `products`, `people`(stub), `competitors`, `partners`) - **capability matrix** (`features`, `product_features`) - **VPC** (`segments`, `personas`, `jobs_pains_gains`) - **business model** (`pricing_models`, `pricing_tiers`, `bmc_blocks`) - **UX teardown** (`ux_screens`, `ux_flows`, `ux_patterns` -- image PATH refs, never blobs) - **theory** (`theory_concepts`) - **gold** (`claims`, `reports`, `market_metrics`). IDs: `market.<entity>.<slug>`; our own rows use reserved `market.company.us` / `market.product.us` + `is_self=TRUE`. `hci_cost` grades A-F where **A = lowest friction (best)**.

## Tier rubric (domain-relative evidence grade in `sources.tier`)

Two sub-rubrics because the corpus mixes empirical theory with live-product intel:

| Tier | Theory leaves | Market / competitive leaves |
|---|---|---|
| **T0** | meta-analysis / systematic review (HCI) | primary capture -- live competitor screens (Playwright), pricing snapshots, filings, funding-DB records |
| **T1** | peer-reviewed (CHI/UIST/TOCHI) | official product docs / changelogs / API docs |
| **T2** | textbook / seminal author (Shneiderman, Norman, Pirolli) | analyst reports (Gartner/Forrester/a16z/CB Insights) + review aggregates (G2/Capterra) |
| **T3** | high-quality practitioner essay | listicles / "alternatives-to" / HN / Reddit |

License discipline: analyst PDFs + product UIs = `reference-only` (metadata + paraphrase + screenshot path, never republish); CC/academic OA = `redistribute-ok`.

## Leaf tree (73 leaves, all exhaustive)

### spine (1)
- **`companies`** -- Insert exactly one row per registry org (~158) + the MetroGraph self-row (is_self=TRUE); funding rounds + people stubs.  
  tables: companies, funding_rounds, people - deps: (wave 1)

### market (3)
- **`market-landscape`** -- FREEZE the canonical feature taxonomy (capability areas → sub-features, categories, layers, pain_score, kano_class, hci_relevance); define the 11-archetype map.  
  tables: features, product_features, concepts - deps: (wave 1)
- **`market-sizing`** -- TAM/SAM/SOM + CAGR for DB-viz / graph-viz / data-engineer tooling, top-down and bottom-up, per whole-market and per-archetype.  
  tables: market_metrics, reports, segments - deps: companies, market-landscape
- **`market-trends`** -- Cross-cutting trend signals: AI-native convergence, agentic 2026, consolidation (dbt+Fivetran), viz-only underfunding, graph-adoption friction.  
  tables: market_metrics, claims, concepts - deps: companies, market-landscape, market-sizing

### competitive (24)
- **`competitors-graph-db-viz-native`** -- DB-bundled/embedded graph explorers: Neo4j Bloom, Memgraph Lab, Kuzu Explorer, gDotV, NebulaGraph Explorer, SemSpect.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-graph-db-viz-platforms`** -- DB-agnostic enterprise platforms + commercial toolkits: Linkurious, Graphistry, GraphAware Hume, Kineviz GraphXR, Tom Sawyer, Cambridge Intelligence (KeyLines/ReGraph), yWorks (yFiles/yEd), Gephi, Graphileon, Graphlytic.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-db-schema-modeling-visual`** -- Visual/cloud/live-DB ERD tools (direct ICP rivals): Azimutt, ChartDB, dbdiagram.io, DrawSQL, DbSchema, Prisma Studio, ER Flow.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-db-schema-modeling-dev`** -- Developer/enterprise modelers + DB-IDE ERD: Vertabelo, SqlDBM, QuickDBD, ERDPlus, pgModeler, DBeaver EER.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-node-graph-libs-rendering`** -- Graph/node rendering libraries (foundation peers, not product rivals): React Flow/xyflow, D3.js, Cytoscape.js, Sigma.js, vis.js, react-force-graph, Cosmograph.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-node-graph-libs-editors`** -- Node-editor frameworks + graph-DB-specific libs: AntV G6, Rete.js, Reaflow, Baklavajs, Neovis.js, Popoto.js, NetworkX.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-graph-databases-leading`** -- Leading property/graph engines (adjacency + partnership surface): Neo4j, TigerGraph, Memgraph, ArangoDB, Kuzu, FalkorDB.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-graph-databases-emerging`** -- Emerging / zero-ETL / multi-model engines: Grafeo, PuppyGraph, NebulaGraph, ArcadeDB, HugeGraph, BigQuery Graph.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-workflow-automation-ipaas`** -- Mainstream node-based iPaaS (canonical surface-area-bloat set): Zapier, Make, n8n, Workato, Tray.ai, Pipedream.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-workflow-automation-oss`** -- OSS / Microsoft / embedded / flow-based automation: Activepieces, Power Automate, Node-RED, Prismatic, Windmill, Latenode.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-rag-agent-builders-canvas`** -- Visual canvas RAG/agent builders (named wedge: agent-vs-graph-chat confusion): Flowise, Langflow, Dify, Gumloop, Rivet, BuildShip, MindStudio, RAGFlow, Mastra, AnythingLLM.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-rag-agent-builders-conversational`** -- Conversational / enterprise / NL-first agent builders: Voiceflow, Coze, Wordware, Lindy, Airia, Botpress, Rasa, Copilot Studio, Vertex AI Agent Builder, Relay.app.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-internal-tools-lowcode`** -- Low-code internal-tool builders (config-sprawl wedge target): Retool, Appsmith, ToolJet, Budibase, Superblocks, UI Bakery, Illa, Lowdefy, Refine, NocoBase.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-lowcode-app-platforms`** -- Low-code/no-code app & web platforms: Mendix, OutSystems, PowerApps, Bubble, Webflow, Xano, GrapesJS, Creatio.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-nocode-databases`** -- No-code database/spreadsheet frontends (ICP-adjacent data frontends over SQL/noSQL): Airtable, NocoDB, Teable, Baserow, Grist, Knack, Smartsheet.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-data-bi-dashboards`** -- BI dashboard/analytics platforms (data-engineer ICP consumption layer): Metabase, Superset, Tableau, Power BI, Looker, Grafana, Redash, QuickSight, OBIEE.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-data-notebooks-ai`** -- Notebooks + AI-native + lightweight data studios (AI+UI convergence signal): Hex, Observable, Google Sheets, Databox, Knowi, Basedash, Tictable, Index, Jupyter.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-diagramming-as-code`** -- Diagram-as-code + ERD/graph-capable diagrammers: Mermaid, Graphviz, PlantUML, D2, Lucidchart, draw.io, Creately, Penrose, Visio.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-diagramming-whiteboard`** -- Collaborative whiteboards + AI diagram tools (Figma = INTEGRATION PARTNER, flag relevant_to_us): Miro, Figma/FigJam, Excalidraw, tldraw, Whimsical, Napkin, Qlerify, Mural, MockFlow.  
  tables: products, product_features, competitors, partners - deps: companies, market-landscape
- **`competitors-data-etl-ingestion`** -- ETL/ELT ingestion + visual ELT + agentic migration: Fivetran, Airbyte, Talend, Matillion, Coalesce, dltHub, Bruin, Rubie.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-data-transformation-quality`** -- Transformation (lineage DAG viz) + data quality/observability: dbt, SQLMesh, Dataform, Great Expectations, Soda, Elementary, Monte Carlo, Databand.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-data-orchestration-modern`** -- Modern data orchestrators with DAG/graph views: Airflow, Dagster, Prefect, Mage, Kestra, Astronomer, Orchestra.  
  tables: products, product_features, competitors - deps: companies, market-landscape
- **`competitors-workflow-engines`** -- General workflow/durable-execution engines (context only): Luigi, Kedro, Apache Beam, Temporal, Conductor, Camunda, Argo Workflows.  
  tables: products, competitors - deps: companies, market-landscape
- **`competitors-data-warehouse-lakehouse`** -- Warehouse/lakehouse platform context for the ICP stack: Databricks, Snowflake, ClickHouse, Dremio.  
  tables: products, competitors, companies - deps: companies, market-landscape

### customers (1)
- **`customer-segments`** -- FREEZE segment.id (noSQL/SQL startups, data engineers, analysts, etc.); personas + the VPC customer profile (jobs/pains/gains) with severity/importance/relief.  
  tables: segments, personas, jobs_pains_gains - deps: companies

### vpc (1)
- **`value-prop`** -- MetroGraph value-map: pain relievers / gain creators / products-and-services mapped to frozen jobs/pains/gains; per-competitor we_win_on differentiation; whitespace claim.  
  tables: jobs_pains_gains, relationships, claims - deps: customer-segments, market-landscape, competitors-graph-db-viz-native, competitors-graph-db-viz-platforms, competitors-db-schema-modeling-visual, ux-teardown-graph-db-viz, theory-metro-map-metaphor, theory-visual-programming-dataflow, theory-hybrid-multimodal-interfaces

### business-model (1)
- **`business-model`** -- MetroGraph's 9-block Business Model Canvas (+ optionally key competitors' BMCs), linking segments/features/partners/pricing tiers.  
  tables: bmc_blocks, claims - deps: customer-segments, value-prop, pricing, partners-integrations

### pricing (1)
- **`pricing`** -- Pricing models + tier ladders for all priced products (reads product.id across competitor leaves); pricing-gap analysis vs MetroGraph.  
  tables: pricing_models, pricing_tiers, claims - deps: companies, market-landscape, competitors-graph-db-viz-native, competitors-db-schema-modeling-visual, competitors-workflow-automation-ipaas, competitors-internal-tools-lowcode

### partners (1)
- **`partners-integrations`** -- MetroGraph's integration surface (Figma, Google Drive, graph-DB engines, modern data stack) + competitors' ecosystems; relevant_to_us flagging.  
  tables: partners, relationships, claims - deps: companies

### theory (29)
- **`theory-cognitive-load`** -- Cognitive Load Theory (Sweller/Ayres/Kalyuga): intrinsic/extraneous/germane load; absorbs progressive disclosure + information architecture as applied CLT.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-working-memory`** -- Working-memory capacity limits (Miller 7±2; Cowan 3-5); hard bound on simultaneous visible controls.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-information-foraging`** -- Information Foraging Theory (Pirolli & Card): information scent, patch/diet models — why poor cues drive flight to chat.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-recognition-recall`** -- Recognition vs recall (Nielsen heuristic #6): visible options cheaper than hidden commands.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-choice-cost`** -- Cost of choices: Hick-Hyman law (RT=a+b·log2 n) + Paradox of Choice / decision fatigue (Schwartz).  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-perception-gestalt`** -- Visual perception: Gestalt grouping, preattentive processing (Treisman), graphical-perception effectiveness (Cleveland & McGill).  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-direct-manipulation`** -- Direct-manipulation foundations (Shneiderman 1983): continuous representation, physical reversible actions, immediate feedback; absorbs reversibility/undo.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-norman-gulfs-distance`** -- Norman's gulfs of execution/evaluation, affordances/signifiers, + Hutchins semantic/articulatory distance.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-instrumental-interaction`** -- Beaudouin-Lafon post-WIMP instrumental interaction (reification, polymorphism, reuse, currying) + AI-Instruments.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-mixed-initiative`** -- Mixed-initiative interaction (Horvitz 1999, 12 principles) + control allocation, autonomy levels, mode switching.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-dm-vs-agents-debate`** -- Shneiderman-Maes debate (DM vs intelligent agents) + modern prompt-vs-direct-manipulation + copilot-vs-autonomous-agent distinctions.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-tangible-embodied`** -- Tangible & embodied interaction (Ishii/Ullmer): spatial metaphor, physicality — grounds metro-map 'substance' of nodes.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-conversational-ui-challenges`** -- Conversational UI limitations: ambiguity, context, intent recognition — why pure chat fails for structured tasks.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-nl-interfaces-structured-data`** -- NL→structured-output (NL2SQL/NL2VIS): ambiguity resolution, DataTone, pragmatics, interactive disambiguation.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-hybrid-multimodal-interfaces`** -- Hybrid NL + direct-manipulation / multimodal interfaces (Graphologue, LLM-GUI architectures) — the space MetroGraph occupies.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-graph-layout-algorithms`** -- Graph layout: force-directed (Eades, Fruchterman-Reingold), hierarchical (Sugiyama), tree (Reingold-Tilford), orthogonal/octilinear.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-graph-aesthetics-readability`** -- Graph aesthetics & readability: crossing minimization, symmetry, edge density, empirical cognitive-load studies (Huang, Kobourov).  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-infovis-framework-methodology`** -- InfoVis design methodology: Munzner nested model, Shneiderman mantra, Cleveland-McGill encoding hierarchy.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-metro-map-metaphor`** -- Metro-map metaphor for abstract data: octilinear schematic layout, MetroSets, applications to software/pathways/concepts.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-database-schema-visualization`** -- DB schema & ERD visualization theory: Chen ER model, relational/noSQL/graph schema representation, large-schema complexity.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-visual-programming-dataflow`** -- Visual/dataflow programming + the Deutsch limit (~50 primitives), end-user programming, why node-canvas builders hit a complexity ceiling.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-interactive-graph-exploration`** -- Interactive graph exploration & sensemaking: pan/zoom/filter, focus+context, brushing, visual query builders, large-network interaction.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-human-ai-interaction-design`** -- Guidelines for Human-AI Interaction (Amershi et al. CHI 2019, 18 principles) + design-pattern catalogs.  
  tables: theory_concepts, claims, relationships - deps: (wave 1)
- **`theory-agentic-ux-patterns`** -- Agentic UX patterns: interruptibility, step-by-step logs, approve/veto, control handoff for autonomous agents.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-trust-explainability`** -- Trust, explainability & transparency in AI UIs; absorbs RAG-UX (showing retrieval context) and model-card documentation.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-agent-observability-workflow`** -- Visualizing agent workflows/observability: DAG/Sankey overlays, per-step latency, human-in-the-loop interruption points.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-mental-models-ai-expertise`** -- User mental models of AI; expert/novice gap; when LLM assistants fail and who blames the UI.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-user-agency-control`** -- Locus of control, sense of agency, user-control vs autonomy preferences/personalization in autonomous systems.  
  tables: theory_concepts, claims - deps: (wave 1)
- **`theory-error-recovery-correction`** -- Error detection/recovery & correction loops: over-reliance vs over-intervention, before/after visibility, persuasion paradox.  
  tables: theory_concepts, claims - deps: (wave 1)

### ux (10)
- **`ux-teardown-graph-db-viz`** -- Deep flows (<=5) on the direct set: Neo4j Bloom, Linkurious, Kineviz GraphXR, Memgraph Lab, Gephi — pane_count/click_depth/hci_cost.  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-graph-db-viz-native, competitors-graph-db-viz-platforms, market-landscape
- **`ux-teardown-db-schema-modeling`** -- <=5 flows on Azimutt, ChartDB, dbdiagram.io, DbSchema, Prisma Studio (live-DB connect → first ERD).  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-db-schema-modeling-visual, competitors-db-schema-modeling-dev, market-landscape
- **`ux-teardown-node-graph-libraries`** -- <=5 flows on canonical demo apps: React Flow, Cytoscape.js, Sigma.js, AntV G6, Rete.js.  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-node-graph-libs-rendering, competitors-node-graph-libs-editors, market-landscape
- **`ux-teardown-graph-databases`** -- <=5 flows on bundled UIs: Neo4j Browser, Memgraph, TigerGraph, NebulaGraph, PuppyGraph (query-to-viz).  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-graph-databases-leading, competitors-graph-databases-emerging, market-landscape
- **`ux-teardown-workflow-automation`** -- <=5 flows on Zapier, Make, n8n, Node-RED, Latenode (build-first-workflow) — canonical pane-bloat evidence.  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-workflow-automation-ipaas, competitors-workflow-automation-oss, market-landscape
- **`ux-teardown-rag-agent-builders`** -- <=5 flows on Flowise, Langflow, Dify, Gumloop, Coze — agent-vs-graph-chat confusion documented.  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-rag-agent-builders-canvas, competitors-rag-agent-builders-conversational, market-landscape
- **`ux-teardown-internal-tools-lowcode`** -- <=5 flows on Retool, Appsmith, Budibase, Airtable, NocoDB (config sprawl + data-frontend).  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-internal-tools-lowcode, competitors-lowcode-app-platforms, competitors-nocode-databases, market-landscape
- **`ux-teardown-data-bi-notebook`** -- <=5 flows on Metabase, Superset, Hex, Tableau, Grafana (query/explore-to-dashboard).  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-data-bi-dashboards, competitors-data-notebooks-ai, market-landscape
- **`ux-teardown-diagramming`** -- <=5 flows on Lucidchart, draw.io, Miro, Figma/FigJam, Mermaid (ERD/graph render) — Figma flow as partner-embed study.  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-diagramming-as-code, competitors-diagramming-whiteboard, market-landscape
- **`ux-teardown-data-orchestration`** -- <=5 flows on Airflow, Dagster, dbt Explorer, Prefect, Coalesce (DAG/lineage graph views).  
  tables: ux_screens, ux_flows, ux_patterns - deps: competitors-data-orchestration-modern, competitors-data-transformation-quality, competitors-data-etl-ingestion, market-landscape

### synthesis (1)
- **`market-synthesis`** -- The fully-cited research paper: whitespace thesis, segment attractiveness, differentiation, pricing gaps, theory-grounded wedge — reads all claims, writes zero.  
  tables: reports, relationships, concepts - deps: value-prop, business-model, market-trends, market-sizing, pricing, ux-teardown-graph-db-viz, ux-teardown-rag-agent-builders, theory-metro-map-metaphor, theory-visual-programming-dataflow, theory-hybrid-multimodal-interfaces

## Cross-leaf contracts

> Resolved in Session 0. **C1 refined** (Aaron, 2026-06-25) for continuous company discovery.

- **[C1-company-id-freeze]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.
- **[C2-self-rows]** MetroGraph's own company + product rows use the reserved ids `market.company.us` / `market.product.us` with is_self=TRUE, written by `companies` and `value-prop` respectively; every us-vs-them query is a self-join on is_self.
- **[C3-feature-taxonomy-freeze]** The `market-landscape` leaf is the sole writer of {{schema}}.features and freezes the feature taxonomy (ids `market.feature.<slug>`, hierarchy, category, layer, kano_class) BEFORE any product_features are written. Competitor + teardown leaves reference feature.id read-only when scoring product_features (deterministic id `market.pf.<product-slug>.<feature-slug>`).
- **[C4-product-id-partition]** product.id is partitioned by archetype: each competitor leaf owns the products rows for exactly its assigned companies (`market.product.<slug>`) and is their only writer; no other leaf inserts products for those companies, so product PKs never collide across parallel writers.
- **[C5-claims-partition-paper-readonly]** {{schema}}.claims is partitioned per leaf by claim-id NAMESPACE (each leaf writes only ids under its declared prefix, e.g. `market.claim.comp.gdbv-native.*`) AND by the controlled category vocab it is allowed to emit. `market-synthesis` (paper) is READ-ONLY on claims and must never re-flatten or overwrite a verdict (conflation guard).
- **[C6-reports-first-writer-wins]** {{schema}}.reports is keyed by source_id (= sources.id); whichever leaf first ingests a source owns its report row (first-writer-wins on upsert). Every number in market-sizing/trends/pricing resolves to a reports or market_metrics row.
- **[C7-segment-id-freeze]** The `customer-segments` leaf is the sole writer of {{schema}}.segments and freezes segment.id (`market.segment.<slug>`); personas, jobs_pains_gains, pricing_tiers, and bmc_blocks reference segment.id read-only.
- **[C8-vpc-ownership-split]** `customer-segments` owns the VPC customer-profile side (personas + jobs_pains_gains for the market ICP). `value-prop` owns the value-map side: it sets our_relief/relief_strength/addressed_by_feature_ids on existing jpg rows and writes the relief/differentiation relationships — the two leaves never write the same column of the same row.
- **[C9-pricing-ownership]** The `pricing` leaf is the sole writer of {{schema}}.pricing_models and {{schema}}.pricing_tiers, referencing product.id/company.id read-only; it runs after all competitor leaves so every priced product exists.
- **[C10-partners-ownership]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.
- **[C11-competitor-role-overlay]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.
- **[C12-ux-evidence-linkage]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.
- **[C13-theory-grounding]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.
- **[C14-relationship-edges]** The `companies` leaf is the canonical writer + first sweeper of {{schema}}.companies / {{schema}}.funding_rounds and defines the id convention `market.company.<slug>`. **Company discovery is CONTINUOUS, not gated:** because slugs are deterministic (same canonical name -> same id, no PK collision), ANY leaf that discovers a new company during its exhaustive sweep MAY append a stub row (id + name + url + source_ids). The `companies` leaf OWNS enrichment + dedup/canonicalization (funding, hq, aliases); it does NOT gatekeep existence. So the corpus grows unbounded as each leaf runs -- the Session-0 registry (~182) is a floor, not a ceiling.

## Breadth-first dependency waves

- **Wave 1** (31): companies, market-landscape, theory-cognitive-load, theory-working-memory, theory-information-foraging, theory-recognition-recall, theory-choice-cost, theory-perception-gestalt, theory-direct-manipulation, theory-norman-gulfs-distance, theory-instrumental-interaction, theory-mixed-initiative, theory-dm-vs-agents-debate, theory-tangible-embodied, theory-conversational-ui-challenges, theory-nl-interfaces-structured-data, theory-hybrid-multimodal-interfaces, theory-graph-layout-algorithms, theory-graph-aesthetics-readability, theory-infovis-framework-methodology, theory-metro-map-metaphor, theory-database-schema-visualization, theory-visual-programming-dataflow, theory-interactive-graph-exploration, theory-human-ai-interaction-design, theory-agentic-ux-patterns, theory-trust-explainability, theory-agent-observability-workflow, theory-mental-models-ai-expertise, theory-user-agency-control, theory-error-recovery-correction
- **Wave 2** (27): competitors-graph-db-viz-native, competitors-graph-db-viz-platforms, competitors-db-schema-modeling-visual, competitors-db-schema-modeling-dev, competitors-node-graph-libs-rendering, competitors-node-graph-libs-editors, competitors-graph-databases-leading, competitors-graph-databases-emerging, competitors-workflow-automation-ipaas, competitors-workflow-automation-oss, competitors-rag-agent-builders-canvas, competitors-rag-agent-builders-conversational, competitors-internal-tools-lowcode, competitors-lowcode-app-platforms, competitors-nocode-databases, competitors-data-bi-dashboards, competitors-data-notebooks-ai, competitors-diagramming-as-code, competitors-diagramming-whiteboard, competitors-data-etl-ingestion, competitors-data-transformation-quality, competitors-data-orchestration-modern, competitors-workflow-engines, competitors-data-warehouse-lakehouse, customer-segments, market-sizing, partners-integrations
- **Wave 3** (12): ux-teardown-graph-db-viz, ux-teardown-db-schema-modeling, ux-teardown-node-graph-libraries, ux-teardown-graph-databases, ux-teardown-workflow-automation, ux-teardown-rag-agent-builders, ux-teardown-internal-tools-lowcode, ux-teardown-data-bi-notebook, ux-teardown-diagramming, ux-teardown-data-orchestration, pricing, market-trends
- **Wave 4** (1): value-prop
- **Wave 5** (1): business-model
- **Wave 6** (1): market-synthesis

## Acceptance tests

1. Coverage: every org in the master registry (~158) plus the MetroGraph self-row resolves to exactly one {{schema}}.companies row; COUNT(is_self)=1; no company appears in two competitor leaves' product sets.
2. Product-id partition (C4): zero product.id collisions; every {{schema}}.products row's company_id resolves to a companies.id; each competitor leaf's product count <= 10.
3. Feature-freeze ordering (C3): every product_features.feature_id and jpg.addressed_by_feature_ids and theory.applies_to_feature_ids resolves to a features.id written by market-landscape; no product_features row predates the frozen taxonomy.
4. Claims partition (C5): every claim.category is in the controlled vocab; every claim.id falls under its writing leaf's declared namespace prefix; no two leaves share a claim-id prefix; market-synthesis wrote zero claim rows.
5. Direct-competitor completeness: every is_direct_competitor company has a competitors row with non-empty we_win_on, they_win_on, wedge_vs_them, and >=1 product_features scorecard row with an hci_cost grade.
6. Teardown caps (C12): each ux-teardown leaf has <= 5 ux_flows; every ux_screen carries pane_count, click_depth and an hci_cost A-F grade; each teardown flags >=1 is_antipattern ux_pattern; any product_features.ux_screen_ids resolve to ux_screens written by the matching teardown.
7. Theory grounding (C13): every theory leaf produced theory_concepts with implication + strength populated; every claim.theory_concept_ids resolves; the six core cognitive/viz theories each ground >=1 strategic claim.
8. Reports first-writer-wins (C6): reports PK is unique on source_id; every numeric assertion in market-sizing, market-trends, and pricing resolves to a reports or market_metrics row with a source.
9. Segment-freeze (C7): customer-segments is the only writer of segments; every persona.segment_id, jpg.segment_id, pricing_tier.target_persona_id/segment link, and bmc linked_segment_ids resolves.
10. Whitespace claim exists: value-prop emits the headline supported/disputed claim that no incumbent combines graph/DB-schema viz + agent-workflow orchestration in a single low-surface-area view, grounded in >=1 theory concept and citing >=3 competitor leaves.
11. Synthesis integrity: market-synthesis writes only reports + synthesis relationships; every assertion in the paper cites a claim.id, and no claim verdict is re-flattened (conflation guard holds).
12. Acyclic waves: no leaf depends on a leaf in an equal-or-later wave; wave 1 has zero dependencies; the dependency graph is a DAG terminating at market-synthesis.

## Session-0 registry snapshot (seed, not ceiling)

- **182 companies** card-sorted into **10 archetypes** (see `_scope/registry.json`); 29 flagged direct competitors. Per C1 this grows unbounded as leaves run.

Archetypes: `graph-db-visualization` (19), `db-schema-modeling` (13), `node-graph-libraries` (14), `graph-databases` (12), `workflow-automation` (12), `rag-agent-builders` (20), `internal-tools-lowcode` (25), `data-bi-notebook` (18), `diagramming` (18), `data-orchestration` (34)

**Validated pain themes** (evidence for the wedge):
- UI surface-area bloat & feature sprawl: endless folders/panes/configs/popups, widget overload, 'extremely basic'/'90s movie' interfaces, cognitive overload from low-value features (Retool, UiPath, LaunchDarkly, general SaaS). MetroGraph's core wedge.
- Steep learning curve & config complexity in visual/low-code builders: confusing node setup, inadequate JS env, nested conditions/retries/fallbacks pile up; 'mental model takes too long' (n8n, Zapier, Make, OutSystems, Blue Prism, Weaviate modules, Milvus).
- Complexity ceiling with no escape hatch: visual builders break when real-world complexity emerges; ~10% of edge cases force users to JS/code hacks; 'hard stop' beyond the toolkit.
- Users fleeing the UI for AI chat ('worst of both worlds'): no-code handles the easy 90%, hard cases go to ChatGPT/Claude; apps must meet users inside their AI environment. The category splits into fixed-sequence builders vs. personal AI assistants.
- Agent-vs-UI confusion & agent feature creep: agents bolted onto every platform (30+ Slackbot features), unclear when to use agent vs UI; MCP/context bloat (7 servers = 33.7% of context window; 8k+ tokens before the user speaks).
- Tool sprawl, fragmentation & vendor lock-in: 5-10 tools per data pipeline; ~$18k/employee in unused licenses; 50%+ orgs consolidating; lock-in (Bubble no source export, ArangoDB Apache→BSL license shift) and costly migrations.

## Execution mechanics & gotchas

- **Scaffolding:** `pnpm leaf add market/<leaf>`. GOTCHA (learned this session): leaf names fed from a Python-written file on Windows carry a trailing `\r` that fails the name regex -- strip with `tr -d '\r'`; and use a `for` loop, not `while read < file`.
- **init-db** auto-discovers the domain, applies `schema.market.sql`, regenerates `_shared/queries/cross_domain.sql` (`meta.*`) + `fts_index.sql` -- both AUTO-GENERATED, do not hand-edit.
- **Ingest:** `ingest fetch` stages JSONL (no lock); `ingest load` needs the lock (close motherduck MCP first); base `load` only handles `sources`/`documents` -- **extension tables load via the `duckdb` CLI** (`read_json_auto` + `INSERT BY NAME`/`ON CONFLICT`). DuckDB CLI is a Windows binary: feed SQL via stdin (`duckdb db < file.sql`) and use `C:/...` paths, not MSYS `/c/...`. FK gotcha: replacing a parent `sources` row trips the `documents` FK -- delete child rows first.
- **Scratch hygiene:** raw under `_db/raw/market/...` (gitignored); Session-0 artifacts under `domains/market/_scope/`.

## Artifacts

- `_scope/registry.json` -- company registry + archetypes + pain themes + dropped
- `_scope/theory-decomposition.json` -- the theory areas -> sub-leaves
- `_scope/leaf-tree.json` -- the full leaf tree (depth-overridden to exhaustive)
