# `firecracker/vsock` — PROGRESS log

Per-leaf log; rolls up into `domains/firecracker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Status

Phase 1 (sources + documents) and Phase 3 (concepts/commands/config_keys/failure_modes/relationships) executed at the **firecracker domain level** rather than per-leaf — the actual extraction sessions ingested all of `firecracker.*` in a single pass for efficiency, then partitioned the data by source-id prefix where helpful.

**This leaf has 0 leaf-specific failure_modes.** Coverage rolls up at the domain level (`firecracker.fm.*`, 71 fms) — leaf-prefixed namespacing wasn't used during extraction. Sources for this leaf are still indexed in `firecracker.sources` and queryable.

**Domain totals (covers this leaf):**

- `firecracker.sources`: 37
- `firecracker.failure_modes`: 71

See `domains/_shared/PROGRESS.md` for the master per-phase log (P1 source build, P3 deep extraction, P4/P5 relationships, P13–17 quality pass).

For interview-day relevance, this leaf is queryable through the harness — try `pnpm harness ask "<your-vsock-related-symptom>"` to see what's available.
