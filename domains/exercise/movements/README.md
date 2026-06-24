# `exercise/movements`

The **exercise library and swap engine** of the `exercise` domain. Depth: **exhaustive** (load-bearing
— the `routine` generator selects, swaps, and orders every prescription out of these rows).

## What it produces

1. **Movement-pattern taxonomy** (`movement_patterns`, ~22–30) — the closed set of biomechanical
   patterns (horizontal/vertical push & pull, hip-hinge, squat, lunge/split-squat, plantarflexion
   knee-straight vs knee-bent, elbow flexion supinated/neutral/pronated, anti-rotation /
   anti-extension / anti-lateral-flexion core, hip abduction, loaded carry, …) with **antagonist
   pairings**, so the generator reasons about balance by pattern, not by exercise name.
2. **The exercise library** (`exercises`, ~120–200) across **all six equipment classes** (barbell,
   dumbbell, cable, machine, smith, bodyweight): prime/secondary movers (FK → `anatomy.muscles`),
   equipment, force vector, ROM, **`grip_demand`** (drives the left-pinky bypass), SFR, `regional_bias`,
   default rep/RIR, and the **fixed-core vs dynamic-accessory** tag the mesocycle rotates on.
3. **The substitution graph** (`substitutions`, ~150–260 edges) — the "no-machine swap" requirement:
   every machine-dependent move gets ≥1 swap that **shares pattern + prime mover** but **drops the
   missing equipment**, with an `equivalence_score` and an explicit `caveat` (what stimulus is lost);
   plus **grip-bypass** edges (cable wrist cuffs / straps / chest-supported / machine variants) for
   every `grip_demand = high` movement.

## Questions it lets the corpus answer

- "I have no [machine X] — what hits the same prime mover in the same pattern, and what do I lose?"
- "This move jams my pinky — give me an equivalent that bypasses crush-grip / weight-hanging."
- "Which exercises bias [region/head Y] of [muscle], and at what SFR?"

## Composition

- **Depends on `anatomy`** — every `primary_muscle_ids` / `secondary_muscle_ids` is a FK into
  `muscles`; author movers against anatomy's ids.
- **Underpins `routine`** (exercise selection + pattern/region gap-analysis + swap-graph walk) and
  **`constraints`** (pinky/equipment rows resolve `substitute_exercise_ids` and match `triggers`
  against `grip_demand`).

## The irreducible work (Phase D)

Not "row exists" — the **defensible equivalence and mover/regional-bias judgments**. Each
`equivalence_score` + `caveat` is a claim about *stimulus*, verified by 3–5 adversarial skeptics
prompted to refute it. Methodological rule: **separate mechanism from effect-size** — never assert "just
as good" where the honest answer is "same pattern & prime mover, but loses constant tension / loses the
lengthened-position load." Dissent lowers the score and sharpens the caveat; it is never silently
upgraded.

See `PLAN.md` for the full phase plan, `STATUS.yaml` for phase state, `PROGRESS.md` for the running log.
