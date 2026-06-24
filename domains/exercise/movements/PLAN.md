# Plan — `exercise/movements`

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> Depth for this leaf: **exhaustive** (see `STATUS.yaml`). It is load-bearing — the generator
> (`routine`) selects, swaps, and orders every prescription out of the rows this leaf produces, so
> source discovery fans out fully, every in-scope exercise/pattern is extracted, and the gold layer
> (Phase D) is verified by N independent skeptics. See `domains/_shared/sessions/depth-profiles.md`.
> The re-engagement contract is `domains/_shared/sessions/extend-playbook.md`.

## Context

Why this leaf exists: `movements` is the **exercise library and the swap engine** of the domain. It
builds, in order, (1) the **movement-pattern taxonomy** — the small closed set of biomechanical
patterns (horizontal/vertical push, horizontal/vertical pull, hip-hinge, squat, lunge/split-squat,
plantarflexion knee-straight vs knee-bent, elbow flexion supinated/neutral/pronated, anti-rotation /
anti-extension / anti-lateral-flexion core, hip abduction, shoulder horizontal abduction, etc.) with
**antagonist pairings**, so the generator can reason about balance and pattern coverage instead of
exercise names; (2) the **exercise library** across all equipment classes (barbell, dumbbell, cable,
machine, smith, bodyweight) with prime/secondary movers (referencing `muscles.id` from the `anatomy`
leaf), `grip_demand` (the field that drives all grip-bypass logic for the left-pinky constraint), SFR
(stimulus-to-fatigue), `regional_bias` (e.g. lower-lat row vs upper-back row, long-head triceps vs
lateral), force vector, ROM notes, and the **fixed-core vs dynamic-accessory** tag the mesocycle uses;
and (3) the first-class **substitution graph** — for every machine-dependent movement, ≥1 swap that
**shares pattern + prime mover** but **drops the missing equipment**, each carrying an
`equivalence_score` and an explicit `caveat` (what stimulus is lost), plus grip-bypass swaps (cable
wrist cuffs / lifting straps / chest-supported & machine variants) that preserve the target stimulus
while removing the crush-grip / weight-hanging demand. The corpus must answer: *"I have no [machine X]
— what hits the same prime mover in the same pattern, and what do I lose?"*, *"this movement jams my
pinky — give me an equivalent that bypasses grip"*, and *"which exercises bias [region/head Y] of
[muscle]?"*

How it composes: **depends on `anatomy`** (every `primary_muscle_ids` / `secondary_muscle_ids` is a
foreign key into `muscles`; the leaf cannot finalize movers until anatomy's muscle ids and length-bias
facts exist — coordinate id naming `exercise.muscle.*`). **Underpins `routine`** (the generator picks
exercises, runs the pattern/region coverage gap-analysis, and walks the substitution graph) and the
personal **`constraints`** leaf (the pinky/equipment-gap rows resolve their `substitute_exercise_ids`
and match their `triggers` against this leaf's `grip_demand` + pattern). It feeds `programming`
indirectly via `default_rep_range` / `default_rir` / `fixed_or_dynamic` (compound-vs-isolation, where
failure belongs). Cross-domain links are wired in Phase E **as discovered**, not deferred.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the domain tables in `domains/exercise/schema.exercise.sql`.

This leaf fills (row targets are the **exhaustive** profile):

| Table | What this leaf puts there | Row target (exhaustive) |
|---|---|---|
| `movement_patterns` | full biomechanical pattern taxonomy + antagonist pairings | **~22–30** patterns |
| `exercises` | the cross-equipment library; prime/secondary movers (→`muscles`), equipment, force vector, ROM, `grip_demand`, SFR, `regional_bias`, `fixed_or_dynamic`, default rep/RIR | **~120–200** exercises |
| `substitutions` | ≥1 swap per machine-dependent move + all grip-bypass swaps; pattern+mover preserved, equipment dropped, `equivalence_score` + `caveat` | **~150–260** edges (≥1 per machine-dependent exercise; many exercises get 2–4) |
| `sources` | ExRx pages, SBS/RP exercise guides, Nippard guides, Beardsley biomech notes | ~25–45 (shared with siblings; de-duped) |
| `documents` | fetched + cleaned source text | tracks `sources` |
| `concepts` | pattern / mechanics vocabulary not already a row (e.g. "active insufficiency", "constant tension", "resistance profile / strength curve", "stretch-mediated hypertrophy at long muscle length") | ~15–30 |
| `relationships` | `targets` (exercise→muscle), `substitutes` (exercise→exercise), `antagonist-of` (pattern↔pattern), `evidenced-by` | dense (Phase E) |

This leaf does **not** own `claims` (that's `programming`/`techniques`), but it **does** carry the
small gold layer described in Phase D: the **substitution-equivalence judgments** are the irreducible,
adversarially-verified facts of this leaf (each `equivalence_score` + `caveat` is a defendable claim
about stimulus, not a transcription). `muscles` is owned by `anatomy`; this leaf only references it.

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — ExRx's
exercise-directory ToC by muscle/equipment, SBS & RP exercise-guide indexes, Nippard's
exercise-library / "best exercises for X" series, Beardsley's biomechanics catalog; sketch the
pattern taxonomy and the equipment matrix. (2) **Plan** agent(s) design the extraction: the canonical
pattern list + antagonist map, the exercise-id scheme (`exercise.move.<equipment>-<name>`), the
mover-attribution rubric (prime = directly produces the joint action under load; secondary = stabilizer
/ assistant), and the substitution-edge rubric (what makes a swap valid; how `equivalence_score` is
scored). (3) `AskUserQuestion` on high-leverage forks: **(a)** breadth-vs-depth of the library (cap at
~120 core or push to ~200 incl. cable/unilateral variants?), **(b)** how strictly "machine-dependent"
is defined (pin-loaded only, or also cable-stack / smith?), **(c)** whether to pre-seed the equipment
inventory now so substitution targets are filtered to owned gear (defer to `constraints` if unknown).
(4) write this PLAN + `STATUS.yaml`; (5) `ExitPlanMode`.

The irreducible work is the **gold layer (Phase D)** — the equivalence judgments. Everything before it
is mechanical (find URLs, fetch, parse, attribute movers). Meta-research exists to protect that layer
from being spent on a bad taxonomy or a redundant source set.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to the movement library + biomechanics.

- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` (de-dupe against `anatomy`/`programming`
      — many authorities overlap). Candidate source **categories + named authorities**:
  - **Exercise databases / mover attribution** — **ExRx.net** (per-exercise prime/secondary movers,
    equipment, force-vector classification; the spine of the library). *Tier T2/T3 (curated
    reference). License: read for facts, do not republish text.*
  - **Evidence-based exercise guides** — **Stronger By Science** (Nuckols et al.) exercise &
    "how to train muscle X" articles; **Renaissance Periodization** (Israetel/Hoffmann) exercise
    technique guides + "best exercises" hypertrophy series; **MASS Research Review** exercise pieces.
    *Tier T2 (expert consensus, well-sourced).*
  - **Biomechanics / strength-curve / mechanism** — **Chris Beardsley** (resistance profiles, active
    vs passive tension, length-tension, regional/fiber recruitment, what biases a head). *Tier T2/T3
    mechanistic.* — these drive `regional_bias`, SFR reasoning, and substitution caveats.
  - **Practitioner library / "best exercise for X" with rationale** — **Jeff Nippard** (exercise
    library + tier lists with mover & ROM rationale), and corroborating EMG/biomech reviews. *Tier T3
    practitioner; use to cross-check ExRx mover lists, not as sole authority.*
  - **Primary biomech/EMG where it settles a dispute** — PubMed/PMC EMG & moment-arm studies, only
    reference-chased when two authorities disagree on a prime mover or a regional-bias claim. *T0/T1.*
- [ ] For each: `tier` (T0–T3), `license_note`, `parser`. Skim once; drop redundancy.
- [ ] **Exhaustive width:** full sweep across all six equipment classes and every pattern; reference-
      chase one hop out of ExRx/SBS/Nippard exercise indexes and out of any Beardsley claim used to set
      a `regional_bias` or `equivalence_score`, until the source set stops yielding new movers/edges.
- [ ] **Verify:** `uv run python -m ingest list --domain exercise --subdomain movements` shows N rows;
      eyeball that every equipment class and every pattern has ≥1 authority covering it.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain exercise --subdomain movements` → fills
      `sources`/`documents`, caches raw under `_db/raw/exercise/movements/<id>.html` (gitignored).
- [ ] `uv run python -m ingest load --domain exercise` (close the motherduck MCP first — read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Verify:** doc count + mean length match expectations; spot-check 3 random ExRx/SBS docs render
      as clean markdown (mover tables and equipment fields survived parsing).

## Phase C — Extract → entity tables

Goal: structured rows for the lookup-able entities — patterns, the library, and the swap graph.

- [ ] **`movement_patterns` first.** Author the closed pattern set with `plane`, `description`, and
      `antagonist_pattern_id` (horizontal-pull↔horizontal-push, vertical-pull↔vertical-push,
      hip-hinge↔?, squat-pattern, lunge/split-squat, plantarflexion-knee-straight vs -knee-bent, knee
      flexion vs extension, elbow flexion supinated/neutral/pronated vs elbow extension, shoulder
      horizontal abduction (rear-delt) vs adduction, hip abduction, anti-extension / anti-rotation /
      anti-lateral-flexion core, loaded carry). This taxonomy is the schema the rest hangs on.
- [ ] **`exercises` next.** For each: id `exercise.move.<equipment>-<name>`, `movement_pattern_id`,
      `primary_muscle_ids`/`secondary_muscle_ids` (FK → anatomy's `muscles`), `equipment[]`,
      `is_compound`, `is_unilateral`, `force_vector`, `rom_notes`, **`grip_demand`**
      (none|low|moderate|high — set high for crush-grip / weight-hanging / heavy pulls, this drives the
      pinky bypass), `joint_stress[]`, `stimulus_to_fatigue` (SFR), `regional_bias`,
      `default_rep_range`, `default_rir`, `tempo`, `cues`, **`fixed_or_dynamic`** (fixed-core for the
      consistent compounds the mesocycle progresses; dynamic-accessory for the rotating high-SFR
      isolations). Cover **all six equipment classes** so every machine move has a free-weight/cable
      sibling to swap to.
- [ ] **`substitutions` last.** For every machine-dependent exercise, emit ≥1 edge to a swap that
      `shares_pattern` and `shares_primary_mover`, with `equipment_removed[]` / `equipment_required[]`,
      `equivalence_score` (0..1), and a concrete `caveat`. Add the **grip-bypass family**: for every
      `grip_demand = high` exercise, an edge with `reason = injury-spare` to a cable-cuff / strap /
      chest-supported / machine-loaded variant that drops the grip load.
- [ ] **Verify:** counts within the exhaustive order-of-magnitude (patterns ~22–30, exercises
      120–200, edges 150–260); **every** `machine`-tagged exercise has an outgoing `equipment-unavailable`
      edge and **every** `grip_demand=high` exercise has an outgoing `injury-spare` edge (run the SQL
      coverage check); sampled `primary_muscle_ids` resolve to real `muscles.id`; sampled rows have
      resolvable `source_ids`.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: the part a human couldn't get from one search — the **defensible substitution-equivalence
judgments** and the **load-bearing mover/regional-bias attributions**. Here the "fact" is *not* "row
exists"; it's *"swap B is a 0.85-equivalent of A for the same prime mover, and what you lose is X"* and
*"exercise A biases region/head Y."* These are claims about stimulus, and per the domain's
methodological rule they must **separate the mechanism (why the swap is close / why it biases Y) from
any effect-size assertion** — never assert "just as good" where the honest answer is "same pattern &
prime mover, but loses constant tension at the top / loses the lengthened-position load."

- [ ] Each fact carries: the statement (the equivalence or attribution), supporting/contradicting
      `source_ids`, and an evidence/confidence grade (mover lists agreed by ExRx+SBS+Nippard → high;
      a regional-bias claim resting on one Beardsley mechanism note → mechanistic/lower).
- [ ] **Exhaustive verification:** spawn **3–5 independent skeptics per load-bearing equivalence and
      per disputed mover/regional-bias claim**, each prompted to **refute** — e.g. "argue this cable
      swap is NOT equivalent to the machine version" / "argue this move does not bias the long head."
      Keep only majority-survivors; **record the dissent on the row** (lower the `equivalence_score`,
      sharpen the `caveat`, or flag the attribution as disputed). Priorities to adversarially test:
      (a) every grip-bypass swap actually preserves the prime-mover stimulus (a strap on a deadlift
      keeps the hinge; a cable-cuff lateral keeps the medial delt — verify); (b) "machine = free-weight
      equivalent" edges where stability/resistance-profile differs most (pec-deck vs DB fly, leg-press
      vs squat, hack-squat vs back-squat, lying-leg-curl vs seated — seated biases the lengthened
      position); (c) any single-source regional-bias or prime-mover call.
- [ ] **Verify:** sample equivalence facts re-derive from their cited sources; every recorded caveat
      is traceable to a mechanism (resistance profile, stability, ROM/length, moment arm); disputes are
      recorded with a softened score, **not** silently upgraded to "just as good."

## Phase E — Relationships → typed graph

- [ ] Wire `targets` (exercise→muscle, into `relationships` mirroring `primary_muscle_ids`),
      `substitutes` (exercise→exercise, mirroring `substitutions`), `antagonist-of` (pattern↔pattern),
      and `evidenced-by` (exercise/edge→source). Cross-domain: `targets` edges resolve into `anatomy`'s
      `muscles`; `gated-by` / `spared-by` stubs toward `constraints` (the pinky rows); `prescribed-as`
      stubs toward `programming` for default rep/RIR. Wire these **as discovered**, not in a final pass.
- [ ] **Verify:** a graph walk from a seed (e.g. `exercise.move.machine-chest-press`) reaches ≥3
      sensible hops: → `substitutes` → `targets` muscle → `antagonist-of` pattern → back to an
      antagonist exercise. Confirm no muscle in `anatomy` is reachable by **zero** `targets` edges
      (that's the coverage signal the generator depends on).

## On completion

- [ ] Update `STATUS.yaml` (phase → `done`, `updated:` date) and append a session entry to
      `PROGRESS.md` (what was extracted, counts, any disputed swaps, open forks left for `routine`).

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- `domains/exercise/anatomy/` — **read its `muscles` ids first**; `primary_muscle_ids` must resolve.
  Copy its `extract/*.json` shape as the starting point for this leaf's `exercises.json`.
- `domains/exercise/schema.exercise.sql` — the authoritative column list for `exercises`,
  `movement_patterns`, `substitutions` (match field names exactly).
- Sibling leaves' `extract/` once populated — reuse the source-id and tiering conventions.

## Open questions

- **Library breadth:** cap at ~120 high-value core exercises, or push to ~200 including every cable /
  unilateral / machine variant? (Affects substitution density — more variants = richer swap graph.)
- **"Machine-dependent" definition:** pin-loaded selectorized only, or also cable-stack and
  smith-machine? (Drives which exercises *require* an `equipment-unavailable` edge.)
- **Equipment inventory:** which machines/cables/cuffs/straps the lifter actually owns is unknown here;
  substitution targets are authored generically now and **filtered** by the `constraints` leaf later —
  confirm this division of labor before `routine` consumes the graph.
- **Antagonist pairing for hip-hinge / core anti-* patterns:** some patterns have no clean single
  antagonist (carries, anti-rotation). Decide whether `antagonist_pattern_id` is nullable for those or
  mapped to a conventional pairing.
