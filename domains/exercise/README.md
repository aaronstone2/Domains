# `exercise` domain

A science-backed, queryable **algebra of training facts** — anatomy, the movement library,
programming variables, set-structure techniques, an adversarially-verified evidence layer, and a
personal constraints layer — built to **generate** an optimal Push/Pull/Legs routine (both a
ready-to-run static loop and a dynamic periodized mesocycle) where every prescription cites the
evidence and respects the lifter's actual equipment and injuries.

This is the first domain authored under the generalized, extensible corpus engine. Depth: **exhaustive**
(full literature sweep + adversarial verification — see `domains/_shared/sessions/depth-profiles.md`).

## Leaves

| Leaf | Covers | Fills (beyond base tables) |
|---|---|---|
| `anatomy` | every trainable muscle/head, its actions, planes, length bias | `muscles` |
| `movements` | the exercise library + movement patterns + **substitutions** | `exercises`, `movement_patterns`, `substitutions` |
| `programming` | volume, intensity, frequency, proximity-to-failure, overload, periodization | `training_variables`, `claims` |
| `techniques` | set structures: RPT, pyramids, straight, drop, rest-pause, myo-reps | `set_structures`, `claims` |
| `constraints` | injuries, equipment gaps, grip-bypass — the personal layer | `constraints` |
| `routine` | the **generator**: consumes all leaves → static loop + dynamic mesocycle | (synthesis; reads everything) |

## Domain-specific schema

`schema.exercise.sql` declares: `muscles`, `movement_patterns`, `exercises`, `substitutions`,
`training_variables`, `set_structures`, `claims`, `studies`, `constraints`. Papers live in the base
`sources` table (tier = evidence grade); cross-entity edges live in `relationships`.

See `PLAN.md` for the strategy and sequencing, `PROGRESS.md` for the running log.
