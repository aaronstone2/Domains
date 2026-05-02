-- Cross-domain views in the `meta` schema.
-- Re-run after any DDL change in domain schemas. Idempotent (CREATE OR REPLACE).

CREATE SCHEMA IF NOT EXISTS meta;

CREATE OR REPLACE VIEW meta.all_sources AS
  SELECT 'devin'       AS domain, * FROM devin.sources       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.sources      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.sources       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.sources         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.sources;

CREATE OR REPLACE VIEW meta.all_documents AS
  SELECT 'devin'       AS domain, * FROM devin.documents       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.documents      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.documents       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.documents         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.documents;

CREATE OR REPLACE VIEW meta.all_concepts AS
  SELECT 'devin'       AS domain, * FROM devin.concepts       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.concepts      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.concepts       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.concepts         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.concepts;

CREATE OR REPLACE VIEW meta.all_commands AS
  SELECT 'devin'       AS domain, * FROM devin.commands       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.commands      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.commands       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.commands         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.commands;

CREATE OR REPLACE VIEW meta.all_config_keys AS
  SELECT 'devin'       AS domain, * FROM devin.config_keys       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.config_keys      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.config_keys       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.config_keys         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.config_keys;

CREATE OR REPLACE VIEW meta.all_failure_modes AS
  SELECT 'devin'       AS domain, * FROM devin.failure_modes       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.failure_modes      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.failure_modes       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.failure_modes         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.failure_modes;

CREATE OR REPLACE VIEW meta.all_relationships AS
  SELECT 'devin'       AS domain, * FROM devin.relationships       UNION ALL BY NAME
  SELECT 'docker'      AS domain, * FROM docker.relationships      UNION ALL BY NAME
  SELECT 'linux'       AS domain, * FROM linux.relationships       UNION ALL BY NAME
  SELECT 'k8s'         AS domain, * FROM k8s.relationships         UNION ALL BY NAME
  SELECT 'methodology' AS domain, * FROM methodology.relationships;
