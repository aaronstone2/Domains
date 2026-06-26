-- strategy domain — the prescriptive SYNTHESIS layer. Reads the whole cross-domain algebra
-- (market + product + hci + voc + compintel + ecosystem + governance + finance) READ-ONLY and renders a
-- non-divergent family of always-current, fully-cited strategy artifacts. It NEVER mutates another
-- domain's claims/verdicts (the C5 conflation guard). `claims` is a BASE table; extras below.
--
-- HONESTY (the spine of the whole build): the wedge's grade is DERIVED, CAPPED, and MARKED. A wedge claim's
-- highest achievable ceiling is `supported-by-proxy / pending-experimental` — never experimental — because
-- the voc dormant-intake tables are empty. wedge_reeval.pending_experimental is computed from that emptiness;
-- needed_experiments are emitted as roadmap items, never assumed satisfied.

-- ============================ WAVE 3: wedge re-evaluation overlay ============================
-- For each market wedge claim, overlay the cross-domain evidence now available WITHOUT touching market's
-- own verdict. The ceiling grade is derived from the evidence mix; pending_experimental is always true for
-- a wedge claim (no real MetroGraph study exists).
CREATE TABLE IF NOT EXISTS {{schema}}.wedge_reeval (
  id                  VARCHAR PRIMARY KEY,    -- strategy.reeval.<market-claim-slug>
  market_claim_id     VARCHAR,                -- XREF market.claims.id (read-only)
  market_verdict      VARCHAR,                -- the ORIGINAL market verdict, copied for contrast (never written back)
  cross_domain_ceiling VARCHAR,               -- supported-by-proxy | contested | weak-proxy | corpus-refuted-only
  proxy_support       VARCHAR[],              -- voc/hci/product/compintel edges that raise it
  contradicting       VARCHAR[],              -- edges that undercut it (recorded, not hidden)
  pending_experimental BOOLEAN,               -- ALWAYS true for a wedge claim (dormant intake empty)
  needed_experiment   VARCHAR,                -- the MetroGraph-specific study that would lift the ceiling
  confidence          DOUBLE,
  rationale           VARCHAR,
  source_ids          VARCHAR[]
);

-- ============================ WAVE 4: prescriptive roadmap + GTM ============================
-- recommendations — a prioritized action. priority_score is a QUERY over cited claims' confidence x impact,
-- NOT hand-set, so it recomputes when facts change. Every rec cites evidence + exposes tradeoffs.
CREATE TABLE IF NOT EXISTS {{schema}}.recommendations (
  id                  VARCHAR PRIMARY KEY,    -- strategy.rec.<slug>
  kind                VARCHAR,                -- build | gtm | integration | compliance | experiment | positioning
  statement           VARCHAR,
  cites_claim_ids     VARCHAR[],              -- cross-domain claims grounding it
  impact              DOUBLE,                 -- 0-1 strategic impact
  confidence          DOUBLE,                 -- 0-1 derived from cited claims' confidence
  effort              VARCHAR,                -- s | m | l | xl
  priority_score      DOUBLE,                 -- DERIVED: impact x confidence / effort_weight (recomputed)
  tradeoffs           VARCHAR,
  is_experiment       BOOLEAN,                -- true => a needed-but-missing validation study (from pending_experimental)
  source_ids          VARCHAR[]
);

-- render_blocks — ONE shared, cited block per metric/claim. Every artifact projects from these; no artifact
-- restates a number. A block resolves to exactly one claim_id/source_id => structural non-divergence.
CREATE TABLE IF NOT EXISTS {{schema}}.render_blocks (
  id                  VARCHAR PRIMARY KEY,    -- strategy.block.<slug>
  block_kind          VARCHAR,                -- metric | claim | recommendation | risk | quote
  label               VARCHAR,
  value_text          VARCHAR,                -- the rendered text/number (single source of truth)
  resolves_claim_id   VARCHAR,                -- the ONE claim this block resolves to
  resolves_source_id  VARCHAR,                -- the ONE source it cites
  verdict_glyph       VARCHAR,                -- self-auditing glyph (supported / proxy / contested / speculative)
  source_ids          VARCHAR[]
);

-- artifact_blocks — which artifact uses which block. The join that PROVES non-divergence: a shared metric
-- across deck+memo+battlecard maps to the identical block_id => identical claim_id/source_id.
CREATE TABLE IF NOT EXISTS {{schema}}.artifact_blocks (
  artifact            VARCHAR,                -- investor-deck | strategy-memo | battlecard:<competitor> | board-update | sales-enablement
  block_id            VARCHAR,                -- XREF render_blocks.id
  ordinal             INTEGER,
  PRIMARY KEY (artifact, block_id)
);

-- ============================ WAVE 4: standing red-team ============================
-- red_team_findings — the bear case re-run on every promoted claim: strongest counter-move, failure mode,
-- thesis falsifier. Wedge falsifiers wire to live compintel temporal signals.
CREATE TABLE IF NOT EXISTS {{schema}}.red_team_findings (
  id                  VARCHAR PRIMARY KEY,    -- strategy.redteam.<slug>
  kind                VARCHAR,                -- competitor-countermove | failure-mode | thesis-falsifier
  targets_claim_id    VARCHAR,                -- the claim/thesis it attacks
  statement           VARCHAR,
  severity            VARCHAR,                -- fatal | major | minor
  watch_signal_id     VARCHAR,                -- XREF compintel.changes/signals that would confirm it firing
  fired               BOOLEAN,                -- has the watch signal actually fired?
  mitigation          VARCHAR,
  source_ids          VARCHAR[]
);
