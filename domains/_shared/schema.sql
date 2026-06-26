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
  notes         VARCHAR
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
  source_id VARCHAR
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
  last_verified            DATE
);

-- ───────────────────────────────── migrations (idempotent) ─────────────────────────────────
-- Runs every init-db. Fresh rebuilds already have these from the CREATEs above; existing DBs that
-- predate a column get it here. ALTER … ADD COLUMN IF NOT EXISTS is a no-op when the column exists.
-- (Append new-column migrations here as the engine evolves; keep them grouped by the layer that added them.)
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS claim_type VARCHAR;
ALTER TABLE {{schema}}.claims ADD COLUMN IF NOT EXISTS confidence DOUBLE;
