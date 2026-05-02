# Phase 5 — Debugging harness build

> **3–4 sessions.** Builds `packages/harness/` (`@domains/harness`) — the interview-day CLI.

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this file or say: *"Run domains/_shared/sessions/phase-5-harness.md, session 5.<n>."*

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md)
- `packages/cli/src/index.ts`, `packages/cli/src/commands/index.ts` — the existing CLI pattern is the model (arg router, command groups, `tsx`-direct execution, cue-extending tsconfig)
- The Phase 0 stub at `packages/harness/src/index.ts`

## Goal

A single-binary CLI that:
- Opens `_db/knowledge.duckdb` directly (no network)
- Answers "what is this error?", "what's the next diagnostic step?", "show me the chain"
- Cites `source_id` → URL on every claim
- Is read-out-loud-able during a screen-share

## Sub-sessions

### 5.1 — Backend (DB layer + query primitives)

Plan-mode meta-research first (Phases 1–5):

- **Phase 1 (Explore)** — Survey current Node/TS DuckDB bindings (`duckdb-async` vs. `@duckdb/node-api`). Determine which is healthier in May 2026 via `context7` MCP. Identify portability story (does the binary work on the interview Linux VM?).
- **Phase 2 (Plan)** — Design the `db.ts` module: open path, retry on lock, query helpers, FTS pre-built statements, type-safe row shapes (Zod or hand-typed).
- **Phase 3** — Confirm with me: bindings choice, type-safety approach (Zod or not).
- **Phase 4** — Write `packages/harness/PLAN.md`.
- **Phase 5** — `ExitPlanMode`.

Then build:

- `packages/harness/src/db.ts` — `openDb()`, `closeDb()`, `searchFts(domain, query, limit)`, `getFailureMode(id)`, `getConcept(id)`, `walkRelationships(fromId, maxHops)`, `getCommand(id)`.
- `packages/harness/src/types.ts` — TS shapes mirroring the SQL row types.
- Tests in `packages/harness/src/db.test.ts` against a fixture DuckDB file.

### 5.2 — Subcommands `query` / `symptom` / `err` / `cmd` / `concept`

Plan-mode meta-research (Phases 1–5) then:

- `query <text>` → BM25 over `meta.all_documents`. Top-10. Show `source_id`, URL, snippet. Use `<C-c>` to copy a result.
- `symptom <text>` → match against `meta.all_failure_modes.symptom`. Use trigram similarity (`SIMILARITY` or LIKE) when FTS is too narrow.
- `err <regex>` → match against `meta.all_failure_modes.error_patterns` (which are themselves regex strings — match the user's literal error string against each pattern).
- `cmd <command>` → exact + fuzzy match on `meta.all_commands.command`. Show flags, examples, related failure-modes.
- `concept <name>` → exact + fuzzy match. Show definition, kind, related commands, related failure-modes.

Output style: terse, one entity per ~5 lines, citation always last line. Suitable to read aloud.

### 5.3 — Subcommands `chain` / `playbook` / `capture`

Plan-mode meta-research (Phases 1–5) then:

- `chain <id>` → walk the relationship graph from a starting entity ID. Print the path with rel_types between hops. Default depth 4.
- `playbook <slug>` → interactive runbook. Print step 1 (action + command + expected). Wait for keypress. On `next`, advance. On `skip`, log and advance. On `done`, summarize what was checked.
- `capture` → run a curated set of read-only diagnostics in the local shell. Bundle output into a single text file. Suggest top-3 likely failure-modes by cross-referencing the captured signals (e.g., if `dmesg` mentions `Killed process`, suggest `container_oom_killed`).

### 5.4 — Distribution

- Build a portable artifact. Investigate: Bun's `bun build --compile`, `pkg`, or `@vercel/ncc` + bundled DuckDB native binary. **Test in WSL Ubuntu** (closest analog to the interview VM).
- Verify: `_db/knowledge.duckdb` copies cleanly, the binary runs without `npm install`, `pnpm harness symptom "<test>"` returns from a clean machine.

## Per sub-session: plan-mode meta-research is non-negotiable

Every sub-session above starts in plan mode. Even 5.4 (distribution) — the bindings + native-binary story has surprises and an Explore agent should map the territory first.

## Verification (overall, end of Phase 5)

- [ ] `pnpm harness symptom "container exits with code 137 immediately"` returns `container_oom_killed` as #1, with diagnostic_steps citing `dmesg` and `cat /sys/fs/cgroup/.../memory.events`.
- [ ] `pnpm harness chain devin.fm.mcp_auth_expired` walks ≥3 hops to a Linux primitive.
- [ ] WSL Ubuntu: copy `_db/knowledge.duckdb` and the harness binary to a fresh VM. Run `harness capture` against a deliberately-broken container. Output is sourced, terse, and actionable.

## When this is done

Move to [`phase-6-drills.md`](./phase-6-drills.md). The harness exists; now I have to be fluent operating it.
