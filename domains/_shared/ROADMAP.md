# Roadmap — the health system, and where its boundaries are

The corpus engine is domain-extensible (auto-discovered domains, per-domain `schema.<d>.sql`, the
extend-playbook, cross-domain `relationships` + `meta.*` views). That makes the long-term vision a
**federation of composable domains**, not one monolith. This file records the boundary decisions so
each future build stays clean.

## The dividing principle: *functional* vs *medical / diagnostic / fuel*

The `exercise` domain is the **training-stimulus engine**: given the body + limitations + equipment +
goals → the optimal thing to *do*. The line that keeps it bounded:

- **In scope (exercise):** "Can/should I do this movement, and if not, what instead?" — modeled
  *functionally* (what a limitation stops you doing), never diagnosed medically.
- **Out of scope (→ their own domains):** "What is medically wrong?", "What should I eat?",
  "What does my body composition say?"

## Current scope (built)

`exercise/{anatomy, movements, programming, techniques, constraints, routine}` — the training-stimulus
engine. `constraints` includes the **functional** handling of limitations: an exhaustive contraindication
library, a self-characterization **intake protocol** (what provokes it / severity / behavior / trend),
and a **red-flag screen** that triages "stop, see a professional" — triage, not diagnosis.

## Future composable domains (add via the extend-playbook; compose via `relationships`)

| Domain | Covers | Composes with `exercise` via |
|---|---|---|
| **`nutrition`** | energy balance, protein/macros, nutrient timing, supplements | training energy cost, protein for hypertrophy, peri-workout |
| **`assessment`** | DEXA / body comp, strength & movement testing, anthropometry, progress tracking | weak-point → exercise emphasis; goals → volume/phase |
| **`recovery`** | sleep, stress, HRV, SRA, deload triggers | autoregulation, frequency, deload cadence |
| **`health` / `medical`** | diagnosis pathways, which specialist, imaging, return-to-train | promotes a `constraints` red-flag into a referral; demotes when cleared |

Each is a separate folder + schema, researched with the same A→E pipeline, linked into the graph. None
is in scope now — `nutrition` in particular is explicitly deferred (premature until training is dialed).

## Boundary guardrail (safety)

The system **routes training around** functional limitations and **flags red-flags** that warrant
professional evaluation. It does **not** diagnose injuries, prescribe medical treatment, or replace a
physician/physiotherapist. Diagnostic/medical depth lives in the future `health` domain as refer-out
pathways, not as self-diagnosis.
