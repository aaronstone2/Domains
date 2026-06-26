# Depth profiles — the research dial

Every leaf declares a **depth** in its `STATUS.yaml`. Depth is one knob that scales every phase at
once: how wide source discovery fans out, how completely the entity tables get filled, and — the part
that actually matters — **how hard each fact is verified before it's trusted.**

Pick depth per leaf, not per domain. A small personal leaf can be `scout` while the load-bearing
leaves of the same domain are `exhaustive`.

| Phase | `scout` | `standard` | `exhaustive` |
|---|---|---|---|
| **A — Survey** | ~10–20 sources, T1–T2 only | ~30–60 sources, ref-chase 1 hop | full sweep, all tiers, multi-hop reference-chasing until dry |
| **C — Extract** | headline entities only | all entity tables | all tables + every named entity in-scope |
| **D — Gold layer** | record claims, **no verification** | single spot-check per claim | **3–5 independent skeptics per claim, each prompted to refute; majority-vote, dissent recorded** |
| **E — Relationships** | skip | obvious edges | exhaustive in- and cross-domain edges |
| **Use when** | mapping a new area fast | most leaves | the leaves the final deliverable leans on |

## What "exhaustive verification" means concretely

This is the difference between *a research doc* and *an algebra of verified facts*. At `exhaustive`,
the gold layer (Phase D) does not just transcribe a claim like "reverse-pyramid training is superior."
It spawns several independent agents whose job is to **refute** the claim against the literature.
A claim becomes a trusted fact only if a majority fail to refute it — and the dissent (e.g. "meta-
analyses show *equivalent* hypertrophy when volume is matched; the advantage is fatigue-management,
not growth") is recorded on the fact itself. Claims that don't survive are kept with a `disputed`
verdict, never silently dropped.

This maps directly onto the orchestration patterns (loop-until-dry finders, N-vote adversarial
verify). Depth = how many finders and how many verify votes.

## Verification standards — not every claim earns trust the same way (Layer 6)

Depth sets *how hard* to verify; the claim's **`verification_standard`** sets *how*. Strict-refute
panels are right for interpretive claims but waste effort (and over-refute) on plain facts. Each claim
carries one of three standards, recalibrated mechanically by `ingest verify --domain <d>`:

| Standard | What it fits | How it's verified | Engine support |
|---|---|---|---|
| **descriptive** | a fact: a price, a funding amount, a measured number | **≥2-source cross-check** (agreement, not a refute panel) | wide Wilson CI until ≥2 concurring sources |
| **evaluative** | an interpretive/strategic judgement | **diverse-lens skeptic panel** (the exhaustive Phase-D refutation) | majority-survivor + recorded dissent |
| **predictive** | a claim about the future | **logged to `forecast_log`, Brier-scored when it resolves** | `ingest calibrate` tracks accuracy over time |

`ingest verify` also computes a **Wilson 95% confidence interval** (`confidence_low/high`) from the
agreement score and the *number* of cited sources — so a claim backed by one blog reads as `[0.1, 0.9]`
(honestly uncertain), not a falsely-precise point — and a **freshness/decay** flag (`stale`) when a
claim ages past its `decay_halflife_days`. Stale facts get re-verified, not silently trusted forever.

## How depth is consumed

- A leaf's research session reads `depth` from `STATUS.yaml` and sizes its fan-out accordingly.
- When a phase runs as a Workflow, depth sets finder-pool width and verify-vote count.
- Bumping a leaf from `standard` to `exhaustive` later is a valid, resumable operation — see
  `extend-playbook.md`.
