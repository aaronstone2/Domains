-- ecosystem domain — integration feasibility. Which external systems MetroGraph should connect to first,
-- scored by reach × effort × strategic fit. XREFs market.partners / market.companies / market.features.
-- `claims` is a BASE table; extras below. Feasibility scores are spec-grade (pending-experimental until a
-- real integration ships) — honesty: an "easy integration" claim is design-estimate, not measured.

-- apis — an external system with a public API surface MetroGraph could bind to.
CREATE TABLE IF NOT EXISTS {{schema}}.apis (
  id            VARCHAR PRIMARY KEY,        -- ecosystem.api.<slug>
  company_id    VARCHAR,                    -- XREF market.companies.id
  name          VARCHAR,
  category      VARCHAR,                    -- db | warehouse | auth | workflow | llm | observability | bi
  auth_model    VARCHAR,                    -- oauth2 | api-key | jwt | none | mtls
  protocol      VARCHAR,                    -- rest | graphql | grpc | websocket | sql-wire | sdk
  has_webhooks  BOOLEAN,
  openapi_url   VARCHAR,
  maturity      VARCHAR,                    -- ga | beta | deprecated
  notes         VARCHAR,
  source_ids    VARCHAR[]
);

-- endpoints — a concrete operation on an api that a MetroGraph binding would call.
CREATE TABLE IF NOT EXISTS {{schema}}.endpoints (
  id            VARCHAR PRIMARY KEY,        -- ecosystem.endpoint.<slug>
  api_id        VARCHAR,                    -- XREF ecosystem.apis.id
  method        VARCHAR,                    -- GET | POST | query | subscribe | …
  path          VARCHAR,
  purpose       VARCHAR,                    -- list-schemas | read-rows | stream-changes | introspect | …
  feeds_feature_id VARCHAR,                 -- XREF market.features.id this would power
  source_ids    VARCHAR[]
);

-- integration_points — a scored candidate integration (the deliverable: what to build first).
CREATE TABLE IF NOT EXISTS {{schema}}.integration_points (
  id            VARCHAR PRIMARY KEY,        -- ecosystem.integ.<slug>
  api_id        VARCHAR,
  partner_id    VARCHAR,                    -- XREF market.partners.id (soft)
  feeds_feature_id VARCHAR,                 -- XREF market.features.id
  direction     VARCHAR,                    -- inbound | outbound | bidirectional
  reach_score   DOUBLE,                     -- 0-1 how many ICP users this unlocks
  effort_score  DOUBLE,                     -- 0-1 build effort (higher = harder)
  strategic_fit DOUBLE,                     -- 0-1 fit with the wedge
  priority_score DOUBLE,                    -- derived: reach * fit / effort (recomputed, not hand-set)
  feasibility   VARCHAR,                    -- easy | moderate | hard | blocked
  rationale     VARCHAR,
  source_ids    VARCHAR[]
);
