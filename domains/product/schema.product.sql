-- product domain — MetroGraph itself, as a corpus. Closes the market "design-targets not measured"
-- gap: turns market.product.us feature claims into spec'd, code-grounded rows with HONEST grading.
-- Repo: github.com/mark1russell7/Graph (Angular + node-server). XREFs market.features by id.
-- `claims` is a BASE table; product adds the per-domain extension tables below.

-- feature_specs — one row per MetroGraph capability, mapped to the canonical market.features taxonomy.
-- grade is honest: 'spec' (from code/docs) or 'pending-experimental' (HCI cost needs a real user study;
-- NEVER 'measured' for a behavioral metric until a primary_studies row exists).
CREATE TABLE IF NOT EXISTS {{schema}}.feature_specs (
  id                 VARCHAR PRIMARY KEY,   -- product.feature.<slug>
  market_feature_id  VARCHAR,               -- XREF market.features.id (the differentiation axis)
  name               VARCHAR NOT NULL,
  status             VARCHAR,               -- shipped | in-progress | planned | design-target
  description        VARCHAR,
  implementation_path VARCHAR,              -- where in the repo it lives
  pane_count_spec    INTEGER,               -- counted from the UI code (spec, not a usability measurement)
  click_depth_spec   INTEGER,
  hci_cost_grade     VARCHAR,               -- A-F design target; honest = a target, not a measured fact
  evidence_grade     VARCHAR,               -- spec | code-measured | pending-experimental
  notes              VARCHAR,
  source_ids         VARCHAR[]
);

-- components — the Angular/service architecture (what builds the product).
CREATE TABLE IF NOT EXISTS {{schema}}.components (
  id            VARCHAR PRIMARY KEY,        -- product.component.<slug>
  name          VARCHAR NOT NULL,
  kind          VARCHAR,                    -- angular-component | service | directive | model | server-route
  path          VARCHAR,
  responsibility VARCHAR,
  feature_ids   VARCHAR[],                  -- product.feature_specs this implements
  depends_on    VARCHAR[],
  loc           INTEGER,
  source_ids    VARCHAR[]
);

-- benchmarks — measurable facts about the product. method is honest about provenance.
CREATE TABLE IF NOT EXISTS {{schema}}.benchmarks (
  id          VARCHAR PRIMARY KEY,          -- product.bench.<slug>
  subject_id  VARCHAR,                      -- feature_spec / flow under measurement
  metric      VARCHAR,                      -- e.g. panes-for-core-task | render-node-budget | bundle-kb
  value       DOUBLE,
  unit        VARCHAR,
  method      VARCHAR,                      -- code-measured | estimated-from-code | pending-experimental
  is_dormant  BOOLEAN,                      -- TRUE = placeholder awaiting a real measurement
  notes       VARCHAR,
  source_ids  VARCHAR[]
);

-- roadmap_items — the build plan. priority is a cited query result (see strategy/roadmap-gtm), not hardcoded.
CREATE TABLE IF NOT EXISTS {{schema}}.roadmap_items (
  id              VARCHAR PRIMARY KEY,      -- product.roadmap.<slug>
  title           VARCHAR NOT NULL,
  category        VARCHAR,                  -- feature | validation-experiment | infra | gtm
  status          VARCHAR,                  -- now | next | later | done
  rationale       VARCHAR,
  cited_claim_ids VARCHAR[],                -- market/hci-evidence claims this is justified by
  depends_on_ids  VARCHAR[],
  effort          VARCHAR,
  source_ids      VARCHAR[]
);
