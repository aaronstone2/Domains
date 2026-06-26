-- hci domain — the empirical HCI evidence base. Promotes market's theory layer (framework-grade) into
-- real published studies with effect sizes, grounding (or refuting) the design hypotheses the wedge
-- rests on. XREFs market.theory_concepts + market.claims. `claims` is a BASE table; extras below.
--
-- HONESTY: these studies are published HCI research (evidence_class='secondary', evidence_grade RCT/
-- meta-analysis) — they GROUND a hypothesis in general, but do NOT validate MetroGraph specifically.
-- So an hci claim can be 'supported' (cites real RCTs); the MetroGraph-self wedge claim it grounds
-- still reads PROXY-ONLY until a product-specific study exists.

-- studies — published empirical HCI results with effect sizes.
CREATE TABLE IF NOT EXISTS {{schema}}.studies (
  source_id        VARCHAR PRIMARY KEY,    -- the paper, registered as a sources.id
  title            VARCHAR,
  authors          VARCHAR,
  year             INTEGER,
  venue            VARCHAR,                -- CHI | UIST | TOCHI | meta-analysis | …
  study_type       VARCHAR,               -- RCT | meta-analysis | controlled-exp | eye-tracking | survey
  n                INTEGER,
  topic            VARCHAR,                -- graph-layout | metro-map | cognitive-load | mixed-initiative | direct-manipulation | …
  finding          VARCHAR,
  effect_size      DOUBLE,
  effect_metric    VARCHAR,               -- d | g | r | %-time-reduction | …
  ci_low           DOUBLE,
  ci_high          DOUBLE,
  p_value          DOUBLE,
  grounds_concept_ids VARCHAR[],          -- market.theory_concepts this evidences
  source_ids       VARCHAR[]
);

-- theory_grounding — does the published evidence actually support a market theory concept?
CREATE TABLE IF NOT EXISTS {{schema}}.theory_grounding (
  id                      VARCHAR PRIMARY KEY,  -- hci.grounding.<slug>
  market_theory_concept_id VARCHAR,             -- XREF market.theory_concepts.id
  claim                   VARCHAR,
  supporting_study_ids    VARCHAR[],
  contradicting_study_ids VARCHAR[],
  strength                VARCHAR,              -- established-law | strong-empirical | mixed | weak | refuted
  applies_to_market_claim_ids VARCHAR[],        -- which market wedge claims this grounds
  notes                   VARCHAR,
  source_ids              VARCHAR[]
);

-- design_hypotheses — MetroGraph's design bets, each scored against the empirical base.
CREATE TABLE IF NOT EXISTS {{schema}}.design_hypotheses (
  id                  VARCHAR PRIMARY KEY,      -- hci.hyp.<slug>
  statement           VARCHAR NOT NULL,
  maps_to_market_claim_id VARCHAR,              -- the (often refuted) market wedge claim it formalizes
  status              VARCHAR,                  -- grounded | partially-grounded | ungrounded | contradicted
  grounding_study_ids VARCHAR[],
  what_would_validate VARCHAR,                  -- the MetroGraph-specific experiment still needed
  source_ids          VARCHAR[]
);
