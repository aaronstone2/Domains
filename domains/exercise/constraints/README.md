# `exercise/constraints`

The **personal gate layer** of the `exercise` domain. Where the research leaves (`anatomy`,
`movements`, `programming`, `techniques`) say what's optimal *in general*, this leaf says what's
permitted for **this lifter** — and what to **substitute** when a prescription violates a personal
limit. The `routine` generator reads it to **gate** exercises (block/penalize) and **inject** swaps.

Depth: **standard**. See `PLAN.md` for the phase plan, `PROGRESS.md` for the running log,
`STATUS.yaml` for phase state.

## What it owns

- **`constraints`** (the only domain table this leaf fills): the personal rules — injuries, equipment
  gaps, mobility, preferences — each with matchable `triggers`, `affected_exercise_ids`, a `workaround`,
  and `substitute_exercise_ids`.
- Plus base-table contributions: a few `sources`/`documents` (grip-accessory + injury-spare guidance)
  and `relationships` edges (`gates`, `substitutes`, `evidenced-by`, `affects`).

It only **references** (never writes) `exercises`, `substitutions`, `muscles`, and the programming
tables — those belong to the research/movement leaves.

## The load-bearing constraint

**Recurring left-pinky jam** — `kind=injury`, fires on `grip-load` / `hanging` / `crush-grip` /
`weight-hanging` movements (DB calf raises, suitcase box step-ups, overhead DB extensions, dead-hangs,
heavy DB rows). Workaround: route grip load off the pinky — **cable wrist-cuffs** (best, removes hand
grip entirely) or **machine-loaded variants**; lifting straps help *pulls* but do **not** spare a
crush-grip. The leaf also encodes the general **bypass decision rule** (cuff vs strap vs hook vs
machine) and the **template** for adding future constraints.

## Row targets (standard)

| Table | Target |
|---|---|
| `constraints` | 8–14 (1 injury + 1 bypass-pattern + 3–6 equipment-gap placeholders + 2–4 templates) |
| `sources` / `documents` | 6–12 |
| `relationships` | 15–30 edges |
| `claims` | 0–4 (optional, T3) |

## Gold-layer focus

Each prescribed bypass must **actually spare the injury**. At `standard` depth: one adversarial
spot-check per bypass claim, dissent recorded. Key trap to catch: a **strap reduces grip but not
pinky compression** — crush-grip spares need a **cuff or machine**, not a strap.

## Authorities

Grip-accessory section of the seed (Gemini) doc; practitioner grip-bypass guidance (SBS/MASS, Nippard,
Israetel); injury-spare "train around it" content (Barbell Medicine, Squat University); light
mechanism (FDP / 5th-digit / ulnar-grip) for *why* a given bypass works.

## Open items (see PLAN)

- **Equipment inventory** not yet captured → equipment-gap rows are placeholders (`active=false`);
  blocks `routine`, not this leaf.
- **Non-pinky injuries / mobility** unknown → template rows only until a fuller interview.
- **Trigger vocabulary** (`grip-load`, `hanging`, `crush-grip`, `weight-hanging`) must be frozen and
  shared with `movements` so the gate actually matches.
