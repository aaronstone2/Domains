# How to use these phase docs

These docs are designed to be **piped into a new Claude Code session as the first message**. Each phase doc is self-contained: it embeds the universal context (or references `PREAMBLE.md`), the phase-specific goal, and the plan-mode meta-research pattern.

## Starting a session

Three equivalent ways:

```powershell
# A) Pipe the file in as the first message
type domains\_shared\sessions\phase-1-source-corpus.md | claude

# B) Reference it from the prompt
# In Claude Code: "Run domains/_shared/sessions/phase-3-deep-extraction.md"

# C) Open Claude Code in the repo, then paste the contents of the phase doc
```

In all three forms, the doc instructs Claude to:
1. Read `domains/_shared/sessions/PREAMBLE.md` first.
2. Enter plan mode.
3. Do its own meta-research (Explore agents → Plan agent → AskUserQuestion → write per-leaf `PLAN.md` → `ExitPlanMode`).
4. Execute the plan after approval.

## The plan-mode meta-research pattern (every session does this)

The same five-phase pattern we used for the master plan:

| Phase | Tool | Output |
|-------|------|--------|
| 1. Initial Understanding | 1–3 Explore agents in parallel | Sitemap + source inventory |
| 2. Design | 1–3 Plan agents | Implementation strategy |
| 3. Review | `AskUserQuestion` | High-leverage forks resolved |
| 4. Final Plan | `Write` to per-leaf `PLAN.md` | Per-leaf plan file |
| 5. Approval | `ExitPlanMode` | Approved plan, mode exit |
| Execute | All tools | Phases A–E from the per-leaf plan |

**Always start in plan mode.** It's cheap and it prevents wasting a session on the wrong sources.

## After each session

- Update `domains/<leaf>/PROGRESS.md` with what was done, what was deferred, what to pick up next.
- Update `MEMORY.md` if anything surprising came up.
- Master plan reference: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`.

## File index

| File | Purpose | Sessions |
|------|---------|----------|
| [`PREAMBLE.md`](./PREAMBLE.md) | Universal context — interview, repo, MCP stack, conventions | read every session |
| [`phase-0-foundation.md`](./phase-0-foundation.md) | Initial repo + DB + ingest + harness scaffold | 1 (Session 0.1) |
| [`phase-1-source-corpus.md`](./phase-1-source-corpus.md) | Per-domain document ingest (sources + raw markdown) | 5 (one per domain) |
| [`phase-2-devbox-capture.md`](./phase-2-devbox-capture.md) | DevBox primary-source capture (T0 tier) | 1–2 |
| [`phase-3-deep-extraction.md`](./phase-3-deep-extraction.md) | Concepts / commands / config_keys / failure_modes / relationships per leaf | 3–5 × N leaves (~17 leaves) |
| [`phase-4-synthesis.md`](./phase-4-synthesis.md) | Cross-domain relationships, Devin→primitive chains | 2 |
| [`phase-5-harness.md`](./phase-5-harness.md) | TS debugging harness (`packages/harness/`) | 3–4 |
| [`phase-6-drills.md`](./phase-6-drills.md) | Mock interview drills | 3–5 |
| [`phase-7-optional.md`](./phase-7-optional.md) | Embeddings + VSS, LLM routing, scheduled refresh | as time permits |

## Naming convention for leaf-level plans

Per-leaf plans live at `domains/<domain>/<leaf>/PLAN.md` and are derived from `domains/_shared/PLAN.template.md`. Don't reinvent the structure; copy and fill in.

## When to add a NEW phase doc

If a session reveals a new recurring pattern (e.g., "after every Phase 3, do a quick anomaly scan"), add a new `phase-<n.x>-<name>.md` and update this index. Don't pile new patterns into the existing docs — keep each one focused.
