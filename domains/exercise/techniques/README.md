# `exercise/techniques`

Set-structure / intensity-technique leaf of the `exercise` domain. Covers **how the reps in a set are
arranged** once volume, load, and proximity-to-failure are fixed by `programming`: reverse-pyramid
(RPT), crescent/ascending pyramid, straight sets (double-progression), drop sets, rest-pause, myo-reps,
supersets, and cluster sets.

**Depth: `exhaustive`.** This is the leaf where the seed Gemini doc is most wrong, so its gold layer is
verified adversarially (N skeptics per claim, majority-vote, dissent recorded).

## What it fills

- **`set_structures`** (~14–20) — one row per structure/variant: `family`, `mechanism` (motor-unit /
  fatigue), `fatigue_cost`, `best_for`, `contraindications`, `evidence_grade`.
- **`claims`** (~18–28) — the gold layer. Every "X is superior" assertion split into an **effect claim**
  (volume-equated literature, high grade T0/T1) and a **practical claim** (fatigue/time/skill, lower
  grade T2/T3), each with `verdict`, `nuance`, `agreement_score`, cites.
- **`studies`** (~15–25), `concepts` (~12–18), plus `sources`/`documents`/`relationships`.

## The core correction

The seed doc correctly says volume-equated pyramid / RPT / straight sets give *similar* hypertrophy,
then calls RPT "far superior" — conflating **equal growth** with **better**. This leaf refuses the
conflation:

| Headline claim | Effect verdict (high grade) | Practical verdict (lower grade) |
|---|---|---|
| RPT vs straight/pyramid | **equivalent** hypertrophy, volume-equated | better fatigue-management (heavy set while fresh) |
| Crescent vs traditional pyramid | **equivalent** (Angleri 2017, trained men) | joint/warmup readiness |
| Drop sets vs straight | **equivalent** when volume-equated | win on **time-efficiency** only |
| Rest-pause / myo-reps | **disputed** for a growth edge | time-efficiency / effective-reps model (T3) |
| Cluster sets | **no hypertrophy edge** | power/velocity-maintenance (their real use) |
| Pre-exhaust supersets | **refuted** (doesn't shift the stimulus) | antagonist supersets buy work density |

Hard rule: no `claims` row may assert a hypertrophy edge from a non-volume-equated or untrained-subject
study — that evidence supports a *practical* claim only.

## Candidate authorities

Pyramid/RPT RCTs (Schoenfeld, Angleri 2017); drop-set reviews/RCTs (Coleman, Fink, Ozaki; Brook Bush
for mechanism); rest-pause/cluster (Prestes, Tufano); myo-reps / effective-reps (Fagerli; SBS/MASS
critiques); supersets/pre-exhaust efficiency (Iversen, Weakley); consensus (Stronger By Science + MASS /
Nuckols, Helms, Schoenfeld, RP/Israetel, Henselmans); plus a one-hop reference-chase of the seed doc.

## Composition

Stated relative to `programming` (volume/RIR anchors every "equated" claim) and `movements` (a structure
attaches to an exercise class). Feeds `routine` (the generator picks a structure per slot) and hard-links
to `constraints` (intensity-technique-on-compound vs failure-on-compounds; grip-loaded variants vs the
left-pinky jam).

See `PLAN.md` for the phase plan, `STATUS.yaml` for phase state, `PROGRESS.md` for the running log.
