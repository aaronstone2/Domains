-- Base schema applied to every domain schema in _db/knowledge.duckdb.
-- Use the {{schema}} placeholder; the ingest CLI's `init-db` runs this once per domain.
-- Domains: devin, docker, linux, k8s, methodology
-- Plus a `meta` schema for cross-domain views (defined in queries/cross_domain.sql).

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
