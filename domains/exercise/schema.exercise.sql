-- Per-domain schema extension for `exercise`, applied by `ingest init-db` on top of the
-- shared base schema (sources, documents, concepts, commands, config_keys, failure_modes,
-- relationships). Uses the same {{schema}} placeholder substituted with the domain name.
--
-- These tables turn the corpus into a queryable "algebra of facts" for training science:
-- anatomy (muscles), the movement library (exercises + substitutions + patterns), the
-- parameterized programming knobs (training_variables), set-structure techniques, the
-- adversarially-verified evidence layer (claims + studies), and a personal constraints layer
-- (injuries, equipment gaps) that flags exercises and prescribes swaps.
--
-- Base-table reuse: papers live in {{schema}}.sources (tier = evidence grade: T0 meta-analysis /
-- systematic review, T1 RCT in trained subjects, T2 expert consensus, T3 mechanistic/blog).
-- Cross-entity edges live in {{schema}}.relationships (targets, substitutes, evidenced-by, ...).

-- ────────────────────────────────────────────────────────────── anatomy
CREATE TABLE IF NOT EXISTS {{schema}}.muscles (
  id              VARCHAR PRIMARY KEY,          -- exercise.muscle.gastrocnemius
  name            VARCHAR NOT NULL,
  muscle_group    VARCHAR,                      -- back | chest | shoulders | quads | calves | forearms | core ...
  region          VARCHAR,                      -- lower-leg | posterior-chain | anterior-torso ...
  heads           VARCHAR[],                    -- ['medial','lateral'] | ['long','lateral','medial']
  primary_actions VARCHAR[],                    -- ['plantarflexion'] | ['shoulder-extension','adduction']
  planes          VARCHAR[],                    -- sagittal | frontal | transverse
  joints_crossed  VARCHAR[],
  biarticular     BOOLEAN,                      -- crosses two joints (length depends on the other joint)
  length_bias     VARCHAR,                      -- e.g. gastroc biased knee-straight; soleus knee-bent
  antagonist_ids  VARCHAR[],
  notes           VARCHAR,
  source_ids      VARCHAR[]
);

-- ──────────────────────────────────────────────────── movement taxonomy
CREATE TABLE IF NOT EXISTS {{schema}}.movement_patterns (
  id                    VARCHAR PRIMARY KEY,    -- exercise.pattern.horizontal-pull
  name                  VARCHAR NOT NULL,
  plane                 VARCHAR,
  description           VARCHAR,
  antagonist_pattern_id VARCHAR,                -- horizontal-pull <-> horizontal-push
  source_ids            VARCHAR[]
);

-- ──────────────────────────────────────────────────── the exercise library
CREATE TABLE IF NOT EXISTS {{schema}}.exercises (
  id                  VARCHAR PRIMARY KEY,      -- exercise.move.barbell-bent-over-row
  name                VARCHAR NOT NULL,
  aliases             VARCHAR[],
  movement_pattern_id VARCHAR,
  primary_muscle_ids  VARCHAR[],
  secondary_muscle_ids VARCHAR[],
  equipment           VARCHAR[],                -- ['barbell'] | ['cable','wrist-cuff'] | ['smith-machine']
  is_compound         BOOLEAN,
  is_unilateral       BOOLEAN,
  force_vector        VARCHAR,                  -- vertical | horizontal | rotational | axial
  rom_notes           VARCHAR,
  grip_demand         VARCHAR,                  -- none | low | moderate | high  (severity of grip involvement)
  grip_pattern_tags   VARCHAR[],                -- ['crush-grip','weight-hanging','dead-hang',...] — the JOIN KEY that constraints.triggers matches against (list_has_any). Cross-leaf contract: see PLAN.md.
  joint_stress        VARCHAR[],                -- joints carrying notable load (for constraint matching)
  stimulus_to_fatigue VARCHAR,                  -- low | moderate | high  (SFR — favor high-SFR for accessories)
  regional_bias       VARCHAR,                  -- which region/head it biases (e.g. 'lower lats')
  -- default_* are ADVISORY exercise-intrinsic defaults (e.g. calves -> higher reps). The
  -- authoritative prescription lives in training_variables; routine reconciles, training_variables wins.
  default_rep_range   VARCHAR,
  default_rir         VARCHAR,
  tempo               VARCHAR,
  cues                VARCHAR,
  fixed_or_dynamic    VARCHAR,                  -- 'fixed-core' (consistent 8-12wk) | 'dynamic-accessory' (rotate 4-6wk)
  source_ids          VARCHAR[]
);

-- ──────────────────────────────────────── substitution edges (no-machine swaps)
CREATE TABLE IF NOT EXISTS {{schema}}.substitutions (
  id                  VARCHAR PRIMARY KEY,
  from_exercise_id    VARCHAR NOT NULL,
  to_exercise_id      VARCHAR NOT NULL,
  reason              VARCHAR,                  -- equipment-unavailable | injury-spare | regional-variety
  shares_pattern      BOOLEAN,
  shares_primary_mover BOOLEAN,
  equipment_removed   VARCHAR[],                -- equipment the swap no longer needs
  equipment_required  VARCHAR[],                -- equipment the swap DOES need
  equivalence_score   DOUBLE,                   -- 0..1 how close the stimulus is
  caveat              VARCHAR,                  -- what you lose (e.g. 'loses constant tension at top')
  source_ids          VARCHAR[]
);

-- ─────────────────────────────────── parameterized, cited programming knobs
CREATE TABLE IF NOT EXISTS {{schema}}.training_variables (
  id             VARCHAR PRIMARY KEY,           -- exercise.var.weekly-sets.back.hypertrophy.trained
  scope          VARCHAR,                       -- global | muscle | exercise | lift-type
  key            VARCHAR NOT NULL,              -- weekly_sets | session_sets | rir | frequency | rest_seconds | rep_range | tempo
  goal           VARCHAR,                       -- hypertrophy | strength | endurance
  population     VARCHAR,                       -- novice | intermediate | trained | elite
  applies_to     VARCHAR,                       -- muscle/lift this row scopes to (nullable for global)
  min_value      DOUBLE,
  max_value      DOUBLE,
  recommended    VARCHAR,                       -- human-readable sweet spot
  unit           VARCHAR,                       -- sets/week | reps | seconds | %1RM | RIR
  description    VARCHAR,
  evidence_grade VARCHAR,                       -- meta-analysis | RCT | expert | mechanistic
  source_ids     VARCHAR[]
);

-- ─────────────────────────────────────────────────── set-structure techniques
CREATE TABLE IF NOT EXISTS {{schema}}.set_structures (
  id                VARCHAR PRIMARY KEY,        -- exercise.tech.reverse-pyramid
  name              VARCHAR NOT NULL,
  family            VARCHAR,                    -- pyramid | straight-set | intensity-technique
  mechanism         VARCHAR,                    -- how it acts on motor units / fatigue
  fatigue_cost      VARCHAR,                    -- low | moderate | high
  best_for          VARCHAR,                    -- compound-strength | isolation-hypertrophy | time-efficiency
  contraindications VARCHAR,
  evidence_grade    VARCHAR,
  source_ids        VARCHAR[]
);

-- ───────────────────────── the GOLD layer: adversarially-verified claims
CREATE TABLE IF NOT EXISTS {{schema}}.claims (
  id                     VARCHAR PRIMARY KEY,
  statement              VARCHAR NOT NULL,      -- "RPT grows more muscle than straight sets"
  category               VARCHAR,               -- controlled vocab partitioned by leaf (so the 3 writers can't collide): anatomy-* (anatomy) | volume|intensity|frequency|failure|overload|periodization (programming) | set-structure (techniques)
  verdict                VARCHAR,               -- supported | equivalent | disputed | refuted
  nuance                 VARCHAR,               -- what the evidence ACTUALLY shows (the recorded dissent)
  evidence_grade         VARCHAR,               -- meta-analysis | RCT | expert | mechanistic
  population             VARCHAR,
  agreement_score        DOUBLE,                -- fraction of independent verifiers that did NOT refute (0..1)
  affected_ids           VARCHAR[],             -- exercises/muscles/variables/structures this claim governs
  supporting_source_ids  VARCHAR[],
  contradicting_source_ids VARCHAR[],
  last_verified          DATE
);

-- ───────────────────── richer per-paper metadata (keyed to {{schema}}.sources)
-- Written by multiple leaves that share papers; source_id is the PK, so first-writer-wins on upsert.
-- Source-of-truth contract (see PLAN.md): programming authors shared method/effect papers; other
-- leaves reference the same source_id and only add a row for papers unique to them.
CREATE TABLE IF NOT EXISTS {{schema}}.studies (
  source_id       VARCHAR PRIMARY KEY,          -- FK to {{schema}}.sources.id
  design          VARCHAR,                      -- meta-analysis | systematic-review | RCT | cohort | narrative
  n_subjects      INTEGER,
  population       VARCHAR,
  training_status VARCHAR,                       -- untrained | recreational | trained | elite
  duration_weeks  INTEGER,
  key_finding     VARCHAR,
  effect_summary  VARCHAR,
  citation        VARCHAR,
  notes           VARCHAR
);

-- ───────────────────────── the personal layer: injuries, equipment, prefs
CREATE TABLE IF NOT EXISTS {{schema}}.constraints (
  id                    VARCHAR PRIMARY KEY,    -- exercise.constraint.left-pinky-jam
  label                 VARCHAR NOT NULL,
  kind                  VARCHAR,                -- injury | equipment-gap | mobility | preference
  description           VARCHAR,
  triggers              VARCHAR[],              -- free descriptive tags (overhead, deep-flexion, axial-loading, impact, ballistic, end-range, ...)
  -- typed matching columns: an exercise is contraindicated if its movement_pattern_id is in provoking_patterns,
  -- OR its joint_stress overlaps provoking_joint_stress, OR its grip_pattern_tags overlaps provoking_grip_tags.
  provoking_patterns    VARCHAR[],              -- movement_pattern slugs that aggravate it (vertical-push, hip-hinge, spinal-flexion, ...)
  provoking_joint_stress VARCHAR[],             -- joint keys (shoulder, elbow, wrist, lumbar-spine, hip, knee, ankle, cervical)
  provoking_grip_tags   VARCHAR[],              -- grip_pattern_tags (crush-grip, dead-hang, weight-hanging) for grip-mediated constraints
  red_flags             VARCHAR[],              -- symptoms that mean STOP + see a professional (the refer-out screen)
  intake_questions      VARCHAR[],              -- the functional characterization protocol for this constraint kind
  affected_exercise_ids VARCHAR[],
  affected_muscle_ids   VARCHAR[],
  workaround            VARCHAR,                -- e.g. 'use cable wrist cuffs / lifting straps / machine variant'
  substitute_exercise_ids VARCHAR[],
  severity              VARCHAR,                -- mild | moderate | hard-block
  active                BOOLEAN,
  notes                 VARCHAR,
  source_ids            VARCHAR[]
);

-- ───────────────────── per-gym equipment profiles (multi-gym) ─────────────
-- A gym is a stored location with an equipment inventory. The routine generator takes a gym_id
-- and selects/substitutes exercises against what that gym actually has. New gym = new profile JSON
-- in routine/gyms/<id>.json + a load. Lets the same lifter carry routines across multiple gyms.
CREATE TABLE IF NOT EXISTS {{schema}}.gyms (
  id          VARCHAR PRIMARY KEY,    -- gym.<slug>
  name        VARCHAR NOT NULL,
  location    VARCHAR,
  notes       VARCHAR,
  is_default  BOOLEAN,
  updated     DATE
);

CREATE TABLE IF NOT EXISTS {{schema}}.gym_equipment (
  gym_id           VARCHAR NOT NULL,   -- -> gyms.id
  equipment        VARCHAR NOT NULL,   -- implement/station key
  category         VARCHAR,            -- free-weight | bar | machine | cable | bench | rack | cardio | accessory
  corpus_equipment VARCHAR,            -- corpus exercise.equipment value(s) this satisfies, csv (dumbbell, cable, machine, smith-machine, barbell, ez-bar, kettlebell, bodyweight, box, ankle-cuff, wrist-cuff, ...)
  station          VARCHAR,            -- specific station key for exercise gating (lat-pulldown, leg-press, pec-deck, back-extension, ...) or NULL
  available        BOOLEAN,            -- false = explicitly absent (drives substitution)
  -- LOADING ALGEBRA: how this implement's achievable weights are computed.
  loading_model    VARCHAR,            -- arithmetic | discrete | plate-loaded | bodyweight | none
  min_lb           DOUBLE,             -- arithmetic / plate-loaded (lightest settable load)
  max_lb           DOUBLE,             -- arithmetic / plate-loaded (heaviest settable load)
  increment_lb     DOUBLE,             -- arithmetic / plate-loaded (smallest step)
  bar_weight_lb    DOUBLE,             -- plate-loaded: the bar's own contribution (Olympic 45, Smith effective ~25)
  weights_lb       DOUBLE[],           -- discrete: the explicit set (kettlebells, fixed-bar set, corebags)
  quantity         INTEGER,            -- count / pairs of the implement
  est              BOOLEAN,            -- TRUE = numeric values are estimates pending measurement
  model            VARCHAR,            -- brand / model
  notes            VARCHAR,
  PRIMARY KEY (gym_id, equipment)
);

-- Plate inventory per gym -> derives the plate-loaded bars' increment (2x smallest) and max (bar + 2x total).
CREATE TABLE IF NOT EXISTS {{schema}}.gym_plates (
  gym_id     VARCHAR NOT NULL,         -- -> gyms.id
  plate_lb   DOUBLE NOT NULL,
  pair_count INTEGER,                  -- number of PAIRS (NULL = ample/unknown)
  est        BOOLEAN,
  PRIMARY KEY (gym_id, plate_lb)
);
