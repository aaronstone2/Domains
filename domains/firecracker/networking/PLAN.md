# Plan — `<domain>/<leaf>` (e.g. `docker/engine`)

> Per-domain plan. Open this file in a Claude Code plan-mode session inside the leaf directory; iterate phases A–E. Track progress in `PROGRESS.md` next to this file.

## Context

Why this leaf exists: <one paragraph: what subsystem this domain covers, why it matters for interview-day debugging, what the expected user-visible failure-modes look like>.

How this leaf composes upward: <which other leaves it underpins or is underpinned by — e.g. `docker/engine` underpins `devin/devbox` failure-modes; `linux/primitives` underpins all of `docker/*`>.

## Inputs already available

- Global source registry: `domains/_shared/sources.yaml` (filter to this leaf via `domain` + `subdomain`).
- Base schema: `domains/_shared/schema.sql` (already applied to the leaf's domain schema).
- Ingest pipeline: `domains/_shared/ingest/` (`uv run python -m ingest fetch --domain <d> --subdomain <s>`).
- Anything captured live (e.g. DevBox CAPTURE.md outputs) under `raw/` with `tier=T0`.

## Phase A — Survey (1 session)

Goal: end with a complete, deduplicated list of sources scoped to this leaf.

- [ ] Add per-leaf sources to `domains/_shared/sources.yaml` (or a leaf-local `sources.yaml` if the volume warrants).
- [ ] For each, set `tier`, `license`, `parser`. Skim each URL once; throw out anything redundant.
- [ ] **Verify:** `uv run python -m ingest list --domain <d> --subdomain <s>` shows N rows; manual eyeball pass.

## Phase B — Document ingest (1 session)

Goal: every source's body lives in `<schema>.documents` and is FTS-searchable.

- [ ] `uv run python -m ingest fetch --domain <d> --subdomain <s>` → fills `<d>.sources`, `<d>.documents`, caches raw under `_db/raw/<d>/<s>/`.
- [ ] Re-run `domains/_shared/queries/fts_index.sql` for the affected schema.
- [ ] **Verify:** `SELECT count(*), avg(length(content_md)) FROM <d>.documents WHERE source_id IN (<this leaf's source IDs>);` matches expected.
- [ ] Spot-check 3 random documents: rendered markdown is sane (not nav-junk, not empty).

## Phase C — Structured extraction: concepts, commands, config_keys (1–2 sessions)

Goal: rows in the structured tables for the lookup-able entities in this leaf.

- [ ] **Concepts** — extract subsystems, files, daemons, features. Target ~50–200/leaf. Land via JSON in `extract/concepts.json`, then `uv run python -m ingest load --table concepts --leaf <d>/<s>`.
- [ ] **Commands** — one row per CLI subcommand (`docker container exec` is a row; flags as STRUCT array). Mine from `man` pages, CLI reference pages, `--help` outputs from CAPTURE.
- [ ] **Config keys** — daemon.json keys, compose YAML keys, kernel sysctls, env vars. Mine from reference docs.
- [ ] **Verify:** counts match expected order-of-magnitude. Sampled rows have working `source_ids` references.

## Phase D — Failure-modes (1–2 sessions, the gold layer)

Goal: the queryable runbook layer. This is what `harness symptom` searches.

- [ ] Mine sources tagged `troubleshoot`, `common-issues`, `error-reference`. Cross-reference GitHub issues with high engagement, canonical SO answers, kernel `Documentation/admin-guide/*-howto.md`.
- [ ] For each failure-mode: symptom, error_patterns (regex), root_cause_class, diagnostic_steps[], fix_steps[], confidence, source_ids.
- [ ] Cross-reference `affected_concepts` to concept IDs in this and other leaves.
- [ ] **Verify:** for 5 random failure-modes, run `harness symptom "<symptom>"` and confirm a sensible top-3 returns. Run the diagnostic steps in a sandbox where applicable.

## Phase E — Relationships (0.5 session)

Goal: connect concepts/commands/failure-modes within and across leaves.

- [ ] `affects`, `depends-on`, `controlled-by`, `surfaces-in`, `fixes`. Target ~3x relationships per concept.
- [ ] **Verify:** `harness chain <concept-id>` walks ≥3 hops with sensible nodes.

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- Other leaves under the same domain — copy their `extract/concepts.json` shape as a starting point.

## Open questions

- <Track any unresolved decisions here so the next session can pick them up.>
