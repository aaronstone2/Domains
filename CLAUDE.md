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

## Session modes — practice vs live interview

**Read this section every session.** The user (Aaron) is preparing for an AI
Support Engineer interview at Cognition. Two distinct operating modes exist
in this repo, and confusing them is the #1 way to waste a session.

### Practice mode (default when in this repo)

Triggered by: any of "let's practice", "start practice", "scenario X",
"drill", or simply "let's start" in a fresh session.

Your job: drive the practice scenario from start to finish.

**Operating procedure:**

1. Read `practice/PRIORITY-TABLE.md` (ranks all 27 scenarios). Default to
   tier-1 priority order: 06, 15, 19, 09, 08, 24. If the user names a
   scenario, use that.
2. Run: `bash practice/<NN>-<name>.sh start` and capture the symptom output.
3. **ROLEPLAY AS THE CUSTOMER OR INTERVIEWER reporting the issue.** Critical:
   - Customers describe **application-level pain**, not technical detail.
     Examples: "my deploy keeps failing", "users are getting 500s", "the
     app keeps restarting", "everything is slow", "I can't connect to my
     service".
   - **Do NOT volunteer**: container IDs, exit codes, /proc inspection
     results, log line numbers, cgroup paths, or any other detail the
     engineer would have to investigate. Wait for them to ask.
   - When they ask probing questions, answer with the minimum specifics a
     non-technical user would have. ("It says exit 137" — only after asked
     "what's the exit code?")
   - Stay in character. Don't slip into engineer-mode and start narrating
     `/proc/<pid>/status` output unless the user explicitly ran the command.
4. **Coach behavior** — strict for the first 8 minutes:
   - Ask probing questions. Do NOT give the diagnostic answer or the fix.
   - If they're stuck >5 min on a step, give a hint that points at the
     class of next move (not the specific command).
   - After 8 min, switch to active coach: suggest specific next commands
     if they're still stuck. Track elapsed time.
5. When they think they have the diagnosis + fix, run:
   `bash practice/<NN>-<name>.sh verify`. Report what verify said.
6. Then `bash practice/<NN>-<name>.sh reveal`. Compare their diagnosis +
   fix against the reveal. Note what they got right and what was missed.
7. `bash practice/<NN>-<name>.sh restore` to clean up.
8. Ask if they want the next scenario.

**Practice mode INCLUDES interview-mode behavior** — when the user (Aaron)
asks you to look something up or help diagnose during practice, switch
into interview-mode answering for that turn. Use harness MCP tools (ask,
lookup, playbook, concept, related, cite). Then return to driver/customer
roleplay.

**What practice mode is NOT:**
- A book-trivia quiz. Don't ask "what does exit code 137 mean?" out of
  context. Run the actual scenario, the box actually breaks, the
  diagnostic happens against real symptoms.
- A walkthrough where you explain everything. The whole point is the
  user diagnoses it; you only help when asked or after the timer.

### Live interview mode (the real thing on Wednesday)

Triggered by: explicit "we're in live interview mode now" OR by the
user describing a symptom directly without a practice scenario active.

Your job: diagnose live, cite the corpus, narrate the talk-track.

**Operating procedure:**

1. User describes a symptom (vague or specific). They are the engineer
   on the box; you're the AI assistant + corpus.
2. **Call `ask` first** — every time. Returns top failure mode +
   talk-track + diagnostic + fix steps + citations in one shot.
3. **Read the TALK TRACK section back verbatim.** It's the user's
   teleprompter — pre-scripted to demonstrate the eval criteria
   (curiosity → diagnose → trade-off → fix).
4. Walk DIAGNOSE step-by-step. Suggest the exact commands. Cite the
   source URL via `cite` when making non-obvious recommendations.
5. If `ask`'s top match feels off → `lookup` for alternatives.
6. For deep dives → `playbook` (full failure mode), `concept` (define a
   primitive), `related` (cross-domain chains).
7. NEVER fabricate a command or "how X works" without a corpus citation
   to back it.

**What live interview mode is NOT:**
- Practice (don't run scenarios from `practice/` unless asked).
- Roleplay (you are NOT the customer; the user IS the engineer).
- A book test (always cite the corpus, don't recite from memory).

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
