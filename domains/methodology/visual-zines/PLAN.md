# Plan — `methodology/visual-zines`

> Stub form. Phases A and B were done at the domain level in session 1.1.

## Context

Julia Evans (jvns) blog posts + Wizard Zines comics + jpetazzo container-training README. The "accessible/visual debugging" subdomain — most content is comic-image PDFs (gated) or marketing landing pages, with one substantive blog post (`jvns-tracing-systems`, ~63 KB) that surveys the tracer landscape (strace / ltrace / ftrace / DTrace / perf_events ancestry).

Smallest leaf in methodology by extractable signal. Most value is in being a citation pointer for tracer ancestry and Linux observability ergonomics.

## Phase status

| Phase | Status | Where |
| --- | --- | --- |
| A — Survey | DONE | `methodology.sources WHERE subdomain='visual-zines'` (14 sources) |
| B — Document ingest | DONE | `methodology.documents` (14 docs, ~464 KB total — but heavily skewed by `wizardzines-comics-index` at 407 KB which is a link list). FTS built. |
| C — Concepts/Commands/Config-keys | **THIS SESSION** | extract/concepts.json → `methodology.concepts` |
| D — Failure-modes | DEFERRED | Horizontal phase. |
| E — Relationships | DEFERRED | Horizontal phase. |

## Phase C scope

Targets:
- ~5–10 concepts (residual — only what's not already covered in use-red-method)
- 0 commands
- 0 config_keys

Sources prioritized:

- `jvns-tracing-systems` — tracing taxonomy concepts not in brendangregg-* (strace ancestry, ftrace, dynamic vs. static tracing), ~5 concepts

Sources deferred:

- `jvns-debugging-zine` — image-only PDF, 0 chars extracted; OCR follow-up
- 6 Wizard Zines free-zine landing pages — marketing-light; the actual zine content is gated PDF
- `wizardzines-comics-index` — 407 KB but mostly a URL list; harvest pending
- `jpetazzo-container-training-readme` — curation/index page

## Phase C dedupe pass

After Batch B (use-red-method concepts) and this batch land, walk both files and merge `source_ids` for any concept that appears in multiple sources (e.g., `methodology.flame-graph` is in `brendangregg-flamegraphs`, `brendangregg-perf`, possibly `jvns-tracing-systems`). One concept row, multiple source citations.

## Open questions

(populated during execution)
