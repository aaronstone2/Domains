# exercise — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## Session 0 — 2026-06-24 — Domain bootstrap + engine generalization — DONE

Refocused the corpus engine from interview-prep onto exercise science, and generalized it to be
extensible-as-hell first.

**Engine upgrades (reusable across all future domains):**

- **Auto-discovered domains** — `paths.discover_domains()` scans `domains/` (drops a new folder →
  registered everywhere). Removed the hardcoded `DOMAIN_SCHEMAS` tuple; `k8s` (folderless) correctly
  dropped, `linux`/`firecracker`/`ecs`/`exercise` picked up.
- **Per-domain schema extensions** — `init-db` applies an optional `domains/<d>/schema.<d>.sql` on top
  of the shared base schema. `paths.domain_schema_extension()` + `load.init_db()`.
- **Auto-generated cross-domain wiring** — `init-db` regenerates `queries/cross_domain.sql` (meta.all_*
  views) and `queries/fts_index.sql` from the live domain list; no hand-maintained domain lists.
- **Status manifests** — `pnpm leaf add` now writes `STATUS.yaml` (depth + per-phase state) for
  deterministic resume. `pnpm domain add` now writes a domain README + PROGRESS.
- **Depth profiles + extend playbook** — `_shared/sessions/depth-profiles.md` (scout/standard/exhaustive,
  the verification dial) and `_shared/sessions/extend-playbook.md` (the re-engagement contract). The
  generic `PLAN.template.md` was de-debugging-fied (Phase D = "gold layer", not "failure-modes").

**Exercise domain scaffold:**

- `domains/exercise/` + `schema.exercise.sql` (9 tables: muscles, movement_patterns, exercises,
  substitutions, training_variables, set_structures, claims, studies, constraints).
- 6 leaves scaffolded: anatomy, movements, programming, techniques, constraints, routine.

**Verified:**

- `ingest init-db` succeeded. `exercise` schema has 16 tables (7 base + 9 extension); schemas present:
  devin, docker, ecs, exercise, firecracker, linux, methodology, meta (k8s gone — no folder).
- `cross_domain.sql` + `fts_index.sql` regenerated to include `exercise`; meta views compile.
- `pnpm typecheck` green for cli + harness. CLI leaf scaffolder dogfooded for all 6 leaves.

**Known issue (pre-existing, non-blocking):** the harness's native `duckdb` node dep won't compile
(Node 25, no MSVC). Corpus is fully usable via the duckdb CLI + motherduck MCP. Harness can migrate to
`@duckdb/node-api` (prebuilt binaries) when its exercise commands are built.

**Next:** deepen the 6 leaf PLAN/README (in progress this session). Then per-leaf Phase A source sweep
(exhaustive), starting with `anatomy` + `movements`. Equipment inventory needed before `routine`.
