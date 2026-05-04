# `ecs/task-defs` — PROGRESS log

Per-leaf log; rolls up into `domains/ecs/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Status

Phase 1 (sources + documents) and Phase 3 (concepts/commands/config_keys/failure_modes/relationships) executed at the **ecs domain level** rather than per-leaf — the actual extraction sessions ingested all of `ecs.*` in a single pass for efficiency, then partitioned the data by source-id prefix where helpful.

**This leaf has 11 failure_modes** in the corpus (id-prefix `ecs.task-defs.fm.*` or `ecs.task-defs.*.fm.*`). Query via `pnpm harness lookup "<keyword>"` or `pnpm harness ask "<symptom>"`.

**Domain totals (covers this leaf):**

- `ecs.sources`: 21
- `ecs.failure_modes`: 50

See `domains/_shared/PROGRESS.md` for the master per-phase log (P1 source build, P3 deep extraction, P4/P5 relationships, P13–17 quality pass).

For interview-day relevance, this leaf is queryable through the harness — try `pnpm harness ask "<your-task-defs-related-symptom>"` to see what's available.
