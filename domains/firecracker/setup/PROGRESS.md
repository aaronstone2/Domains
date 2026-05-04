# `firecracker/setup` — PROGRESS log

Per-leaf log; rolls up into `domains/firecracker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Status

Phase 1 (sources + documents) and Phase 3 (concepts/commands/config_keys/failure_modes/relationships) executed at the **firecracker domain level** rather than per-leaf — the actual extraction sessions ingested all of `firecracker.*` in a single pass for efficiency, then partitioned the data by source-id prefix where helpful.

**This leaf has 24 failure_modes** in the corpus (id-prefix `firecracker.setup.fm.*` or `firecracker.setup.*.fm.*`). Query via `pnpm harness lookup "<keyword>"` or `pnpm harness ask "<symptom>"`.

**Domain totals (covers this leaf):**

- `firecracker.sources`: 37
- `firecracker.failure_modes`: 71

See `domains/_shared/PROGRESS.md` for the master per-phase log (P1 source build, P3 deep extraction, P4/P5 relationships, P13–17 quality pass).

For interview-day relevance, this leaf is queryable through the harness — try `pnpm harness ask "<your-setup-related-symptom>"` to see what's available.
