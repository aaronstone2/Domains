-- compintel domain — live competitive intelligence. Time-stamped competitor moves (changelog/pricing/
-- hiring/funding signals) that exercise the temporal layer and feed the strategy red-team's falsifiers.
-- XREFs market.companies/products/features. `claims` is a BASE table; extras below.

-- intel_snapshots — a captured competitor surface at a point in time (the temporal anchor).
CREATE TABLE IF NOT EXISTS {{schema}}.intel_snapshots (
  id          VARCHAR PRIMARY KEY,        -- compintel.snap.<company>.<date>.<kind>
  company_id  VARCHAR,                    -- XREF market.companies.id
  kind        VARCHAR,                    -- changelog | pricing | homepage | docs | jobs
  captured_at DATE,
  summary     VARCHAR,
  url         VARCHAR,
  source_ids  VARCHAR[]
);

-- changes — a discrete observed competitor move, dated. affects_wedge flags wedge-relevant moves.
CREATE TABLE IF NOT EXISTS {{schema}}.changes (
  id            VARCHAR PRIMARY KEY,       -- compintel.change.<slug>
  company_id    VARCHAR,
  product_id    VARCHAR,
  change_type   VARCHAR,                   -- feature-ship | price-change | funding | pivot | acquisition | deprecation
  detail        VARCHAR,
  observed_date DATE,
  signal_strength VARCHAR,                 -- weak | moderate | strong
  affects_wedge BOOLEAN,                   -- does this erode a MetroGraph wedge feature?
  wedge_feature_ids VARCHAR[],             -- XREF market.features the move touches
  source_ids    VARCHAR[]
);

-- signals — leading indicators (hiring, patents, repo activity) that predict moves.
CREATE TABLE IF NOT EXISTS {{schema}}.signals (
  id            VARCHAR PRIMARY KEY,       -- compintel.signal.<slug>
  company_id    VARCHAR,
  signal_type   VARCHAR,                   -- job-posting | patent | github-activity | exec-hire | partnership
  observed_date DATE,
  detail        VARCHAR,
  interpretation VARCHAR,                  -- what it predicts
  confidence    DOUBLE,
  source_ids    VARCHAR[]
);
