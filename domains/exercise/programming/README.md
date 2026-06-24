# `exercise/programming`

Leaf of the `exercise` domain — the **dose layer** of the training-science corpus. See `PLAN.md` for
the phase plan and `PROGRESS.md` for the running log. **Depth: `exhaustive`.**

## What it owns

The numeric knobs the `routine` generator turns when it writes a prescription, captured as cited,
parameterized rows:

- **Volume** — sets/muscle/week (MV/MEV/MAV/MRV landmarks), per-session set ceiling, the junk-volume tail.
- **Intensity** — %1RM and goal-specific rep ranges (strength ~1–6 @ ≥80%; hypertrophy ~5–30 near failure).
- **Frequency** — sessions/muscle/week, derived from weekly-volume ÷ session-ceiling.
- **Proximity-to-failure (RIR)** — hypertrophy 0–3, strength ~1–5; the distinct *cost* of training to failure.
- **Progressive overload** — the load > volume > density progression hierarchy (a practitioner ordering).
- **Periodization** — mesocycle volume-ramp toward MRV, deloads, autoregulation.

## Tables it fills

`training_variables` (**≈90–140 rows** — primary; scope × goal × population with min/max/recommended +
unit + evidence_grade), `claims` (**≈30–45** — the gold layer), `studies` (**≈25–40** per-paper
metadata), plus shared `sources`/`documents`/`concepts`/`relationships`.

## The one rule

Separate the **effect** claim (what volume-/RIR-/frequency-equated studies show — high grade) from the
**practical/mechanistic** claim (why you'd still pick X — fatigue, time, skill — lower grade). Never let
"equal growth" be reported as "better." The seed Gemini doc conflates these (e.g. RPT "far superior");
this leaf's gold layer exists to de-conflate them, and every Phase-D refuter is told to flag the trap.

## Authorities

T0 metas (Schoenfeld/Krieger volume, **Refalo** proximity-to-failure, Schoenfeld/Grgic/Krieger
frequency, load metas), T1 RCTs in trained lifters, T2 syntheses that reconcile them (**Stronger By
Science / MASS**, **Helms** *Muscle & Strength Pyramids*, **RP / Israetel** MEV–MRV landmarks,
**Henselmans**), T3 mechanism explainers (effective reps, SRA). Load-bearing numbers anchor to a T0
meta; Israetel landmarks scaffold `weekly_sets` only when graded against the metas.

## Verification (Phase D, exhaustive)

3–5 independent skeptics per claim, each prompted to refute against the literature; majority-survivors
kept, dissent recorded in `nuance`, `agreement_score` = fraction not refuting. Disputed/refuted claims
are kept, never dropped. Load-bearing claims (volume band, proximity-to-failure, frequency) get all 5.

## Feeds

`routine` (reads every knob + the failure-cost guardrail) and `techniques` (set structures *deliver* a
dose defined here). Draws on `anatomy` (muscle scopes for `weekly_sets`). Interacts with `constraints`
(session ceiling × recovery; failure-cost × the left-pinky grip ceiling).
