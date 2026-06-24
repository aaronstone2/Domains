# Plan — `exercise` domain (strategy)

> Domain-level strategy. Each leaf has its own `PLAN.md` (executed in a plan-mode session) and
> `STATUS.yaml`. This file is the brief they all serve. Depth: **exhaustive** for the four research
> leaves; the personal + synthesis leaves are lighter. See
> `domains/_shared/sessions/{depth-profiles,extend-playbook}.md`.

## Goal

A queryable **algebra of training facts** that can **generate** the optimal Push/Pull/Legs routine —
a ready-to-run static loop **and** a dynamic periodized mesocycle — where every prescription cites the
evidence, hits **every** muscle, and respects the lifter's actual **equipment** and **injuries**.

The deliverable is not a document; it's a corpus + a generator. The "paper" is rendered from the
corpus (like the debug harness renders from its corpus), so it stays auditable and regenerable when
equipment, constraints, or the evidence change.

## The methodological commitment (why a corpus, not one deep-research doc)

The seed for this work — a Gemini deep-research doc — is good but **flattens evidence grade**. It
says, correctly, that volume-equated pyramid / reverse-pyramid / straight sets yield *statistically
similar* hypertrophy, then argues reverse-pyramid is *"far superior."* Both are true (equal growth,
better fatigue-management) but the conflation is exactly the failure mode the corpus fixes. So the
gold layer (`claims`) **separates two things that prose blurs**:

- the **equivalence/effect claim** — what the literature shows when volume is matched (high grade), and
- the **practical/mechanistic claim** — why you'd still pick X (lower grade, fatigue/time/skill).

Every claim carries a `verdict` (supported / equivalent / disputed / refuted), the `nuance` (the
recorded dissent), an `evidence_grade`, and an `agreement_score` from adversarial verification.

## Evidence tiering (T0–T3 = evidence grade, not just "trust")

| Tier | Meaning | Examples |
|---|---|---|
| **T0** | meta-analysis / systematic review | Schoenfeld volume meta, Refalo proximity-to-failure meta-regression |
| **T1** | RCT in trained subjects | volume-equated pyramid RCTs, RIR vs failure RCTs |
| **T2** | expert consensus / textbook | Helms, Nuckols (Stronger By Science / MASS), RP/Israetel, Henselmans |
| **T3** | mechanistic / high-quality practitioner | mechanism explainers, well-sourced blogs |

Richer per-paper metadata (design, n, population, training status, duration, finding) lives in the
`studies` table keyed to `sources`.

## Leaves and dependency order

```
anatomy ─┐
         ├─> movements ─┐
         │              ├─> routine (generator: static loop + dynamic mesocycle)
programming ─> techniques ┤
                          │
constraints ──────────────┘   (personal layer: gates exercises, injects substitutions)
```

1. **anatomy** (exhaustive) — every trainable muscle/head: actions, planes, joints, length bias
   (gastroc knee-straight vs soleus knee-bent), antagonists. Fills `muscles`. This is the
   **"hit EVERY muscle" coverage backbone** — the gap analysis runs against it.
2. **movements** (exhaustive) — the exercise library: prime/secondary movers, equipment, movement
   pattern, ROM, grip demand, SFR, regional bias, fixed-core vs dynamic-accessory. Fills `exercises`,
   `movement_patterns`, and the first-class **`substitutions`** (the "no-machine swap" requirement:
   a swap shares pattern + prime mover but drops the missing equipment, with an equivalence score and
   the caveat of what's lost).
3. **programming** (exhaustive) — volume (sets/muscle/week), intensity (%1RM, rep ranges), frequency,
   proximity-to-failure (RIR), progressive-overload hierarchy, periodization. Fills `training_variables`
   (parameterized, cited knobs) + `claims`.
4. **techniques** (exhaustive) — set structures: reverse-pyramid, crescent pyramid, straight sets,
   drop sets, rest-pause, myo-reps. Fills `set_structures` + `claims`.
5. **constraints** (standard) — the personal layer: injuries (the recurring left-pinky jam on
   grip-load / hanging / crush-grip movements), equipment gaps, mobility, preferences. Fills
   `constraints`, which **gate** exercises and **inject** substitutions into the generator.
6. **routine** (synthesis) — the generator. Consumes every leaf: builds the PPL loop, runs the muscle
   coverage/volume gap-analysis, applies constraints + equipment, and emits the static loop and the
   dynamic mesocycle (reverse-pyramid on fixed cores, 4–6 wk accessory rotation, volume waving,
   deloads). Every cell cites a `claims`/`training_variables` row.

## Personal context to encode (from the lifter's logs)

- **Recurring left-pinky jam** on hanging / crush-grip / weight-hanging movements (calf raises holding
  DBs, suitcase box step-ups, overhead DB extensions) → a hard `constraints` row with grip-bypass
  workarounds (cable wrist cuffs, lifting straps, machine-loaded variants).
- **Under-stimulated back & core** (rows are the only real back driver; ab work skipped) → coverage
  gap the generator must close (RDL/hip-hinge, loaded multi-planar core).
- **Failure on compounds + heavy drop-set use** (Smith-bench failure singles) → claims layer should
  surface that failure belongs on isolation, with RIR buffers preserved on compounds.
- Equipment inventory (machines actually available, whether cable cuffs/straps are owned) feeds the
  generator's substitution choices — to be captured into the `constraints`/profile before `routine`.

## Source strategy (Phase A across the research leaves)

Multi-modal sweep, not a single angle: by-authority (Schoenfeld, Helms, Nuckols/SBS+MASS, RP,
Henselmans), by-meta-analysis (PubMed/PMC volume, proximity-to-failure, frequency, variation), by-topic
(each training variable + technique), and reference-chasing the Gemini doc's 51 citations one hop out.
De-dupe, tier, license, then ingest. Verification is adversarial at the gold layer (see depth-profiles).

## Cross-leaf contracts (resolved from the Session-0 consistency audit)

These bind the leaves so shared tables don't collide or drift. Honor them at execution time.

- **Pinky gate join key (G1).** `constraints.triggers` (tag strings: `grip-load`, `hanging`,
  `crush-grip`, `weight-hanging`, …) match against the new `exercises.grip_pattern_tags[]` column via
  `list_has_any` — *not* against the `grip_demand` ordinal (which only encodes severity). `movements`
  MUST populate `grip_pattern_tags` from this exact vocabulary; `constraints` owns the vocabulary list.
  This is what makes the pinky constraint actually fire.
- **`studies` source-of-truth (S1).** PK is `source_id`; multiple leaves cite the same paper.
  `programming` authors the shared method/effect-size papers; other leaves reference the same
  `source_id` and only insert a `studies` row for papers unique to them. Loads are upsert
  (first-writer-wins), so no crash — but don't author conflicting metadata for a shared paper.
- **Rep/RIR/tempo authority (S2).** `exercises.default_rep_range` / `default_rir` / `tempo` are
  *advisory, exercise-intrinsic* defaults (e.g. calves → higher reps). The authoritative prescription
  is `programming.training_variables`; `routine` reconciles and `training_variables` wins.
- **`claims.category` namespace (O1).** Three leaves write `claims`. Partition the `category` vocab by
  writer: `anatomy-*` (anatomy, descriptive kinesiology only) · `volume|intensity|frequency|failure|
  overload|periodization` (programming) · `set-structure` (techniques). `routine` is read-only on
  `claims` (it must never re-flatten the effect-vs-practical split).
- **`muscles.id` freeze.** `anatomy` freezes the `exercise.muscle.<slug>` id namespace; `movements`,
  `programming`, `routine` reference it. Author anatomy first.

## Acceptance (domain-level)

- `muscles` covers every major trainable muscle/head with no anatomical gap.
- `exercises` has ≥1 substitution path for every machine-dependent movement.
- Every `training_variables` row and `claims` row resolves to ≥1 `source_id`; T0/T1 preferred for
  load-bearing claims.
- `routine` emits a static PPL loop + a dynamic mesocycle, each cell traceable to a fact, with the
  pinky constraint and equipment honored.

## Open questions

- Equipment inventory + any non-pinky constraints + target timeline (needed before `routine`; not
  before the research leaves).
- Harness consumer commands for exercise (`substitute`, `muscle`, `gaps`, `routine`, `why`) — design
  in the `routine` leaf once the data exists. Note: the harness's native `duckdb` node dep doesn't
  build on this machine (Node 25 / no MSVC); the corpus is fully usable via the duckdb CLI + motherduck
  MCP meanwhile, and the harness can move to `@duckdb/node-api` (prebuilt) when wired up.
