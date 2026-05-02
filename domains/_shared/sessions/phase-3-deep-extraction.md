# Phase 3 — Deep extraction (per leaf)

> **Run this once per leaf folder.** ~17 leaves × 3–5 sessions = bulk of the project. Ask which leaf to start with: e.g. `docker/engine`, `linux/primitives`, `devin/devbox`, etc.

> **Sequencing (revised 2026-05-02, see [PREAMBLE.md](./PREAMBLE.md) → Approach commitments):** Phase 3 pairs with Phase 1 as one **P1+P3 vertical per domain** — the parent domain should already have P1 complete in `<domain>.documents` before running this. **Domain order under the new doctrine: methodology → docker → linux → devin → k8s** (the priority order list below is preserved for intra-domain leaf prioritization but its top entry of `devin/devbox` is overridden by the vertical-slice doctrine; methodology comes first). **Phase 2 (devbox live-capture) now runs HORIZONTALLY AFTER all domains have P1+P3 landed** — so `devin/devbox` P3 runs without live capture in the first pass and is enriched later when P2 fires. Source gaps surfaced during P3 patch back into `domains/_shared/sources.yaml` mid-session (P1 is dynamic, not a one-time pass).

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this file or say: *"Run domains/_shared/sessions/phase-3-deep-extraction.md for `<domain>/<leaf>`."*

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md)
- The leaf's existing files: `domains/<domain>/<leaf>/README.md` (if exists), `PLAN.md` (if exists), `PROGRESS.md`
- The Phase 1 corpus for this leaf: `SELECT * FROM <domain>.documents WHERE source_id IN (subquery on sources.yaml subdomain filter)`

## Goal

For the chosen leaf, end with non-trivial rows in:
- `<domain>.concepts` (subsystems, daemons, files, features) — target 50–200
- `<domain>.commands` (CLI subcommands with flags, examples) — target 100–500
- `<domain>.config_keys` (daemon.json keys, compose YAML keys, env vars, sysctls) — target 50–300
- `<domain>.failure_modes` (THE GOLD LAYER — symptom, error_patterns, root_cause_class, diagnostic_steps[], fix_steps[]) — target 50–200
- `<domain>.relationships` linking those entities to each other and to entities in other domains

Cross-references: every failure-mode lists `affected_concepts`; every command links to its concept(s); every relationship cites a `source_id`.

## Domain priority order

Highest-leverage first (cut from the bottom if running short):
1. `devin/devbox` (driven by Phase 2 capture + Phase 1 docs)
2. `docker/engine`
3. `linux/primitives`
4. `linux/networking`
5. `linux/debugging`
6. `docker/networking`
7. `docker/compose`
8. `docker/runtime`
9. `linux/systemd`
10. `devin/integrations`
11. `devin/mcp`
12. `devin/api`
13. `devin/product` + `devin/knowledge-playbooks` + `devin/enterprise`
14. `docker/build-buildkit` + `docker/security`
15. `linux/filesystem`
16. `k8s/debugging`
17. `k8s/core` + `k8s/networking` + `k8s/runtime`
18. `methodology/*`

## Plan-mode meta-research (Phases 1–5)

### Phase 1 — Initial Understanding (Explore agents)

Launch 1–3 Explore agents (max). Quality > quantity.

For the chosen leaf, the agents survey:
1. The ingested documents — query `<domain>.documents WHERE source_id LIKE '<leaf-prefix>%' OR section_path LIKE '%<leaf>%'`. Identify the canonical reference page, the troubleshooting page, and the highest-density "errors" page.
2. The leaf's prior-art schemas in other domains — if `docker/engine` is done already and you're on `linux/primitives`, look at the shape of `docker.concepts` for inspiration. Don't reinvent column conventions.
3. Cross-referenced entities — concepts in OTHER schemas this leaf depends on or surfaces in. Note them now so you can wire `relationships` later.

### Phase 2 — Design (Plan agent — sometimes 2 perspectives)

Have the Plan agent design the per-leaf extraction:
- **Concepts pass** — strategy: regex/structural extraction from manpages/CLI-refs (mechanical), or LLM-aided structured-output extraction from prose docs (semantic). Choose per source.
- **Commands pass** — flag mining from `--help` outputs preferred over docs (more authoritative). For Docker/Linux, the manpage SYNOPSIS sections are gold.
- **Config keys pass** — for daemon.json / compose YAML / kernel sysctls, write a small parser; for kernel sysctls, `sysctl -a` outputs are well-structured.
- **Failure-modes pass** — the irreducible work. Mine from: troubleshoot pages, common-issues pages, GitHub issues with high engagement (reactions/comments), kernel `Documentation/admin-guide/*-howto.md`, StackOverflow questions tagged with this domain at high vote counts. Cross-reference each to concepts and commands. **Set realistic targets per leaf** (Devin: 30–80; Docker engine: 100+).
- **Relationships pass** — graph-walk over the new entities + existing entities in other schemas. Use `memory` MCP graph for the conceptual skeleton; SQL for bulk.

For a multi-perspective Plan agent, consider asking one to advocate for *minimal-scope* (ship something useful fast) and one for *exhaustive* (catalog everything). Pick the right balance for this leaf's priority.

### Phase 3 — Review (`AskUserQuestion`)

Confirm with me:
- Target counts (concepts/commands/config_keys/failure_modes) — am I OK with the scope?
- Any specific GitHub issues / SO answers you want me to weight in?
- Are there custom extractor scripts worth writing this session vs. deferring?

### Phase 4 — Final Plan

Scaffold the leaf folder if it doesn't yet exist: `pnpm leaf add <domain>/<leaf>` (idempotent — creates `README.md`, `PLAN.md` from template, `PROGRESS.md`, `extract/`, `queries/` only if missing; never overwrites). Then fill in the leaf-specific Phase A–E goals in `PLAN.md` and update `PROGRESS.md` with the session's intent.

### Phase 5 — `ExitPlanMode`

## Execute the per-leaf phases A–E (after plan approval)

These are the per-leaf phases inside `PLAN.template.md`:

- **A. Survey** — confirm `sources.yaml` filtering returns the right set. Add any missed sources.
- **B. Document ingest** — re-run `uv run python -m ingest fetch --domain <d> --subdomain <s>` if any sources changed.
- **C. Concepts / Commands / Config-keys** — run extractor(s); land JSON in `domains/<domain>/<leaf>/extract/{concepts,commands,config_keys}.json`; load via `python -m ingest load --table <t> --leaf <d>/<s>` (this CLI subcommand is a Phase 0.x backlog item — write it if it doesn't exist).
- **D. Failure-modes** — the gold layer. Hand-curated + LLM-assisted. Spot-check every entry.
- **E. Relationships** — wire via SQL inserts; mirror the conceptual chain in `memory` MCP.

## Verification

- [ ] `SELECT count(*) FROM <domain>.{concepts,commands,config_keys,failure_modes}` hits the target order-of-magnitude.
- [ ] Random-sample 5 rows per table, eyeball for sanity. Each row's `source_ids` resolves to a real URL.
- [ ] For 3 random failure-modes, manually confirm the diagnostic_steps run cleanly in a sandbox (a local Docker container or WSL Ubuntu VM).
- [ ] For 5 concepts, walk `relationships` outgoing — at least 3 links each.
- [ ] Update `domains/<domain>/<leaf>/PROGRESS.md`.

## When this leaf is done

Move to the next leaf in the priority order. Once all priority leaves are at minimum-viable extraction, [`phase-4-synthesis.md`](./phase-4-synthesis.md) wires it all together.

## Reuse map specific to this phase

- LLM structured extraction — use Claude via the Anthropic SDK with `tool_use`-shaped JSON schema matching the table's column types. Don't free-form-prompt.
- Manpage parsing — `man7.org` HTML structure is consistent; a small lxml selector can grab SYNOPSIS / DESCRIPTION / DIAGNOSTICS reliably.
- GitHub issue mining — `gh api repos/<owner>/<repo>/issues?state=closed&labels=bug&per_page=100` + reaction sort. Issues with 10+ thumbs-ups are usually canonical.
- DuckDB JSON ingestion — `read_json_auto('extract/concepts.json')` is one-line and respects nested arrays/structs.
