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
- `snapshot --label <L>` / `restore --label <L>` / `diff --since <L>` — Layer 2: `snapshot` writes **every** data table (base + domain-specific, excludes only regenerable `embeddings`/`claim_history`) to committed parquet under `_shared/snapshots/<L>/`; `restore` reloads them FK-safely into a fresh DB. **`init-db` + `restore --label 2026Q2-complete` fully reconstructs the corpus from committed state** (round-trip verified: 298 tables / 15.6k rows). SCD-2 `claim_history` + `diff` track change between labels.
- `embed --domain` / `search --hybrid` / `gaps` — Layer 4: local fastembed vectors (`embed` extra), `base embeddings` table, HNSW via `queries/vss_index.sql`, BM25+vector RRF, dedup/whitespace.
- `reason --domain [--commit]` — Layer 5: inference rules in `_shared/rules/*.yaml` derive edges (`transitive`, `sql_edge`) and **claims** (`sql_claim` → speculative claims with `derivations` provenance, quarantined until L6 verify promotes them). E.g. `derive-contested-wedge` infers 9 contested-wedge claims from the compintel erosion edges.
- `model run --domain --model <id>` — Layer 3: NumPy Monte-Carlo from `_shared/models/*.yaml` (fixed seed → reproducible) into `model_runs`.
- `render [--out <dir>]` — Layer 7: project `strategy.render_blocks` ⋈ `artifact_blocks` into a non-divergent family of `.md` artifacts (investor deck / strategy memo / battlecards / board update) under `domains/strategy/render/`. A shared metric renders byte-identically across artifacts (structural non-divergence); verdict glyphs keep every figure self-auditing (a proxy-only wedge can't read as measured). Read-only; regenerable.
- `sensitivity --domain --model <id>` — Layer 3 (tornado): each model input's rank-correlation (Spearman, no SciPy) with the output over the MC draws → which assumption drives variance (e.g. SOM is 61% penetration; LTV:CAC is 60% ARPU). Reproducible from the same seed as `model run`.
- `forecast --domain [--horizon <days>]` — Layer 6 (forecast loop): register every predictive/speculative claim as a datable `forecast_log` row (predicted_prob from confidence, `resolves_by` horizon). This is what gives `calibrate` (Brier) something to score; outcomes are filled in later via `resolve`, never auto-assumed.
- `watch --since <DATE>` — Layer 8 (self-updating): scan the temporal layer for competitor moves after a cutoff that erode a wedge feature or fire a red-team falsifier, and report the recommendations/wedge claims to recompute. Read-only — raises alerts, never silently mutates the synthesis (closes the reason→render loop).
- `decide --budget <pts>` — Layer 9 (portfolio): exact 0/1 knapsack over `strategy.recommendations` maximizing total priority within an effort budget (s=1, m=2, l=3, xl=5) → a committed action set + deferred list, not just a ranking.

**The `strategy` synthesis domain** reads the whole cross-domain algebra READ-ONLY and never mutates another domain's verdicts (the C5 conflation guard; `market.claims` snapshot diff stays 0/0/0). It holds `wedge_reeval` (each wedge claim re-graded to an honest ceiling — **supported-by-proxy is the cap, never experimental**, derived from the empty `voc` dormant-intake), `recommendations` (priority derived by query over cited claims' confidence × impact; missing experiments emitted as `is_experiment` roadmap items), `render_blocks`/`artifact_blocks` (the non-divergence projection), and `red_team_findings` (falsifiers wired to live `compintel` temporal signals).

**Active focus:** `domains/exercise/` — a science-backed training-fact corpus that generates an optimal Push/Pull/Legs routine (static loop + dynamic mesocycle). See `domains/exercise/PLAN.md`.

**Parked (not deleted):** the original interview-prep domains (`devin`, `docker`, `linux`, `ecs`, `firecracker`, `methodology`), whose context lives in `domains/_shared/sessions/PREAMBLE.md` + the per-phase `phase-*.md` docs. Still queryable and resumable through the same engine; just not the current focus.

**Combined corpus (this branch).** This branch is the union of two research runs: the `exercise` training-science corpus and the Strategy-OS business domains (`market`, `strategy`, `compintel`, `product`, `hci`, `voc`, `finance`, `ecosystem`, `governance`). All 16 domains share one uniform gold layer — `meta.all_claims` spans 452 claims across 10 populated domains — and `exercise` is now a first-class engine citizen: embedded (`ingest embed --domain exercise`), hybrid-searchable (`ingest search --domain exercise "<q>"`), evidence-graded (L1 `evidence`), and verification-recalibrated (L6 `verify`) like every other domain. The built corpus is tracked at `_db/knowledge.duckdb`; it is also rebuildable from committed state — `init-db` + `restore --label 2026Q2-complete` reconstructs the Strategy-OS domains, `load-extract --domain exercise` (+ mark's `routine`/gym loaders) reloads exercise, and `queries/{fts,vss}_index.sql` rebuild the BM25/HNSW indexes after `embed`.

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
