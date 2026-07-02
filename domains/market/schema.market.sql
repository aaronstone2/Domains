-- Per-domain schema extension for `market`, applied by `ingest init-db` on top of the
-- shared base schema (sources, documents, concepts, commands, config_keys, failure_modes,
-- relationships). Uses the same {{schema}} placeholder substituted with the domain name.
--
-- These tables turn the corpus into a queryable "algebra of facts" for market research:
-- the company/product universe, a competitor capability matrix, the Value Proposition Canvas
-- (segments/personas/jobs-pains-gains), pricing + the Business Model Canvas, an exhaustive UX
-- teardown of existing products (screens/flows/patterns), an HCI/graph/RAG theory grounding
-- layer, and the adversarially-verified evidence layer (claims + reports). Querying it derives
-- strategy (whitespace, segment attractiveness, differentiation, pricing gaps) and generates a
-- fully-cited research paper.
--
-- OUR product is MetroGraph (github.com/mark1russell7/Graph, `fable` branch) — a metro-map-style
-- DB-visualization graph tool. Our own rows live in `companies`/`products` under the reserved
-- `…company.us` / `…product.us` ids with is_self = TRUE, so every differentiation / pricing / UX
-- query is just a self-join split on is_self (us-vs-them for free). MetroGraph is its own product
-- (NOT graph-studio, NOT kraken-unchained).
--
-- Conventions (mirroring exercise): VARCHAR PKs with a namespaced id `market.<entity>.<slug>`
-- (kebab-case); cross-table references are soft (plain VARCHAR / VARCHAR[], NOT declared FKs —
-- exercise does the same to avoid the FK/INSERT-OR-REPLACE upsert gotcha); STRUCT(...)[] for
-- sub-records; every entity row carries source_ids VARCHAR[] for citation. Tiers in
-- {{schema}}.sources double as an evidence grade (domain-relative; see PLAN.md). Cross-entity
-- edges live in {{schema}}.relationships (rel_type: has_product | acquired_by | competes_with |
-- partners_with | integrates_with | invested_in | substitute_for | belongs_to_segment |
-- grounded_in | evidenced_by ...).

-- ══════════════════════════════════════════════════════ ENTITY SPINE

-- ─────────────────────────────────────────────────────────── companies
-- EVERY org discovered gets a row: competitors, partners, customers, adjacents, investors,
-- acquirers. Facts live here ONCE; roles (competitor/partner) are classified in their own tables.
CREATE TABLE IF NOT EXISTS {{schema}}.companies (
  id              VARCHAR PRIMARY KEY,           -- market.company.retool | market.company.us (reserved = MetroGraph)
  name            VARCHAR NOT NULL,
  slug            VARCHAR,
  aliases         VARCHAR[],
  is_self         BOOLEAN,                       -- TRUE only for our own company row (MetroGraph)
  category        VARCHAR,                       -- rag | workflow-graph | agent-builder | ipaas | low-code | db-client | bi | etl | orchestration | design-tool | db-viz | graph-diagramming
  subcategories   VARCHAR[],
  description     VARCHAR,
  founded_year    INTEGER,
  hq_country      VARCHAR,
  hq_city         VARCHAR,
  employee_count  INTEGER,                       -- point estimate
  employee_range  VARCHAR,                       -- '11-50' | '51-200' | '201-500' ...
  ownership       VARCHAR,                       -- private | public | acquired | open-source-project | nonprofit
  stock_ticker    VARCHAR,
  status          VARCHAR,                       -- active | acquired | defunct | stealth
  acquired_by_id  VARCHAR,                       -- companies.id (nullable)
  -- funding summary (per-round detail lives in funding_rounds)
  total_funding_usd  DOUBLE,
  last_round_stage   VARCHAR,                    -- pre-seed | seed | series-a..f | growth | ipo | bootstrapped
  last_round_usd     DOUBLE,
  last_round_date    DATE,
  valuation_usd      DOUBLE,
  key_investors      VARCHAR[],
  -- urls / traction signals
  homepage_url    VARCHAR,
  docs_url        VARCHAR,
  pricing_url     VARCHAR,
  crunchbase_url  VARCHAR,
  linkedin_url    VARCHAR,
  github_url      VARCHAR,
  github_stars    INTEGER,                       -- OSS traction proxy
  -- positioning
  business_model  VARCHAR,                       -- saas | open-core | self-host | usage-based | services
  target_market   VARCHAR[],
  tagline         VARCHAR,
  notes           VARCHAR,
  source_ids      VARCHAR[]
);

-- ─────────────────────────────────────────────────── funding rounds (detail)
CREATE TABLE IF NOT EXISTS {{schema}}.funding_rounds (
  id            VARCHAR PRIMARY KEY,             -- market.round.retool-series-c
  company_id    VARCHAR NOT NULL,                -- companies.id
  stage         VARCHAR,                         -- seed | series-a..f | growth | ipo | grant
  amount_usd    DOUBLE,
  round_date    DATE,
  valuation_usd DOUBLE,
  lead_investor VARCHAR,
  investors     VARCHAR[],
  notes         VARCHAR,
  source_ids    VARCHAR[]
);

-- ──────────────────────────────────────────────── products (company 1→many)
CREATE TABLE IF NOT EXISTS {{schema}}.products (
  id                VARCHAR PRIMARY KEY,         -- market.product.n8n | market.product.us (MetroGraph)
  company_id        VARCHAR NOT NULL,            -- companies.id
  name              VARCHAR NOT NULL,
  slug              VARCHAR,
  aliases           VARCHAR[],
  is_self           BOOLEAN,
  category          VARCHAR,                     -- per-product (same vocab as companies.category)
  archetype         VARCHAR,                     -- emergent cluster from Session-0 card-sort (e.g. rag-agent-builders, workflow-automation, db-viz-modeling)
  product_type      VARCHAR,                     -- platform | feature | plugin | library | service
  description       VARCHAR,
  positioning       VARCHAR,
  target_user       VARCHAR,
  status            VARCHAR,                     -- ga | beta | deprecated | discontinued
  launched_year     INTEGER,
  primary_use_cases VARCHAR[],
  tech_stack        VARCHAR[],                   -- react-flow | d3 | cytoscape | sigma.js | proprietary
  deployment        VARCHAR[],                   -- cloud | self-host | desktop | hybrid
  open_source       BOOLEAN,
  license           VARCHAR,
  platforms         VARCHAR[],                   -- web | desktop | cli | vscode | mobile
  homepage_url      VARCHAR,
  docs_url          VARCHAR,
  demo_url          VARCHAR,
  notes             VARCHAR,
  source_ids        VARCHAR[]
);

-- ───────────────────────────────── people (STUB — designed now, populated later)
CREATE TABLE IF NOT EXISTS {{schema}}.people (
  id              VARCHAR PRIMARY KEY,           -- market.person.david-hsu
  company_id      VARCHAR,                       -- companies.id
  name            VARCHAR NOT NULL,
  role            VARCHAR,                       -- founder | ceo | cto | head-of-design | pm | investor | ic
  title           VARCHAR,
  seniority       VARCHAR,                       -- c-level | vp | director | senior | staff | ...
  linkedin_url    VARCHAR,
  twitter_url     VARCHAR,
  bio             VARCHAR,
  focus_areas     VARCHAR[],
  prior_companies VARCHAR[],
  notes           VARCHAR,
  source_ids      VARCHAR[]
);

-- ───────────────────── competitors (ROLE overlay on companies/products — no dup facts)
-- A single company can carry both a competitors row AND partners rows (coopetition, e.g. Figma).
CREATE TABLE IF NOT EXISTS {{schema}}.competitors (
  id               VARCHAR PRIMARY KEY,          -- market.competitor.retool
  company_id       VARCHAR NOT NULL,             -- companies.id
  product_id       VARCHAR,                      -- products.id (specific competing product, optional)
  competitor_type  VARCHAR,                      -- direct | indirect | adjacent | substitute | aspirational | legacy-incumbent
  threat_level     VARCHAR,                      -- low | medium | high
  overlap_area     VARCHAR[],                    -- jobs/feature areas of overlap
  they_win_on      VARCHAR[],                    -- feature_ids/dimensions where they beat us
  we_win_on        VARCHAR[],                    -- dimensions where MetroGraph beats them
  wedge_vs_them    VARCHAR,                      -- our specific wedge against this competitor
  moat             VARCHAR,                      -- their defensibility
  positioning_note VARCHAR,
  source_ids       VARCHAR[]
);

-- ─────────────────────── partners / integrations (our ecosystem AND competitors')
-- for_company_id = whose ecosystem (us, or a competitor); partner_company_id = the partner org.
CREATE TABLE IF NOT EXISTS {{schema}}.partners (
  id                 VARCHAR PRIMARY KEY,        -- market.partner.us-figma
  for_company_id     VARCHAR NOT NULL,           -- companies.id (us, or a competitor)
  for_product_id     VARCHAR,                    -- products.id (optional)
  partner_company_id VARCHAR,                    -- companies.id (the partner, if it has a row)
  partner_name       VARCHAR,                    -- denormalized if no company row
  partner_type       VARCHAR,                    -- integration | channel | tech | data | reseller | design | infra
  integration_kind   VARCHAR,                    -- import | export | embed | api | oauth | webhook | plugin | sync
  direction          VARCHAR,                    -- inbound | outbound | bidirectional
  maturity           VARCHAR,                    -- native | planned | community | api-only | rumored
  strategic_value    VARCHAR,                    -- low | medium | high
  relevant_to_us     BOOLEAN,                    -- TRUE = an integration MetroGraph should build (e.g. Figma, Google Drive)
  description        VARCHAR,
  source_ids         VARCHAR[]
);

-- ══════════════════════════════════════════════════════ CAPABILITY MATRIX

-- ─────────────────────────────────────────────────── feature taxonomy
-- The canonical capability vocabulary. Frozen by the market-landscape leaf (cross-leaf
-- contract C3); every competitor + teardown leaf scores product_features against THIS vocab.
CREATE TABLE IF NOT EXISTS {{schema}}.features (
  id                VARCHAR PRIMARY KEY,         -- market.feature.canvas-pan-zoom
  name              VARCHAR NOT NULL,
  parent_feature_id VARCHAR,                     -- self-ref hierarchy (capability area → sub-feature)
  category          VARCHAR,                     -- canvas | nodes | edges | data-binding | ai-assist | collaboration | versioning | deploy | observability | auth | extensibility | onboarding | import-export
  layer             VARCHAR,                     -- core | integration | ai | ux-chrome
  description       VARCHAR,
  why_it_matters    VARCHAR,
  customer_pain     VARCHAR,                     -- none | low | medium | high | critical (pain when absent/poor)
  pain_score        DOUBLE,                      -- 0..1 numeric (drives whitespace ranking) — from review/survey evidence
  kano_class        VARCHAR,                     -- basic | performance | delighter | indifferent
  hci_relevance     VARCHAR,                     -- low | medium | high (does HCI cost concentrate here?)
  is_table_stakes   BOOLEAN,
  demand_evidence   VARCHAR,                     -- where the pain signal comes from
  source_ids        VARCHAR[]
);

-- ───────────────────────── product × feature matrix (the scorecard)
-- Deterministic id `market.pf.<product-slug>.<feature-slug>` enforces one row per matrix
-- coordinate (no separate UNIQUE needed; matches exercise's deterministic-PK idempotency).
CREATE TABLE IF NOT EXISTS {{schema}}.product_features (
  id            VARCHAR PRIMARY KEY,             -- market.pf.retool.canvas-pan-zoom
  product_id    VARCHAR NOT NULL,                -- products.id
  feature_id    VARCHAR NOT NULL,                -- features.id
  support_level VARCHAR,                         -- none | partial | full | native | beta | via-plugin | via-workaround
  quality_grade VARCHAR,                         -- A | B | C | D | F (how well executed)
  hci_cost      VARCHAR,                         -- A | B | C | D | F  (A = LOWEST friction/best; F = highest). NOTE: inverted from the word "cost".
  hci_cost_note VARCHAR,                         -- e.g. 'buried 3 panes deep, 6 clicks'
  ux_screen_ids VARCHAR[],                       -- evidence screenshots (ux_screens.id)
  maturity      VARCHAR,
  notes         VARCHAR,
  source_ids    VARCHAR[]
);

-- ══════════════════════════════════════════════════════ VALUE PROP CANVAS

-- ─────────────────────────────────────────────────────────── segments
CREATE TABLE IF NOT EXISTS {{schema}}.segments (
  id                  VARCHAR PRIMARY KEY,       -- market.segment.data-engineers
  name                VARCHAR NOT NULL,
  description         VARCHAR,
  segment_type        VARCHAR,                   -- vertical | role | company-size | use-case
  size_usd            DOUBLE,                    -- TAM/SAM dollar value for this segment
  size_count          INTEGER,                   -- # of orgs/users
  growth_rate         DOUBLE,                    -- CAGR (0..1)
  willingness_to_pay  VARCHAR,                   -- low | medium | high
  accessibility       VARCHAR,                   -- GTM reachability
  competition_density VARCHAR,                   -- low | medium | high
  our_fit             VARCHAR,                   -- low | medium | high
  attractiveness      DOUBLE,                    -- 0..1 curated composite (also computed in queries)
  priority            VARCHAR,                   -- beachhead | expansion | ignore
  notes               VARCHAR,
  source_ids          VARCHAR[]
);

-- ─────────────────────────────────────────────────────────── personas
CREATE TABLE IF NOT EXISTS {{schema}}.personas (
  id              VARCHAR PRIMARY KEY,           -- market.persona.staff-data-engineer
  segment_id      VARCHAR,                       -- segments.id
  name            VARCHAR NOT NULL,
  role_title      VARCHAR,
  description     VARCHAR,
  goals           VARCHAR[],
  tools_used      VARCHAR[],                     -- current stack (incumbent-displacement map)
  technical_level VARCHAR,
  buying_power    VARCHAR,                       -- user | influencer | economic-buyer
  where_they_hang VARCHAR[],                     -- channels (for GTM)
  quote           VARCHAR,                       -- representative voice-of-customer
  source_ids      VARCHAR[]
);

-- ───────────────────────────── jobs / pains / gains (VPC customer profile)
CREATE TABLE IF NOT EXISTS {{schema}}.jobs_pains_gains (
  id                       VARCHAR PRIMARY KEY,  -- market.jpg.config-sprawl-pain
  kind                     VARCHAR NOT NULL,     -- job | pain | gain
  persona_id               VARCHAR,              -- personas.id (nullable)
  segment_id               VARCHAR,              -- segments.id (nullable; invariant: >=1 of persona/segment set)
  statement                VARCHAR NOT NULL,
  job_type                 VARCHAR,              -- functional | emotional | social (when kind=job)
  severity                 VARCHAR,              -- pain: low | medium | high | critical
  frequency                VARCHAR,              -- rare | occasional | frequent | constant
  importance               DOUBLE,              -- 0..1
  our_relief               VARCHAR,              -- how MetroGraph relieves the pain / creates the gain
  relief_strength          VARCHAR,              -- none | weak | moderate | strong
  addressed_by_feature_ids VARCHAR[],            -- features.id (traceability to roadmap)
  current_alternative      VARCHAR,              -- how they cope today
  evidence_grade           VARCHAR,              -- survey | interview | review-mining | analyst | anecdote
  source_ids               VARCHAR[]
);

-- ══════════════════════════════════════════════════════ BUSINESS MODEL

-- ─────────────────────────────────────────────────── pricing models
CREATE TABLE IF NOT EXISTS {{schema}}.pricing_models (
  id                VARCHAR PRIMARY KEY,         -- market.pricing-model.retool
  company_id        VARCHAR,                     -- companies.id
  product_id        VARCHAR,                     -- products.id (preferred when known)
  model_type        VARCHAR,                     -- seat-based | usage-based | flat | freemium | open-core | tiered | hybrid
  billing_units     VARCHAR[],                   -- per-seat | per-app | per-run | per-row | per-compute
  has_free_tier     BOOLEAN,
  free_tier_note    VARCHAR,
  free_trial_days   INTEGER,
  enterprise_custom BOOLEAN,                     -- "contact us" tier exists
  currency          VARCHAR,
  transparency      VARCHAR,                     -- public | partial | quote-only
  pricing_page_url  VARCHAR,
  notes             VARCHAR,
  source_ids        VARCHAR[]
);

-- ─────────────────────────────────────────────────── pricing tiers
CREATE TABLE IF NOT EXISTS {{schema}}.pricing_tiers (
  id                VARCHAR PRIMARY KEY,         -- market.pricing-tier.retool-team
  pricing_model_id  VARCHAR,                     -- pricing_models.id
  product_id        VARCHAR,                     -- products.id
  company_id        VARCHAR,                     -- companies.id
  tier_name         VARCHAR NOT NULL,            -- Free | Starter | Team | Business | Enterprise
  tier_order        INTEGER,                     -- 0,1,2... ladder ordering
  price             DOUBLE,                      -- NULL = custom/quote
  unit              VARCHAR,                     -- per-user/month | per-month | per-run
  billing_period    VARCHAR,                     -- monthly | annual
  min_seats         INTEGER,
  included          VARCHAR[],                   -- headline inclusions
  limits            STRUCT(metric VARCHAR, value VARCHAR)[],  -- quota caps
  target_persona_id VARCHAR,                     -- personas.id
  target_persona    VARCHAR,                     -- denormalized label
  is_most_popular   BOOLEAN,
  notes             VARCHAR,
  source_ids        VARCHAR[]
);

-- ───────────────────── Business Model Canvas (9 blocks — MetroGraph, cited)
-- subject_company_id defaults to us; allows authoring a competitor's BMC too.
CREATE TABLE IF NOT EXISTS {{schema}}.bmc_blocks (
  id                 VARCHAR PRIMARY KEY,        -- market.bmc.value-propositions
  block              VARCHAR NOT NULL,           -- customer-segments | value-propositions | channels | customer-relationships | revenue-streams | key-resources | key-activities | key-partnerships | cost-structure
  subject_company_id VARCHAR,                    -- companies.id (default = us)
  title              VARCHAR,
  items              STRUCT(item VARCHAR, detail VARCHAR, confidence VARCHAR, source_ids VARCHAR[])[],
  linked_segment_ids      VARCHAR[],
  linked_feature_ids      VARCHAR[],
  linked_partner_ids      VARCHAR[],
  linked_pricing_tier_ids VARCHAR[],
  narrative          VARCHAR,
  source_ids         VARCHAR[]
);

-- ══════════════════════════════════════════════════════ UX TEARDOWN
-- Captured exhaustively from existing products (ours added later). Images live as files under
-- the leaf's extract/screens/<product>/ — store PATH refs here, never blobs in DuckDB.

-- ─────────────────────────────────────────────────── UI screens
CREATE TABLE IF NOT EXISTS {{schema}}.ux_screens (
  id                VARCHAR PRIMARY KEY,         -- market.screen.retool.app-editor-canvas
  product_id        VARCHAR NOT NULL,            -- products.id
  screen_name       VARCHAR NOT NULL,
  screen_type       VARCHAR,                     -- canvas | dashboard | settings | modal | onboarding | empty-state | wizard | inspector-pane
  image_path        VARCHAR,                     -- repo-relative: domains/market/ux-teardown-<archetype>/extract/screens/<product>/<slug>.png
  image_sha         VARCHAR,                     -- dedupe / integrity
  captured_from_url VARCHAR,
  description       VARCHAR,
  ui_elements       VARCHAR[],                   -- panes/popups/toolbars present
  pane_count        INTEGER,                     -- HCI surface-area metric (the "endless panes" thesis)
  click_depth       INTEGER,                     -- how deep this screen sits in nav
  annotations       STRUCT(region VARCHAR, note VARCHAR, kind VARCHAR)[],  -- kind: friction | delight | pattern
  feature_ids       VARCHAR[],                   -- features.id visible/exercised here
  hci_cost          VARCHAR,                     -- A..F friction grade for this screen
  source_id         VARCHAR,                     -- primary provenance
  source_ids        VARCHAR[]
);

-- ─────────────────────────────────────────────────── user flows
CREATE TABLE IF NOT EXISTS {{schema}}.ux_flows (
  id            VARCHAR PRIMARY KEY,             -- market.flow.n8n.build-first-workflow
  product_id    VARCHAR NOT NULL,                -- products.id
  flow_name     VARCHAR NOT NULL,
  goal          VARCHAR,                         -- the job this flow accomplishes
  job_id        VARCHAR,                         -- jobs_pains_gains.id
  entry_point   VARCHAR,
  steps         STRUCT(step INTEGER, action VARCHAR, screen_id VARCHAR, clicks INTEGER, friction VARCHAR, note VARCHAR)[],
  total_steps   INTEGER,
  total_clicks  INTEGER,                         -- friction quantum for time-to-value queries
  time_estimate VARCHAR,
  pain_points   VARCHAR[],
  drop_off_risk VARCHAR,                         -- low | medium | high
  hci_cost      VARCHAR,                         -- A..F overall
  our_approach  VARCHAR,                         -- how MetroGraph would do this flow better (best-of-both wedge)
  source_ids    VARCHAR[]
);

-- ─────────────────────────────────────────────────── reusable UI/UX patterns
CREATE TABLE IF NOT EXISTS {{schema}}.ux_patterns (
  id                   VARCHAR PRIMARY KEY,      -- market.pattern.left-rail-config-tree
  pattern              VARCHAR NOT NULL,
  category             VARCHAR,                  -- navigation | config | canvas-interaction | ai-entry | data-binding | empty-state | onboarding
  description          VARCHAR,
  exemplar_product_ids VARCHAR[],                -- products.id using it
  exemplar_screen_ids  VARCHAR[],                -- ux_screens.id
  prevalence           DOUBLE,                   -- 0..1 (also computed in queries)
  hci_cost             VARCHAR,                  -- A..F: is the pattern cheap or expensive for users
  is_antipattern       BOOLEAN,                  -- the "worst of both worlds" catalog
  our_stance           VARCHAR,                  -- adopt | avoid | reinvent | conditional
  our_rationale        VARCHAR,
  source_ids           VARCHAR[]
);

-- ══════════════════════════════════════════════════════ THEORY
-- HCI / graph-viz / RAG-UX grounding. Expected large (multi-leaf cluster). Theory-backed
-- assertions also flow into claims (category = theory | hci).
CREATE TABLE IF NOT EXISTS {{schema}}.theory_concepts (
  id                     VARCHAR PRIMARY KEY,    -- market.theory.fitts-law
  concept                VARCHAR NOT NULL,
  field                  VARCHAR,                -- hci | cognitive-psych | graph-theory | rag | information-foraging | interaction-design | visualization | visual-programming
  definition             VARCHAR,
  key_refs               VARCHAR[],              -- canonical citations (also captured as source_ids)
  implication            VARCHAR,                -- what it implies for MetroGraph's design
  strength               VARCHAR,                -- established-law | empirical | framework | hypothesis
  applies_to_feature_ids VARCHAR[],              -- features.id
  applies_to_pattern_ids VARCHAR[],              -- ux_patterns.id
  related_concept_ids    VARCHAR[],              -- self-ref
  source_ids             VARCHAR[]
);

-- ══════════════════════════════════════════════════════ GOLD LAYER

-- ───────────────────────── adversarially-verified claims (mirrors exercise.claims)
-- category is a controlled vocab PARTITIONED PER LEAF (cross-leaf contract C4) so parallel
-- writers never collide on PKs. `paper` is read-only on this table and must never re-flatten a
-- verdict (the conflation guard).
-- claims is now a BASE table (domains/_shared/schema.sql). market adds one grounding extra.
-- (category vocab for market: market | competition | pricing | ux | hci | theory | segment | demand | feature | gtm | funding | integration)
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS theory_concept_ids VARCHAR[];  -- grounding (powers the theory-grounding-of-claims query)

-- ───────────────── reports: analyst / survey / G2 / case-study (mirrors exercise.studies)
-- source_id is the PK → first-writer-wins on upsert. The place every NUMBER in the paper resolves to.
CREATE TABLE IF NOT EXISTS {{schema}}.reports (
  source_id           VARCHAR PRIMARY KEY,       -- FK-style to {{schema}}.sources.id
  report_type         VARCHAR,                   -- analyst | survey | g2-reviews | case-study | benchmark | market-sizing | earnings | blog-teardown
  publisher           VARCHAR,                   -- Gartner | Forrester | G2 | a16z | CB-Insights | self ...
  methodology         VARCHAR,
  sample_size         INTEGER,
  population          VARCHAR,
  geography           VARCHAR,
  period              VARCHAR,                   -- time window covered
  subject_company_ids VARCHAR[],
  subject_product_ids VARCHAR[],
  key_finding         VARCHAR,
  metrics             STRUCT(metric VARCHAR, value VARCHAR, unit VARCHAR)[],
  ratings             STRUCT(product_id VARCHAR, score DOUBLE, scale VARCHAR, n_reviews INTEGER)[],  -- G2-style
  market_size_usd     DOUBLE,
  cagr                DOUBLE,
  citation            VARCHAR,
  url                 VARCHAR,
  notes               VARCHAR
);

-- ───────────────── market_metrics: quantitative facts not owned by one entity
-- TAM/SAM/SOM, CAGR, adoption, aggregate funding — keeps the paper's sizing section queryable.
CREATE TABLE IF NOT EXISTS {{schema}}.market_metrics (
  id           VARCHAR PRIMARY KEY,              -- market.metric.db-viz-tam-2025
  metric       VARCHAR NOT NULL,                 -- tam | sam | som | cagr | adoption-rate | nps | churn | arr | seat-count
  subject_kind VARCHAR,                          -- market | segment | company | product | category
  subject_id   VARCHAR,                          -- id of the subject (nullable for whole-market)
  value        DOUBLE,
  unit         VARCHAR,                          -- usd | percent | count | usd-per-year
  as_of        DATE,
  geography    VARCHAR,
  basis        VARCHAR,                          -- top-down | bottom-up | analyst
  confidence   DOUBLE,
  source_ids   VARCHAR[]
);
