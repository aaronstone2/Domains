# Domains monorepo

pnpm workspace. Two top-level dirs:

- `domains/<name>/` — research/knowledge domains (folders only for now; will be extended)
- `packages/<name>/` — TS packages, all named `@domains/<name>`

## Commands

Run from repo root:

- `pnpm domain add <name>` — create `domains/<name>/` (just the folder shell + .gitkeep)
- `pnpm leaf add <domain>/<leaf>` — scaffold `domains/<d>/<l>/` with `README.md`, `PLAN.md` (from `_shared/PLAN.template.md`), `PROGRESS.md`, `extract/`, `queries/`. **Idempotent** — only creates what's missing, never overwrites populated PLANs/PROGRESS files. Run this at the start of a Phase 3 session for the leaf you're working on.
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

## Knowledge corpus

A multi-domain debugging KB lives in this repo: DuckDB at `_db/knowledge.duckdb`, ingest pipeline at `domains/_shared/ingest/` (Python via `uv`), per-phase session prompts at `domains/_shared/sessions/`, queryable via `pnpm harness <sub> [args]`. **Always start a corpus session by reading `domains/_shared/sessions/PREAMBLE.md`** — it captures the interview goal (AI Support Engineer at Cognition), conventions, the MCP stack (motherduck/filesystem/memory/context7/playwright), and the plan-mode meta-research pattern every session follows. Per-phase docs (`phase-1-source-corpus.md`, etc.) are designed to be piped in as the first message of a new session.

Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`.

## Using the corpus during interviews / live debugging (MCP tools)

**This repo IS an MCP** for the AI Support Engineer interview screen-share. When you're invoked from inside this repo, the project-scoped `.mcp.json` exposes 8 native tools via the `domains-harness` MCP server. Prefer these tools over shelling out to `! pnpm harness ...` — they're faster, structured, and the user is being evaluated on how the MCP "feels" while running.

| Tool | When to call |
|---|---|
| `ask` | **PRIMARY.** User describes a symptom or error → call this first. Returns top failure mode + talk-track + diagnostic + fix steps + citations in one shot. |
| `lookup` | When `ask`'s top match feels off, or to browse all candidates. |
| `playbook` | When you already know the fm-id (e.g. from a prior `ask`) and want to re-render. |
| `concept` | Definition + relationship edges for a primitive (cgroups, OOM-killer, iptables NAT). |
| `related` | Walk the relationship graph from a node to depth N. Cross-domain inference. |
| `cite` | Get the canonical doc URL for a recommendation. |
| `stats` | Corpus inventory — what's available before answering. |
| `capture` | Run a curated diagnostic-bundle on the live system. SIDE EFFECT: actually executes shell. |

**Talk-track is the user's teleprompter.** When `ask` returns, read the TALK TRACK section back to the user verbatim — it's pre-scripted to demonstrate the eval criteria (curiosity → diagnose → trade-off → fix). Then walk DIAGNOSE step-by-step.

If MCP tools aren't available (e.g. running outside the repo), the same commands work as `pnpm harness <subcommand>` shell-outs.

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
