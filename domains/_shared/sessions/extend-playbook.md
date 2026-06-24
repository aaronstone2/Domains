# Extend playbook — starting (or resuming) a domain extension

This is the single entry point for engaging Claude on corpus work. It makes "start a new extension"
and "build off partially-completed work" deterministic instead of ad hoc. The corpus engine is
domain-agnostic; this playbook is how you point it at anything.

## The engine in one paragraph

A domain is a folder under `domains/`. Each domain gets the shared base schema (`sources`,
`documents`, `concepts`, `commands`, `config_keys`, `failure_modes`, `relationships`) plus optional
domain-specific tables it declares in `schema.<domain>.sql`. Domains are **auto-discovered** — dropping
a folder under `domains/` registers it everywhere (init-db, the cross-domain `meta.*` views, FTS), no
hardcoded list. Each leaf carries a `STATUS.yaml` phase manifest and a `PROGRESS.md` narrative log.

## Starting a brand-new domain

```powershell
pnpm domain add <name>                 # folder + README + PROGRESS
# (optional) author domains/<name>/schema.<name>.sql for domain-specific tables
pnpm leaf add <name>/<leaf>            # repeat per leaf; scaffolds PLAN + STATUS.yaml + dirs
cd domains/_shared/ingest && uv run python -m ingest init-db   # creates schema + applies extension + regenerates meta views/FTS
```

Then, **per leaf**, run a plan-mode session that executes the meta-research ritual and the A–E phases
in `PLAN.md`. Set the leaf's `depth` in `STATUS.yaml` first (see `depth-profiles.md`).

## Resuming partially-completed work (the re-engagement contract)

A new session is cheap to start because state is on disk:

1. **Read `STATUS.yaml`** for the target leaf. It says the `depth` and which phases are
   `todo` / `partial` / `done`. Resume at the first non-`done` phase — do not re-derive prior phases.
2. **Read `PROGRESS.md`** for the narrative (what was landed, what was deferred, open questions).
3. **Build off other domains.** Completed domains are queryable now: the `meta.all_*` views and the
   `relationships` table compose across domains, so a new extension cites existing facts rather than
   re-researching them. Cross-domain edges are wired in Phase E as discovered.
4. On finishing a phase, update `STATUS.yaml` (`done` + `updated:` date) and append to `PROGRESS.md`.

## Deepening an existing leaf

Bumping `depth` (e.g. `standard` → `exhaustive`) is a resumable operation: set the new depth in
`STATUS.yaml`, mark the gold/relationship phases back to `partial`, and re-run them — the wider
fan-out and stronger verification append to and re-grade what's already there.

## Phase ↔ STATUS key map

| STATUS key | Phase | Produces |
|---|---|---|
| `meta_research` | plan-mode ritual | the leaf's PLAN |
| `a_survey` | A | `sources` |
| `b_ingest` | B | `documents` + FTS |
| `c_extract` | C | entity tables |
| `d_gold` | D | verified facts (the irreducible layer) |
| `e_relationships` | E | typed graph |
