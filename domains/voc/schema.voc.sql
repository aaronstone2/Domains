-- voc domain — Voice of Customer. The PROXY-EVIDENCE engine: real user voice mined from public review
-- sites (G2/Capterra/Reddit/HN/GitHub issues) that grounds the wedge pain-points in *review-mining* grade
-- evidence (NOT behavioral/experimental). XREFs market.features / market.companies / market.segments.
-- `claims` is a BASE table; extras below.
--
-- HONESTY (the core of the user's evidence constraint): mined reviews are evidence_class='primary' ONLY in
-- the review-mining sense (real user statements), graded `primary_kind='review-mining'`. They raise a wedge
-- pain claim to **supported-by-proxy**, NEVER to experimental/behavioral grade — a review proves a user
-- *said* something, not that MetroGraph *measurably fixes* it. The dormant intake tables below stay EMPTY
-- (no real MetroGraph study data exists or is assumed); they exist so real data can land later without a
-- schema change, and their emptiness is the standing `pending-experimental` marker.

-- reviews — a single mined public user statement about a competitor/category (the raw proxy evidence).
CREATE TABLE IF NOT EXISTS {{schema}}.reviews (
  id            VARCHAR PRIMARY KEY,        -- voc.review.<slug>
  company_id    VARCHAR,                    -- XREF market.companies.id (the product reviewed)
  platform      VARCHAR,                    -- g2 | capterra | reddit | hn | github | trustradius | youtube
  rating        DOUBLE,                     -- normalized 0-5 where available
  role          VARCHAR,                    -- reviewer role/persona if stated
  segment_id    VARCHAR,                    -- XREF market.segments.id (inferred)
  quote         VARCHAR,                    -- the actual user words (verbatim, trimmed)
  sentiment     VARCHAR,                    -- positive | negative | mixed | neutral
  about_feature_ids VARCHAR[],              -- XREF market.features the quote touches
  pain_or_praise VARCHAR,                   -- pain | praise
  observed_date DATE,
  url           VARCHAR,
  source_ids    VARCHAR[]
);

-- sentiment_themes — an aggregated pain/praise theme across many reviews (the mined signal).
CREATE TABLE IF NOT EXISTS {{schema}}.sentiment_themes (
  id            VARCHAR PRIMARY KEY,        -- voc.theme.<slug>
  theme         VARCHAR,
  polarity      VARCHAR,                    -- pain | praise
  frequency     INTEGER,                    -- # of mined reviews mentioning it
  maps_to_feature_id VARCHAR,               -- XREF market.features.id
  maps_to_wedge_claim_id VARCHAR,           -- the market wedge claim this proxy-grounds
  grounds_strength VARCHAR,                 -- supported-by-proxy | weak-proxy | contradicts
  representative_review_ids VARCHAR[],
  notes         VARCHAR,
  source_ids    VARCHAR[]
);

-- personas_voc — a customer persona reconstructed from the mined voice (jobs/pains/triggers).
CREATE TABLE IF NOT EXISTS {{schema}}.personas_voc (
  id            VARCHAR PRIMARY KEY,        -- voc.persona.<slug>
  name          VARCHAR,
  segment_id    VARCHAR,                    -- XREF market.segments.id
  jobs_to_be_done VARCHAR,
  top_pains     VARCHAR,
  switching_triggers VARCHAR,
  evidence_review_ids VARCHAR[],
  source_ids    VARCHAR[]
);

-- ============================ DORMANT REAL-STUDY INTAKE (stays EMPTY) ============================
-- These tables are the wired-but-dormant intake for genuine MetroGraph behavioral data. They are NEVER
-- populated by mining or assumption. Their emptiness IS the pending-experimental marker the synthesis
-- reads to keep every wedge claim capped at supported-by-proxy. Real data lands here only if/when an
-- actual study is run — which the plan explicitly does NOT assume will ever happen.
CREATE TABLE IF NOT EXISTS {{schema}}.interviews (
  id VARCHAR PRIMARY KEY, participant_ref VARCHAR, segment_id VARCHAR, conducted_date DATE,
  jobs VARCHAR, pains VARCHAR, transcript_path VARCHAR, source_ids VARCHAR[]
);
CREATE TABLE IF NOT EXISTS {{schema}}.surveys (
  id VARCHAR PRIMARY KEY, instrument VARCHAR, n INTEGER, fielded_date DATE,
  metric VARCHAR, value DOUBLE, ci_low DOUBLE, ci_high DOUBLE, raw_path VARCHAR, source_ids VARCHAR[]
);
CREATE TABLE IF NOT EXISTS {{schema}}.usability_sessions (
  id VARCHAR PRIMARY KEY, task VARCHAR, participant_ref VARCHAR, completed BOOLEAN,
  time_on_task_s DOUBLE, error_count INTEGER, sus_score DOUBLE, recorded_date DATE, raw_path VARCHAR, source_ids VARCHAR[]
);
CREATE TABLE IF NOT EXISTS {{schema}}.ab_experiments (
  id VARCHAR PRIMARY KEY, hypothesis VARCHAR, variant VARCHAR, metric VARCHAR, n INTEGER,
  effect_size DOUBLE, ci_low DOUBLE, ci_high DOUBLE, p_value DOUBLE, direction VARCHAR,
  ran_date DATE, raw_path VARCHAR, source_ids VARCHAR[]
);
