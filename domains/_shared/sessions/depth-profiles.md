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

## How depth is consumed

- A leaf's research session reads `depth` from `STATUS.yaml` and sizes its fan-out accordingly.
- When a phase runs as a Workflow, depth sets finder-pool width and verify-vote count.
- Bumping a leaf from `standard` to `exhaustive` later is a valid, resumable operation — see
  `extend-playbook.md`.
