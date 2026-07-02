-- governance domain — de-risks the governance/enterprise ICP. Catalogs the compliance requirements a
-- data-tooling buyer imposes, maps them to MetroGraph features that satisfy (controls), and surfaces the
-- gaps that GATE the enterprise segment. XREFs market.features / market.segments. `claims` is a BASE
-- table; extras below. Honesty: a control "satisfies" a requirement only as a design-claim until audited.

-- requirements — a compliance/governance obligation an enterprise buyer imposes on data tooling.
CREATE TABLE IF NOT EXISTS {{schema}}.requirements (
  id            VARCHAR PRIMARY KEY,        -- governance.req.<slug>
  framework     VARCHAR,                    -- soc2 | gdpr | hipaa | iso27001 | ccpa | sox | internal
  category      VARCHAR,                    -- access-control | audit-log | data-residency | lineage | encryption | retention | rbac
  statement     VARCHAR,
  severity      VARCHAR,                    -- table-stakes | important | nice-to-have
  applies_to_segment_id VARCHAR,            -- XREF market.segments.id (which ICP demands it)
  source_ids    VARCHAR[]
);

-- controls — a MetroGraph capability that satisfies (or partially satisfies) a requirement.
CREATE TABLE IF NOT EXISTS {{schema}}.controls (
  id            VARCHAR PRIMARY KEY,        -- governance.control.<slug>
  requirement_id VARCHAR,                   -- XREF governance.requirements.id
  feature_id    VARCHAR,                    -- XREF market.features.id that implements it (soft)
  coverage      VARCHAR,                    -- full | partial | none | planned
  evidence      VARCHAR,                    -- how it's satisfied (or why not)
  is_shipped    BOOLEAN,                    -- does this exist today (from product domain) or aspirational
  source_ids    VARCHAR[]
);

-- compliance_gaps — an unmet (or partly-met) requirement that GATES a segment. The deliverable.
CREATE TABLE IF NOT EXISTS {{schema}}.compliance_gaps (
  id            VARCHAR PRIMARY KEY,        -- governance.gap.<slug>
  requirement_id VARCHAR,
  gates_segment_id VARCHAR,                 -- XREF market.segments.id this gap blocks
  severity      VARCHAR,                    -- blocker | major | minor
  remediation   VARCHAR,                    -- what MetroGraph must build to close it
  effort        VARCHAR,                    -- s | m | l | xl
  becomes_roadmap_item BOOLEAN,             -- feeds strategy/roadmap-gtm
  source_ids    VARCHAR[]
);
