# Phase 7 — Optional enhancements (only if runway remains)

> Skip these unless Phases 1–6 are solid. The interview is won by fluency on the corpus, not by extra features.

> **Sequencing (revised 2026-05-02, see [PREAMBLE.md](./PREAMBLE.md) → Approach commitments):** Phase 7 (optional polish) runs **last, horizontally**. Anything not blocking the interview can also be deferred via `/schedule` for follow-up after the deadline.

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this file or say: *"Run domains/_shared/sessions/phase-7-optional.md."*

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md)

## Three candidate enhancements

### 7.1 Embeddings + VSS (semantic search)

Add a `documents.embedding VECTOR(384)` column; populate via a local embedding model (Ollama + `nomic-embed-text` is free and fast); enable DuckDB VSS HNSW index for cosine similarity.

**Caveat:** VSS persistence is *experimental* in DuckDB 1.x — confirm current state via `context7` MCP before relying on it. May need to recompute on each open.

**Plan-mode meta-research first** — Phases 1–5 normally. Specifically:
- Phase 1 (Explore): current state of DuckDB VSS persistence; embedding model options; chunking strategy for documents.
- Phase 2 (Plan): chunking + embedding pipeline + harness integration (`harness ask`).
- Phase 3: confirm vendor (Ollama vs. OpenAI vs. Anthropic — note Anthropic has no embedding API).
- Phase 4: per-leaf plan.
- Phase 5: ExitPlanMode.

**Trade-off:** real value comes from semantic search over `failure_modes.symptom`, not over `documents` (the FTS already crushes that). Consider embedding *only* the symptom column.

### 7.2 LLM-routed query

Add `harness ask "<natural-language question>"`. A small LLM (Anthropic `claude-haiku-4-5`) routes the query to the right structured query against the corpus. Strict tool-use schema; the LLM never *generates* facts — it only *picks* which structured query to run and which entities to fetch. Every answer cites corpus rows.

**Plan-mode meta-research first.** This is a small Anthropic SDK app — invoke the `claude-api` skill in the planning session for prompt-caching / model-version best practices.

### 7.3 Scheduled refresh

Use Claude Code's `/schedule` to run a remote agent weekly that:
- Re-fetches top-tier sources
- Diffs against stored `content_hash`
- Queues re-extraction for changed pages
- Posts a one-line summary to a log file

**Plan-mode meta-research first.** `/schedule` cron + remote-agent semantics are non-trivial; map them via `claude-code-guide` agent before designing.

## Verification

Per enhancement: it WORKS, has a test, has a documented usage in `packages/harness/README.md`. No need to verify all three — one solid enhancement > three half-baked.

## Stop condition

If interview is in <1 week and Phase 6 self-review is still <4/5 on any criterion: **STOP this phase, return to Phase 6.** Fluency beats features.
