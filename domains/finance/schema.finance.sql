-- finance domain — the financial model. Builds a comps-based valuation band off market.funding_rounds,
-- unit-economics (CAC/LTV/payback), and named assumptions that feed the Layer-3 Monte-Carlo (ingest model).
-- XREFs market.companies / market.funding_rounds. `claims` is a BASE table; extras below.
-- Honesty: every figure is a comps-derived ESTIMATE — valuations are bands, not point truth; assumptions
-- carry p10/p50/p90 so the simulation reports a distribution, never a single deterministic number.

-- comps — a comparable company valuation datapoint, derived from a funding round.
CREATE TABLE IF NOT EXISTS {{schema}}.comps (
  id            VARCHAR PRIMARY KEY,        -- finance.comp.<slug>
  company_id    VARCHAR,                    -- XREF market.companies.id
  funding_round_id VARCHAR,                 -- XREF market.funding_rounds.id (soft)
  stage         VARCHAR,                    -- seed | series-a | … | public
  post_money_usd DOUBLE,
  raised_usd    DOUBLE,
  arr_estimate_usd DOUBLE,                  -- if known/estimable
  revenue_multiple DOUBLE,                  -- post_money / arr (null if arr unknown)
  as_of         DATE,
  multiple_basis VARCHAR,                   -- reported | estimated | inferred
  source_ids    VARCHAR[]
);

-- unit_economics — a CAC/LTV/payback datapoint or assumption for MetroGraph (or a comp benchmark).
CREATE TABLE IF NOT EXISTS {{schema}}.unit_economics (
  id            VARCHAR PRIMARY KEY,        -- finance.unit.<slug>
  scope         VARCHAR,                    -- metrograph | benchmark | segment:<id>
  metric        VARCHAR,                    -- cac | ltv | payback-months | gross-margin | nrr | logo-churn
  value         DOUBLE,
  unit          VARCHAR,                    -- usd | months | ratio | pct
  basis         VARCHAR,                    -- benchmark | assumption | derived
  confidence    DOUBLE,
  notes         VARCHAR,
  source_ids    VARCHAR[]
);

-- assumptions — named p10/p50/p90 inputs the Monte-Carlo samples (mirror of _shared/models YAML, queryable).
CREATE TABLE IF NOT EXISTS {{schema}}.assumptions (
  id            VARCHAR PRIMARY KEY,        -- finance.assume.<slug>
  model         VARCHAR,                    -- which model uses it (e.g. som | unit-econ | valuation)
  param         VARCHAR,                    -- tam_usd | sam_share | cac | …
  distribution  VARCHAR,                    -- point | uniform | normal | triangular | lognormal
  p10           DOUBLE,
  p50           DOUBLE,
  p90           DOUBLE,
  rationale     VARCHAR,
  source_ids    VARCHAR[]
);

-- simulation_runs — a recorded Monte-Carlo run (seed + summary), reproducible from assumptions + seed.
CREATE TABLE IF NOT EXISTS {{schema}}.simulation_runs (
  id            VARCHAR PRIMARY KEY,        -- finance.sim.<slug>
  model         VARCHAR,
  seed          INTEGER,
  n_iter        INTEGER,
  p10_out       DOUBLE,
  p50_out       DOUBLE,
  p90_out       DOUBLE,
  mean_out      DOUBLE,
  ran_at        DATE,
  notes         VARCHAR,
  source_ids    VARCHAR[]
);
