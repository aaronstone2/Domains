-- Base schema applied to every domain schema in _db/knowledge.duckdb.
-- Use the {{schema}} placeholder; the ingest CLI's `init-db` runs this once per domain.
-- Domains are auto-discovered (every folder under domains/ except _shared).
-- Plus a `meta` schema for cross-domain views (defined in queries/cross_domain.sql).
--
-- EVOLUTION NOTE: `claims` is now a BASE table (was per-domain) so the gold layer is uniform
-- across domains and `meta.all_claims` exists. Per-domain claim extras are added via
-- `ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS ...` in each schema.<domain>.sql.
-- New columns on existing tables go in the `-- migrations` block at the bottom (idempotent).

CREATE SCHEMA IF NOT EXISTS {{schema}};

CREATE TABLE IF NOT EXISTS {{schema}}.sources (
  id            VARCHAR PRIMARY KEY,
  url           VARCHAR NOT NULL,
  title         VARCHAR,
  subdomain     VARCHAR,
  tier          VARCHAR CHECK (tier IN ('T0','T1','T2','T3')),
  license_note  VARCHAR,
  fetched_at    TIMESTAMP,
  content_hash  VARCHAR,
  parser        VARCHAR,
  notes         VARCHAR,
  -- Layer 1 — primary-evidence tier
  evidence_class VARCHAR,             -- primary | secondary | tertiary | synthetic (what KIND of evidence this is)
  primary_kind   VARCHAR              -- ab-test | pref-test | usability | review-mining | telemetry | interview | survey (when evidence_class='primary')
);

CREATE TABLE IF NOT EXISTS {{schema}}.documents (
  source_id    VARCHAR REFERENCES {{schema}}.sources(id),
  section_path VARCHAR,
  content_md   VARCHAR,
  PRIMARY KEY (source_id, section_path)
);

CREATE TABLE IF NOT EXISTS {{schema}}.concepts (
  id          VARCHAR PRIMARY KEY,
  name        VARCHAR NOT NULL,
  kind        VARCHAR,
  description VARCHAR,
  source_ids  VARCHAR[],
  aliases     VARCHAR[]
);

CREATE TABLE IF NOT EXISTS {{schema}}.commands (
  id        VARCHAR PRIMARY KEY,
  command   VARCHAR NOT NULL,
  purpose   VARCHAR,
  flags     STRUCT(name VARCHAR, value VARCHAR, doc VARCHAR)[],
  examples  STRUCT(invocation VARCHAR, expected_output VARCHAR, scenario VARCHAR)[],
  source_ids VARCHAR[]
);

CREATE TABLE IF NOT EXISTS {{schema}}.config_keys (
  id            VARCHAR PRIMARY KEY,
  scope         VARCHAR,
  key           VARCHAR NOT NULL,
  type          VARCHAR,
  default_value VARCHAR,
  description   VARCHAR,
  source_ids    VARCHAR[]
);

CREATE TABLE IF NOT EXISTS {{schema}}.failure_modes (
  id                VARCHAR PRIMARY KEY,
  symptom           VARCHAR NOT NULL,
  error_patterns    VARCHAR[],
  root_cause_class  VARCHAR,
  affected_concepts VARCHAR[],
  diagnostic_steps  STRUCT(step INTEGER, action VARCHAR, command VARCHAR, expected VARCHAR, source_id VARCHAR)[],
  fix_steps         STRUCT(step INTEGER, action VARCHAR, command VARCHAR, validation VARCHAR, rollback VARCHAR, source_id VARCHAR)[],
  confidence        DOUBLE,
  last_verified     DATE,
  source_ids        VARCHAR[]
);

CREATE TABLE IF NOT EXISTS {{schema}}.relationships (
  from_id   VARCHAR NOT NULL,
  to_id     VARCHAR NOT NULL,
  rel_type  VARCHAR NOT NULL,
  source_id VARCHAR,
  -- Layer 5 — causal/graph-reasoning
  confidence DOUBLE,                   -- 0..1 strength of the edge
  derived    BOOLEAN,                  -- TRUE if produced by an inference rule (vs observed)
  rule_id    VARCHAR,                  -- which rule derived it
  valid_from DATE,
  valid_to   DATE
);

-- derivations: provenance for rule-derived claims/edges (which rule, from which premises).
CREATE TABLE IF NOT EXISTS {{schema}}.derivations (
  id                VARCHAR PRIMARY KEY,
  derived_claim_id  VARCHAR,
  derived_rel       VARCHAR,           -- "from_id|rel_type|to_id" if it derived an edge
  rule_id           VARCHAR NOT NULL,
  premise_claim_ids VARCHAR[],
  premise_rel_ids   VARCHAR[],
  confidence_in     DOUBLE,
  confidence_out    DOUBLE,
  created_at        DATE
);

-- ───────────────────────── gold layer (promoted to base; common core) ─────────────────────────
-- The irreducible, adversarially-verified fact layer. Common columns live here; per-domain extras
-- (e.g. market.theory_concept_ids) are ALTER-added in schema.<domain>.sql. UNION ALL BY NAME in the
-- meta.all_claims view NULL-fills any column a given domain doesn't carry.
CREATE TABLE IF NOT EXISTS {{schema}}.claims (
  id                       VARCHAR PRIMARY KEY,
  statement                VARCHAR NOT NULL,
  category                 VARCHAR,               -- controlled vocab partitioned by leaf (writers never collide)
  claim_type               VARCHAR,               -- empirical | strategic | theoretical | quantitative | descriptive | evaluative | predictive
  verdict                  VARCHAR,               -- supported | equivalent | disputed | refuted | speculative
  nuance                   VARCHAR,               -- the recorded dissent / what evidence ACTUALLY shows
  evidence_grade           VARCHAR,               -- meta-analysis | RCT | analyst-report | survey | review-mining | expert | …
  population               VARCHAR,
  agreement_score          DOUBLE,                -- fraction of independent verifiers that did NOT refute (0..1)
  confidence               DOUBLE,                -- 0..1
  affected_ids             VARCHAR[],             -- entities this claim governs
  supporting_source_ids    VARCHAR[],
  contradicting_source_ids VARCHAR[],
  last_verified            DATE,
  -- Layer 6 — verification recalibration
  verification_standard    VARCHAR,               -- descriptive | evaluative | predictive (how this claim is checked)
  confidence_low           DOUBLE,                -- CI lower bound (not just a point agreement_score)
  confidence_high          DOUBLE,                -- CI upper bound
  decay_halflife_days      INTEGER,               -- how fast this claim goes stale
  stale                    BOOLEAN,               -- last_verified aged past halflife OR a supporting source changed
  forecast_resolved        BOOLEAN,               -- predictive claims: has the outcome resolved?
  forecast_actual          VARCHAR                -- the resolved outcome (for calibration)
);

-- ───────────────────────── Layer 1 — primary-evidence tier ─────────────────────────
-- claim_evidence: a gradeable junction generalizing supporting/contradicting_source_ids. Each row ties
-- a claim to one piece of evidence with a stance + weight + the evidence's class. Base → meta.all_claim_evidence.
CREATE TABLE IF NOT EXISTS {{schema}}.claim_evidence (
  id             VARCHAR PRIMARY KEY,   -- <domain>.ce.<claim-slug>.<n>
  claim_id       VARCHAR NOT NULL,
  evidence_id    VARCHAR,               -- a sources.id OR a primary_studies.source_id
  evidence_class VARCHAR,               -- primary | secondary | tertiary | synthetic (snapshot of the source's class)
  stance         VARCHAR,               -- supports | contradicts | contextual
  weight         DOUBLE,                -- 0..1 strength of this evidence for the claim
  is_primary     BOOLEAN,               -- convenience: evidence_class = 'primary'
  note           VARCHAR
);

-- primary_studies: real behavioral/empirical evidence (A/B, preference, usability, review-mining, telemetry).
-- The ONLY place 'experimental'/'primary' grade can originate. `is_dormant`=TRUE marks a framework placeholder
-- (the intake exists; no real data yet) so the wedge cannot be quietly upgraded to experimental grade. Base.
CREATE TABLE IF NOT EXISTS {{schema}}.primary_studies (
  source_id   VARCHAR PRIMARY KEY,       -- the study, registered as a sources.id (evidence_class='primary')
  study_type  VARCHAR,                   -- ab-test | pref-test | usability-task | review-mining | telemetry | survey | interview
  subject_id  VARCHAR,                   -- product/feature/segment under test
  n           INTEGER,
  population  VARCHAR,
  metric      VARCHAR,
  effect_size DOUBLE,
  ci_low      DOUBLE,
  ci_high     DOUBLE,
  p_value     DOUBLE,
  direction   VARCHAR,                   -- favors-us | favors-them | neutral
  raw_path    VARCHAR,                   -- gitignored raw capture
  captured_at DATE,
  methodology VARCHAR,
  is_dormant  BOOLEAN,                   -- TRUE = placeholder framework row, NOT real evidence
  source_ids  VARCHAR[]
);

-- Honesty guard (mechanized): is_primary_backed is DERIVED, never authored — synthetic/secondary
-- evidence can't masquerade as primary. The synthesis reads THIS view, not an author-set flag.
CREATE OR REPLACE VIEW {{schema}}.v_claim_grade AS
SELECT
  c.id AS claim_id,
  c.verdict,
  COALESCE(BOOL_OR(ce.stance = 'supports' AND ce.evidence_class = 'primary'
                   AND NOT COALESCE(ps.is_dormant, FALSE)), FALSE) AS is_primary_backed,
  COUNT(*) FILTER (WHERE ce.stance = 'supports') AS n_supporting_evidence
FROM {{schema}}.claims c
LEFT JOIN {{schema}}.claim_evidence ce ON ce.claim_id = c.id
LEFT JOIN {{schema}}.primary_studies ps ON ps.source_id = ce.evidence_id
GROUP BY c.id, c.verdict;

-- ───────────────────────── Layer 3 — quantitative model ─────────────────────────
-- Parameterized Monte-Carlo: assumptions (p10/p50/p90 per param) + reproducible runs (fixed seed).
-- Base so financial-model and market both inherit them; model defs live in _shared/models/*.yaml.
CREATE TABLE IF NOT EXISTS {{schema}}.model_assumptions (
  id           VARCHAR PRIMARY KEY,    -- <domain>.assume.<model>.<param>
  model        VARCHAR,
  param        VARCHAR,
  distribution VARCHAR,                -- point | normal | triangular | lognormal | uniform
  p10          DOUBLE,
  p50          DOUBLE,
  p90          DOUBLE,
  unit         VARCHAR,
  rationale    VARCHAR,
  source_ids   VARCHAR[]
);
CREATE TABLE IF NOT EXISTS {{schema}}.model_runs (
  id            VARCHAR PRIMARY KEY,   -- <domain>.run.<model>.<seed>
  model         VARCHAR,
  seed          INTEGER,
  n_draws       INTEGER,
  output_metric VARCHAR,
  p10           DOUBLE,
  p50           DOUBLE,
  p90           DOUBLE,
  mean          DOUBLE,
  stdev         DOUBLE,
  created_at    DATE
);

-- ───────────────────────── Layer 4 — semantic / embeddings ─────────────────────────
-- Local fastembed vectors over documents/claims/concepts. Fixed-width FLOAT[384] for the VSS HNSW
-- index (one model per index; dim/model recorded). Base → meta.all_embeddings (cross-domain search).
CREATE TABLE IF NOT EXISTS {{schema}}.embeddings (
  id           VARCHAR PRIMARY KEY,    -- <domain>.emb.<kind>.<object_id>
  object_kind  VARCHAR,                -- document | claim | concept | …
  object_id    VARCHAR,
  model        VARCHAR,
  dim          INTEGER,
  vector       FLOAT[384],
  content_hash VARCHAR
);

-- ───────────────────────── Layer 2 — temporal ─────────────────────────
-- claim_history: SCD-2 closed versions of claims. Written by `ingest snapshot` when a claim's verdict
-- or agreement changed since the last snapshot. row_json holds the full prior row (schema-drift proof).
CREATE TABLE IF NOT EXISTS {{schema}}.claim_history (
  history_id       VARCHAR PRIMARY KEY,    -- <claim_id>@<snapshot-label>
  claim_id         VARCHAR NOT NULL,
  verdict          VARCHAR,
  agreement_score  DOUBLE,
  as_of            DATE,
  valid_from       DATE,
  valid_to         DATE,
  superseded_at    DATE,
  supersede_reason VARCHAR,
  row_json         VARCHAR
);

-- forecast_log — predictive-claim calibration (Brier scoring). Base so meta.all_forecast_log exists.
CREATE TABLE IF NOT EXISTS {{schema}}.forecast_log (
  id              VARCHAR PRIMARY KEY,
  claim_id        VARCHAR,
  predicted_prob  DOUBLE,                          -- P assigned when the forecast was made (0..1)
  predicted_at    DATE,
  resolves_by     DATE,
  resolved        BOOLEAN,
  outcome         INTEGER,                         -- 1 = came true, 0 = did not (NULL until resolved)
  brier           DOUBLE,                          -- (predicted_prob - outcome)^2 once resolved
  notes           VARCHAR
);

-- ───────────────────────────────── migrations (idempotent) ─────────────────────────────────
-- Runs every init-db. Fresh rebuilds already have these from the CREATEs above; existing DBs that
-- predate a column get it here. ALTER … ADD COLUMN IF NOT EXISTS is a no-op when the column exists.
-- (Append new-column migrations here as the engine evolves; keep them grouped by the layer that added them.)
-- Stage 0:
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS claim_type VARCHAR;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS confidence DOUBLE;
-- Layer 6 (verification recalibration):
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS verification_standard VARCHAR;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS confidence_low DOUBLE;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS confidence_high DOUBLE;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS decay_halflife_days INTEGER;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS stale BOOLEAN;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS forecast_resolved BOOLEAN;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS forecast_actual VARCHAR;
-- Layer 1 (primary-evidence tier):
ALTER TABLE {{schema}}.sources ADD COLUMN IF NOT EXISTS evidence_class VARCHAR;
ALTER TABLE {{schema}}.sources ADD COLUMN IF NOT EXISTS primary_kind VARCHAR;
-- Layer 2 (temporal):
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS as_of DATE;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS valid_from DATE;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS valid_to DATE;
ALTER TABLE {{schema}}.sources ADD COLUMN IF NOT EXISTS valid_from DATE;
ALTER TABLE {{schema}}.sources ADD COLUMN IF NOT EXISTS valid_to DATE;
-- Layer 5 (causal/graph-reasoning):
ALTER TABLE {{schema}}.relationships ADD COLUMN IF NOT EXISTS confidence DOUBLE;
ALTER TABLE {{schema}}.relationships ADD COLUMN IF NOT EXISTS derived BOOLEAN;
ALTER TABLE {{schema}}.relationships ADD COLUMN IF NOT EXISTS rule_id VARCHAR;
ALTER TABLE {{schema}}.relationships ADD COLUMN IF NOT EXISTS valid_from DATE;
ALTER TABLE {{schema}}.relationships ADD COLUMN IF NOT EXISTS valid_to DATE;
