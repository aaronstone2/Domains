# Plan — `exercise/constraints`

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> Set **depth** (`scout` | `standard` | `exhaustive`) in `STATUS.yaml` — it governs how wide each
> phase fans out and how hard the gold layer (Phase D) is verified. See
> `domains/_shared/sessions/depth-profiles.md`. The re-engagement contract (how a future session
> resumes this leaf) is `domains/_shared/sessions/extend-playbook.md`. **This leaf is `standard`.**

## Context

Why this leaf exists: `constraints` is the **personal gate layer** that sits between the evidence-driven
exercise library and the generator. The research leaves (`anatomy`, `movements`, `programming`,
`techniques`) describe what is *optimal in general*; this leaf encodes what is *permitted for THIS
lifter* and what to **substitute** when a prescription violates a personal limit. It must serve two
query shapes for the `routine` generator: (1) **gate** — "given exercise X, is it blocked / penalized
for this lifter, and why?" and (2) **inject** — "if X is gated, what concrete `substitute_exercise_ids`
preserve the stimulus while dropping the offending demand?" The load-bearing case is the lifter's
**recurring left-pinky jam**: a grip-mediated injury that fires on `grip-load` / `hanging` /
`crush-grip` / `weight-hanging` patterns (e.g. calf raises holding DBs, suitcase box step-ups, overhead
DB extensions where the bell hangs off the pinky side). The leaf encodes that injury as a hard
`constraints` row with matchable `triggers`, the affected examples, a graded `workaround` (cable wrist
cuffs / lifting straps / machine-loaded variants), and explicit substitute IDs. It also lays down the
**general template** for adding future constraints (equipment gaps, other injuries, mobility,
preferences) so the personal layer is extensible without re-deriving the schema each time.

Beyond the single injury, this leaf owns the **grip-bypass accessory knowledge** — the decision logic
for *straps vs hooks vs wrist-cuffs vs machine-loaded*, and when each is the right bypass — because the
generator's substitution choice is only as good as the rule that says "this is a grip-limited movement;
route it through a cuff, not a strap." That is a small evidence/practitioner-knowledge layer, not a
literature meta-analysis, which is why the depth is **standard**, not exhaustive.

How it composes: this leaf is a **consumer of `movements`** (it references `exercise.move.*` and
`substitutions` rows by ID) and a **producer for `routine`** (the generator reads `constraints` to gate
and inject). It draws `triggers` vocabulary from the `exercises.grip_demand` / `joint_stress` columns
defined in `movements`, and its `substitute_exercise_ids` should resolve to real rows that `movements`
created (preferably ones already carrying a `substitutions` edge with `reason='injury-spare'`). It is a
**leaf of the personal layer**, parallel to (not blocking) the four research leaves; it can be authored
before `movements` is fully populated by using *placeholder* exercise IDs and reconciling in Phase E.
Cross-domain links (to the `health`/`mobility` domain if one exists, or to `anatomy` for the
`affected_muscle_ids` of pinky-loaded grip work — the forearm flexors / FDP) are wired in Phase E as
discovered, not deferred.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the domain-specific tables in `domains/exercise/schema.exercise.sql`.

This leaf **owns** exactly one domain table and contributes to two base tables. Row targets at
`standard` depth (most leaves):

| Table | This leaf's fill | Row target (`standard`) | Notes |
|---|---|---|---|
| `constraints` | **owns** — the whole personal gate layer | **8–14 rows** | 1 hard injury (left-pinky jam) + 1 documented general grip-bypass "pattern" constraint + 3–6 equipment-gap placeholder rows + 2–4 template/exemplar rows for future injuries/mobility/preference kinds |
| `sources` | grip-accessory + injury-spare guidance | **6–12 rows** | seed-doc grip section + 1 hop of practitioner/clinical references; T2–T3 mostly |
| `documents` | fetched text for the above | = source count | standard ingest |
| `relationships` | `gates`, `substitutes`, `evidenced-by`, `affects` edges | **15–30 edges** | constraint→exercise (`gates`), constraint→substitute (`substitutes`), constraint→source (`evidenced-by`), constraint→muscle (`affects`) |
| `studies` | — (not a study-heavy leaf) | 0–2 | only if a clinical source on grip/finger injury merits per-paper metadata |
| `claims` | a few practitioner claims about bypass choice | **0–4 rows** | optional: e.g. "straps reduce grip stimulus but not pinky compression" — graded T3, kept light at this depth |

Tables this leaf does **not** fill: `muscles`, `exercises`, `movement_patterns`, `substitutions`,
`training_variables`, `set_structures` (owned by the research/movement leaves; this leaf only
*references* their IDs).

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — sitemaps, ToCs, repo
trees, the authorities; (2) **Plan** agent(s) design the per-leaf extraction — which sources, which
tables, what verification looks like; (3) `AskUserQuestion` on high-leverage forks (scope, depth);
(4) write this PLAN + `STATUS.yaml`; (5) `ExitPlanMode`.

For THIS leaf the meta-research is light (depth=standard) and has a specific shape:

1. **Read the seed doc's grip-accessory section** (the Gemini deep-research doc) and lift its concrete
   grip-bypass guidance — this is the primary authority and should be skimmed before any web fetch.
2. **Confirm the trigger vocabulary** matches what `movements` writes into `exercises.grip_demand` and
   `joint_stress`, so `constraints.triggers` actually matches against real exercise rows. If `movements`
   isn't authored yet, **freeze a canonical trigger string set** here (`grip-load`, `hanging`,
   `crush-grip`, `weight-hanging`) and record it in Open questions so `movements` adopts it.
3. **One `AskUserQuestion` fork** worth raising: whether to model the left-pinky jam as a single
   constraint with many triggers, or split per-trigger — and how aggressive the gate should be
   (hard-block vs penalize-and-prefer-substitute). Default assumption if unasked: **single constraint,
   severity=`moderate`, gate = prefer-substitute (not hard-block)** so the generator can still use a
   gripped movement with a cuff rather than dropping it entirely.

The irreducible work here is **Phase D** — turning "my pinky hurts on grip stuff" into a *precise,
matchable, substituting* rule whose bypass advice is correct (a strap does NOT spare a crush-grip; a
cuff or machine does). Everything before D is mechanical.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to this leaf's two topics: **grip-bypass
accessories** and **injury-spare lifting around a finger/grip limitation**.

- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` (or a leaf-local `sources.yaml`).
- [ ] For each: `tier` (T0–T3 = evidence/authority grade), `license_note`, `parser`. Skim once; drop redundancy.
- [ ] Width scales with depth (`standard`: ~6–12 sources, ref-chase 1 hop). Candidate source **categories** + named authorities:
  - **Seed doc (primary)** — the grip-accessory section of the Gemini deep-research doc. *T2/T3.*
  - **Grip-accessory practitioner guidance** — how straps / hooks / figure-8s / wrist-cuffs differ and
    when each is indicated (Stronger By Science / MASS practical articles, Jeff Nippard / Israetel
    technique explainers, reputable strength-coach writeups). *T2–T3.*
  - **Injury-spare / "lifting around a tweaked finger" guidance** — practitioner + light clinical:
    load-management around a hand/finger injury, cable-cuff and machine-loaded substitution patterns
    (Barbell Medicine / Jordan-Feigenbaum-style "train around it" content, Squat University for joint
    sparing). *T2–T3.*
  - **Anatomy/mechanism of the trigger (one hop)** — why hanging/crush-grip load the pinky-side digits
    (FDP/FDS, ulnar-side grip, the 5th-digit lever) — enough to justify *which* bypass works. *T3.*
- [ ] **Verify:** `uv run python -m ingest list --domain exercise --subdomain constraints` shows N rows; eyeball pass.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain exercise --subdomain constraints` → fills `sources`/`documents`, caches raw under `_db/raw/exercise/constraints/`.
- [ ] `uv run python -m ingest load --domain exercise` (close the motherduck MCP first — it holds a read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Verify:** doc count + mean length match expectations; spot-check 3 docs render as clean markdown; confirm the grip-accessory section parsed intact.

## Phase C — Extract → entity tables

Goal: structured `constraints` rows (the personal gate layer) plus the general template for future
additions.

- [ ] Extract into `extract/constraints.json`, then `ingest load`. Required rows:
  - **`exercise.constraint.left-pinky-jam`** (the load-bearing row):
    `kind=injury`, `severity=moderate`, `active=true`,
    `triggers=['grip-load','hanging','crush-grip','weight-hanging']`,
    `affected_exercise_ids` = the named examples (DB calf raises, suitcase box step-ups, overhead DB
    extensions, plus any farmer-carry / dead-hang / heavy-DB-row rows from `movements`),
    `affected_muscle_ids` = forearm-flexor / grip muscle IDs from `anatomy` (placeholder OK),
    `workaround` = "route grip load off the pinky: cable wrist cuffs (best — removes hand grip
    entirely), lifting straps (good for pulls, does NOT spare crush-grip), figure-8s, or machine-loaded
    / fixed-handle variants; avoid free DBs that hang off the 5th digit and dead-hangs",
    `substitute_exercise_ids` = concrete swaps (machine/cuffed variants of each affected exercise),
    `source_ids` = the grip-accessory + injury-spare sources.
  - **`exercise.constraint.grip-bypass-pattern`** (a general `kind=preference`/`mobility` knowledge row,
    or modeled as notes on the injury row): encodes the **bypass decision rule** — cuff vs strap vs hook
    vs machine, keyed to whether the movement is a *pull* (strap OK), a *hold/carry/hang* (crush-grip —
    cuff/machine only), or an *isolation hanging a bell off the pinky* (machine/cuff).
  - **3–6 `kind=equipment-gap` placeholder rows** — one per likely-missing machine class (e.g.
    `exercise.constraint.no-leg-press`, `.no-cable-stack`, `.no-hack-squat`), `active=false` until the
    inventory is captured, each with a `workaround` pointing at the substitution the generator should
    prefer. These are placeholders by design (see Open questions).
  - **2–4 template/exemplar rows** demonstrating the other `kind`s (`mobility`, `preference`) so the
    schema's full surface is exercised and future additions have a copy-paste shape.
- [ ] **Verify:** counts within order-of-magnitude (8–14 rows); every `substitute_exercise_id` and
      `affected_exercise_id` either resolves to a real `exercises` row or is flagged as a placeholder;
      `triggers` strings match the frozen canonical vocabulary.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: the personal layer is only useful if its **gates are correct and its substitutions actually spare
the injury**. For this leaf the "gold" facts are: (a) each constraint's trigger→affected-exercise match
is right, and (b) each prescribed bypass genuinely removes the offending demand.

- This is the constraints analogue of `failure_modes`: a personal rule → what it gates → the spare
  → the evidence/mechanism that the spare works → grade.
- [ ] Each constraint-fact records: the statement (e.g. "lifting straps spare grip endurance but do NOT
      spare a crush-grip / pinky-compression load — use a cuff or machine"), supporting/contradicting
      `source_ids`, and an evidence grade (mostly T3 practitioner/mechanistic here; T2 where a coach
      consensus exists). Keep the **evidence claim** (what a strap/cuff mechanically does) separate from
      the **practical claim** (why you'd still pick the cuff) per the domain methodological rule.
- [ ] **Verification scales with depth — this leaf is `standard` → single spot-check per claim.** For
      EACH bypass recommendation, run one adversarial check: prompt a skeptic to *refute* "this spare
      removes the pinky load." The known trap to catch: **straps reduce grip but a crush-grip / weight
      hanging off the pinky is not a grip-strength problem** — a strap can leave the pinky loaded, so the
      correct spare for crush-grip is a **cuff or machine**, not a strap. If the spot-check refutes a
      substitution, fix the `substitute_exercise_ids` / `workaround`, don't silently keep it.
      *(Note: the domain runs adversarial verification at `exhaustive`; at this leaf's `standard` depth a
      single documented spot-check per bypass claim is the contract, with dissent recorded on the row.)*
- [ ] **Verify:** sample constraint-facts re-derive from their cited sources; for the left-pinky row,
      confirm each affected exercise has at least one substitute whose bypass survived the spot-check;
      contradictions (e.g. "straps don't help crush-grip") are recorded in `notes`/`caveat`, not dropped.

## Phase E — Relationships → typed graph

- [ ] Wire edges in `relationships`:
  - constraint **`gates`** → each `affected_exercise_id` (the generator reads this to penalize/block).
  - constraint **`substitutes`** → each `substitute_exercise_id` (the inject path; mirror/relate to the
    `substitutions` rows `movements` created with `reason='injury-spare'`).
  - constraint **`evidenced-by`** → its `source_ids`.
  - constraint **`affects`** → `affected_muscle_ids` (grip/forearm muscles from `anatomy`).
  - cross-leaf: confirm each gated exercise's `substitutes` edge points at a movement that `movements`
    actually carries; if not, file the gap.
- [ ] **Verify:** a graph walk from `exercise.constraint.left-pinky-jam` reaches ≥3 sensible hops
      (constraint → gated exercise → substitute exercise → its prime mover/muscle), and the substitute
      drops the offending equipment/grip demand.

## On completion

- [ ] Update `STATUS.yaml` (phase → `done`, `updated:` date) and append a session entry to `PROGRESS.md`.
- [ ] Hand off to `routine`: confirm the generator can read `constraints` to gate+inject, and flag the
      still-open equipment inventory as a blocker for `routine` (not for this leaf).

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- `domains/exercise/movements/extract/` — copy the `exercises.json` / `substitutions.json` shape; this
  leaf's `substitute_exercise_ids` should resolve against those IDs, and `injury-spare` substitution
  edges may already exist there to reuse rather than re-create.
- `domains/exercise/anatomy/extract/` — for `affected_muscle_ids` (forearm flexors / grip muscles).
- Sibling leaves' `extract/*.json` for JSON conventions.

## Open questions

- **Equipment inventory not yet captured.** The `kind=equipment-gap` rows are placeholders
  (`active=false`) until the lifter's actual machine/accessory list is recorded (including whether cable
  wrist-cuffs and lifting straps are *owned*). This blocks `routine`'s substitution choices, not this
  leaf's structure. Resolve before `routine`.
- **Non-pinky injuries / mobility limits unknown.** Only the left-pinky jam is documented. Template rows
  exist for `mobility`/`preference`/other `injury` kinds, but the actual content needs the lifter's full
  history. Capture in a follow-up interview.
- **Trigger vocabulary must be frozen and shared with `movements`.** Canonical set proposed here:
  `grip-load`, `hanging`, `crush-grip`, `weight-hanging`. `movements` must write these exact strings into
  `exercises.grip_demand` / a matchable column, or the gate won't fire. Confirm or reconcile.
- **Gate semantics fork (deferred to `routine`/user):** hard-block vs prefer-substitute, and per-trigger
  vs single-constraint modeling. Default taken here: single constraint, `severity=moderate`,
  prefer-substitute. Revisit if the generator needs finer control.
- **Pinky-side mechanism depth:** whether to record the FDP/5th-digit mechanism as a `claims`/`concepts`
  row or leave it as `notes`. Left as notes at `standard`; promote if `routine` needs to reason about it.
