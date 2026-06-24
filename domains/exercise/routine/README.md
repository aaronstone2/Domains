# `exercise/routine`

**The generator leaf.** Synthesis, not a source sweep. It turns the `exercise` corpus into the actual
deliverable: a Push/Pull/Legs routine that hits **every** muscle, respects the lifter's real **equipment**
and **injuries**, and **cites a fact for every prescribed cell**. It mints no new training science — it
*composes* the five upstream leaves and proves each prescription back to an evidence-graded `claims` /
`training_variables` / `set_structures` row.

See `PLAN.md` for the full phase plan and `PROGRESS.md` for the running log.

## What it does (the algorithm)

1. **Gap analysis** — `muscles` vs Σ(`exercises` × sets) under the candidate split; flags any muscle below
   its target weekly sets. Surfaces the lifter's known **back + core** shortfall and closes it (hinge / row
   / loaded multi-planar core).
2. **Constraint gating** — drops or swaps any exercise matching an active constraint — notably the
   **left-pinky jam** on grip-load / hanging / crush-grip — injecting `substitutions` (cable wrist cuffs,
   straps, machine variants). Equipment gating prunes anything needing absent gear.
3. **Assemble PPL** — fixed cores on reverse-pyramid + compound RIR buffers; dynamic accessories on
   straight sets / myo-reps with a rotation tag. Failure lives on isolation, not compounds.
4. **Emit two artifacts** — a **static** ready-to-run PPL loop and a **dynamic** periodized mesocycle
   (RPT cores, 4–6-wk accessory rotation, volume waving, scheduled deloads). Every cell carries the
   relationship ids that prove it.

## Depth: `standard`

A synthesis leaf, so its phases are inverted. **A/B/C are near-degenerate** (it consumes already-ingested
sibling tables instead of fetching the web — B is a deliberate no-op). The weight is on **D** (assemble +
verify the routine) and **E** (the traceability graph). "Standard" verification = one **coverage spot-check**
(no muscle left under target) + one **adversarial self-consistency pass** (one skeptic hunting uncited cells,
un-gated exercises, missing equipment, and the corpus's signature failure mode — citing an *equivalent*-verdict
claim to justify a *superior* prescription). Not the 3–5-skeptic gauntlet the research leaves ran.

## Tables

- **Writes** (few): `relationships` (~120–200 — `prescribes`, `cited-by`, `closes-gap`, `gated-by`; the
  audit trail is the real output), `commands` (~5), `concepts` (~8–12), `config_keys` (~6–10),
  `failure_modes` (~6–10 generator self-checks).
- **Reads** (many, read-only): `muscles`, `exercises`, `movement_patterns`, `substitutions`,
  `training_variables`, `set_structures`, `claims`, `constraints`.
- The two artifacts render to `extract/routine.static.json` and `extract/routine.mesocycle.json`.

## Harness surface (the consumer commands this leaf defines)

| command | does |
|---|---|
| `harness substitute <ex> [--no-<equip>]` | swap an exercise off missing equipment / off the pinky, with equivalence + caveat |
| `harness muscle <m>` | exercises hitting a muscle, its volume + the claims behind it |
| `harness gaps` | muscles under target weekly volume in the current routine |
| `harness routine [--equipment ...]` | emit the static loop + mesocycle for the given inventory |
| `harness why <claim>` | walk a prescription back to the evidence that justifies it |

## Dependencies

Runs **LAST**, after all five research/personal leaves are `done` (`anatomy`, `movements`, `programming`,
`techniques`, `constraints`) **and** the lifter's **equipment inventory** is on file in
`constraints`/`config_keys`. No cross-domain links — inward-facing within `exercise`.
