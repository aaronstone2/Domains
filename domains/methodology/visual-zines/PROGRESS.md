# `methodology/visual-zines` — PROGRESS log

Per-leaf log; rolls up into `domains/methodology/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.1 — 2026-05-02 — DONE

**Outputs:**

- **6 visual-zines concepts** in `methodology.concepts`. The core add: `methodology.tracing-taxonomy` (Julia Evans / Brendan Gregg's 3-layer mental model — data sources / collection mechanisms / frontends). Plus 5 tracer-ancestor concepts that fall outside use-red-method scope: `methodology.strace`, `methodology.ltrace`, `methodology.systemtap`, `methodology.lttng`, `methodology.dtrace`.
- **0 commands** — visual-zines is concept-only.
- **0 config_keys** — N/A for this leaf.

**Sources extracted from:**

- `jvns-tracing-systems` — substantive blog post surveying the Linux tracing landscape; the only doc with extractable concept density in this leaf

**Verified (ran via motherduck SQL):**

- Row counts: 6 concepts. (Target was 5–10.)
- Source-ID integrity: 0 orphan refs.
- Canonical-hook presence: `methodology.tracing-taxonomy` resolves and ties together the kprobe/uprobe/tracepoint/USDT concepts already landed in use-red-method.

**Deferred (intentional, low-priority):**

- **`jvns-debugging-zine`** — image-only PDF; 0 chars extracted via pymupdf. **OCR follow-up needed** (Phase 1 backlog item — tesseract + pymupdf `get_textpage_ocr()` wiring). The actual zine content is cartoon/comic-style and extractable text density would be modest after OCR.
- **`wizardzines-comics-index`** (407 KB ingested HTML) — link list of individual comic URLs. Phase 1.5 follow-up: harvest individual comic landing-page URLs and re-fetch.
- **6 Wizard Zines free-zine landing pages** — marketing-light; gated PDF content not available for ingestion. Title metadata only.
- **`jpetazzo-container-training-readme`** — curation/index page; minimal new concept value.
- **`jvns-notes-man-pages`**, **`jvns-examples-tcpdump-dig-manpages`** — example-driven; tooling already covered in use-red-method.
- **`otel-concepts`** — OpenTelemetry concept hub page; thin, indexable as citation pointer only.

**Defer-list (per PREAMBLE doctrine):**

- `methodology.failure_modes` and `methodology.relationships` — horizontal phases.

## Cross-references

- Concepts JSON: `extract/concepts.json` (6 entries)
