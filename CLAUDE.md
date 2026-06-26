# Domains monorepo

pnpm workspace. Two top-level dirs:

- `domains/<name>/` — research/knowledge domains (each holds leaf folders + an optional `schema.<name>.sql`)
- `packages/<name>/` — TS packages, all named `@domains/<name>`

## Commands

Run from repo root:

- `pnpm domain add <name>` — create `domains/<name>/` with a domain `README.md` + `PROGRESS.md`. Add an optional `schema.<name>.sql` for domain-specific tables.
- `pnpm leaf add <domain>/<leaf>` — scaffold `domains/<d>/<l>/` with `README.md`, `PLAN.md` (from `_shared/PLAN.template.md`), `PROGRESS.md`, `STATUS.yaml` (phase manifest), `extract/`, `queries/`. **Idempotent** — only creates what's missing, never overwrites populated files. Run it when you start work on a leaf.
- `pnpm package add <name> [--preset=<node|node-cjs|ts|vite|react>]` — scaffold a new `@domains/<name>` package; prompts for tsconfig preset if `--preset` omitted
- `pnpm test` — run vitest across all packages
- `pnpm typecheck` — `tsc --noEmit` across all packages

`domain add`, `leaf add`, and `package add` all prompt via `@clack/prompts` if their argument is omitted. After `pnpm package add`, run `pnpm install` to register the new workspace package.

## tsconfig: always extend cue

We install [`@mark1russell7/cue`](https://github.com/mark1russell7/cue) via git ref. **Never write a tsconfig from scratch** — always `extends` one of these presets and only override the bare minimum (e.g., extra `types`).

| preset | use for |
| --- | --- |
| `node.json` | Node.js library/CLI, ESM (NodeNext) |
| `node-cjs.json` | Node.js library, CJS |
| `ts.json` | generic TS library, ESM |
| `vite.json` | browser/bundler code |
| `react.json` | React + Vite |

Form: `"extends": "@mark1russell7/cue/ts/config/<preset>.json"`.

Cue's base enables `isolatedDeclarations`, so all exported values need explicit type annotations. If a package executes TS directly with `tsx` (like the CLI) and uses `.ts` import specifiers (NodeNext-correct ESM), add `"noEmit": true` and `"allowImportingTsExtensions": true` in its tsconfig.

## Conventions

- **Vite + Vitest** wherever applicable. Every package gets a `vitest.config.ts`; browser/UI packages use Vite.
- **TypeScript everywhere.** Source under `src/`, no separate build step in dev — root scripts use `tsx` to execute TS directly.
- **Package scope.** All packages are `@domains/<name>`, private, ESM (`"type": "module"`).
- **Naming.** `^[a-z0-9][a-z0-9-]*$` for both domains and packages.
- **Scratch files during research.** Never write loose research scratch (curl-dumped HTML, intermediate notes) to the project root — it gets accidentally committed via `git add .`. Drop scratch under `domains/<active-domain>/raw/` (gitignored). The pipeline's own raw cache lives at `_db/raw/<domain>/<subdomain>/<id>.html` (also gitignored). The repo-root `.gitignore` explicitly ignores `/*.md` with an allowlist for `CLAUDE.md`, `README.md`, `Start.md` to backstop this.

## Knowledge corpus (extensible engine)

A multi-domain knowledge corpus lives in this repo: DuckDB at `_db/knowledge.duckdb`, ingest pipeline at `domains/_shared/ingest/` (Python via `uv`), queryable via the `duckdb` CLI / motherduck MCP. (`pnpm harness <sub>` needs the native `duckdb` node dep, which can't compile on this machine — Node 25, no MSVC; migrate it to `@duckdb/node-api` prebuilt binaries when wiring up harness commands. The corpus is fully usable via the CLI / MCP meanwhile.)

**The engine is domain-agnostic and auto-extending:**

- **Domains are auto-discovered** — a domain is any folder under `domains/` (excluding `_shared`). Dropping a folder registers it everywhere: `ingest init-db` creates its schema and regenerates the cross-domain `meta.*` views (`queries/cross_domain.sql`) and the FTS build script (`queries/fts_index.sql`) from the live domain list — both are AUTO-GENERATED, do not hand-edit.
- **Per-domain tables** — every domain gets the shared base schema (`sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`, `relationships` — `domains/_shared/schema.sql`). A domain may declare its own tables in `domains/<d>/schema.<d>.sql` (uses the `{{schema}}` placeholder; `init-db` applies it on top of the base).
- **Per-leaf state** — each leaf carries a `STATUS.yaml` (depth + per-phase progress) for deterministic resume, plus a `PROGRESS.md` narrative log.
- **Configurable depth** — `scout | standard | exhaustive` per leaf (`_shared/sessions/depth-profiles.md`); depth scales source breadth and how hard the gold layer (Phase D) is adversarially verified.

**Starting or resuming work:** read `domains/_shared/sessions/extend-playbook.md` — the single entry point for engaging on any domain, new or partially complete. Each leaf runs a plan-mode meta-research ritual (Explore → Plan → clarify → write PLAN/STATUS → execute phases A–E in `PLAN.md`).

**Strategy-OS engine layers (`ingest` subcommands beyond init-db/fetch/load).** The engine evolved from a research corpus into a strategy OS; `claims` is now a BASE table (uniform gold layer + `meta.all_claims`). New capabilities, all backward-compatible (idempotent `-- migrations` block in `schema.sql`; DB stays a regenerable artifact):
- `load-extract --domain [--leaf]` — upsert `{table: rows}` extension-table JSON from `extract/*.json` (replaces the manual duckdb-CLI step).
- `verify --domain` / `calibrate` — Layer 6: per-claim `verification_standard` (descriptive/evaluative/predictive), Wilson CIs (`confidence_low/high`), freshness/`stale` decay; Brier calibration via `forecast_log`.
- `evidence --domain [--audit]` — Layer 1: `claim_evidence` junction + `primary_studies` + the `v_claim_grade` view. `is_primary_backed` is **derived, never authored** — secondary evidence can't masquerade as primary; supported-but-unbacked claims read as "supported-by-proxy" (the wedge honesty cap).
- `snapshot --label <L>` / `diff --since <L>` — Layer 2: committed parquet history under `_shared/snapshots/` + SCD-2 `claim_history`.
- `embed --domain` / `search --hybrid` / `gaps` — Layer 4: local fastembed vectors (`embed` extra), `base embeddings` table, HNSW via `queries/vss_index.sql`, BM25+vector RRF, dedup/whitespace.
- `reason --domain [--commit]` — Layer 5: inference rules in `_shared/rules/*.yaml` derive edges/claims (speculative until verified) with `derivations` provenance.
- `model run --domain --model <id>` — Layer 3: NumPy Monte-Carlo from `_shared/models/*.yaml` (fixed seed → reproducible) into `model_runs`.

**Active focus:** `domains/exercise/` — a science-backed training-fact corpus that generates an optimal Push/Pull/Legs routine (static loop + dynamic mesocycle). See `domains/exercise/PLAN.md`.

**Parked (not deleted):** the original interview-prep domains (`devin`, `docker`, `linux`, `ecs`, `firecracker`, `methodology`), whose context lives in `domains/_shared/sessions/PREAMBLE.md` + the per-phase `phase-*.md` docs. Still queryable and resumable through the same engine; just not the current focus.

## CLI internals

The CLI lives in `packages/cli/` (`@domains/cli`). Architecture:

```
packages/cli/src/
  index.ts              # arg router: pnpm <group> <sub> [args]
  paths.ts              # repo-root, domains/, packages/ paths
  commands/
    index.ts            # group registry
    domain/{index,add}.ts
    leaf/{index,add}.ts
    package/{index,add}.ts
```

To add a new subcommand: drop a file in `commands/<group>/<sub>.ts` exporting an `async (args: string[]) => void`, then register it in `commands/<group>/index.ts`. To add a new group, create the folder and register it in `commands/index.ts`.

Root scripts (`pnpm domain ...`, `pnpm package ...`) run `tsx packages/cli/src/index.ts <group>` and pnpm appends the remaining args.
