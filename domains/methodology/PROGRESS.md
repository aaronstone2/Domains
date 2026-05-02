# Methodology — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.1 — 2026-05-02 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-1-sou-floofy-lampson.md`; pipe-able session prompt `domains/_shared/sessions/phase-1-source-corpus.md`.

**Outputs:**

- **44 sources, 44 documents, 1,270,471 chars indexed** in `methodology.sources` / `methodology.documents`.
- BM25 FTS index `fts_methodology_documents` built (porter stemmer, english stopwords).

**Per-subdomain breakdown:**

| subdomain        | sources | mean chars | total chars |
| ---              | ---:    | ---:       | ---:        |
| use-red-method   | 18      | 34,584     | 622,514     |
| visual-zines     | 14      | 33,175     | 464,450     |
| sre-debugging    | 12      | 15,292     | 183,507     |

By tier: T1=12 (canonical), T2=27 (respected secondary), T3=5 (high-quality blog/reference).

**Verified (acceptance per plan):**

- All 44 sources fetched (0 unfetched, 0 fetch failures).
- Mean doc length 28,874 chars (well above 500 threshold).
- 1 thin doc (<200 chars): `jvns-debugging-zine` (PDF — explained below). Threshold was ≤4. ✓
- 9 small docs (<2 KB): the PDF + `sre-google-books` index + `otel-concepts` + 6 Wizard Zines free-zine landing pages (marketing-light). All expected per plan.
- 7 BM25 verification queries (one per major framework keyword) — all return relevant top-5 results; each subdomain represented in ≥2 query top-5s.
  - Q4 "four golden signals" → `sre-monitoring-signals` top-1 with score 8.2 (>2× runner-up).
  - Q5 "blameless postmortem" → `sre-postmortem-culture` top-1 (6.55).
  - Q6 "incident commander" → `sre-managing-incidents` top-1 (4.50).
  - Q1 "USE method" → `brendangregg-usemethod` top-1 (4.53), full USE-method cluster in top-5.

**Infra delta (this session):**

- Added `pymupdf>=1.24` to `domains/_shared/ingest/pyproject.toml`. Installed via `uv sync`.
- Refactored `extract.py` to dispatch on `Source.parser`:
  - `parser=pdf` → pymupdf text extraction
  - `parser=github-md` → passthrough (raw markdown URLs already serve our target format; trafilatura returns nothing on plain markdown without HTML, which silently broke `bpftrace-oneliners` + `jpetazzo-container-training-readme` on first attempt — now fixed)
  - else → trafilatura (default)
- **Refactored ingest pipeline to decouple from DB lock** (this was the day's biggest win):
  - `ingest fetch` now writes JSONL staging to `_db/staging/<domain>.{sources,documents}.jsonl` (no DB lock).
  - New `ingest load --domain <d>` command opens DB and bulk-loads via DuckDB `read_json` + `INSERT OR REPLACE BY NAME`.
  - Standard load path is the **motherduck MCP** running the same SQL — works while the MCP holds the DB lock. Unblocks the recurring "DB locked by another process" pain that Phase 0 PROGRESS warned about.
  - Files modified: `ingest/cli.py`, `ingest/load.py`, `ingest/paths.py` (added `STAGING_DIR`).

**Sources failed:** none (0 of 44).

**Sources with sparse content (action items):**

- `jvns-debugging-zine` (0 chars) — PDF is 20 pages of pdfTeX-rendered comic art (all images, no text layer). pymupdf opens it correctly but extracts nothing. **Phase 2 candidate for OCR (tesseract via pymupdf's `get_textpage_ocr()` or `pytesseract`).**
- `sre-google-books` (796 chars) — index page; we have the chapters separately so this is acceptable as a citation pointer.
- `otel-concepts` (1,132 chars) — concept hub page; thin but indexable. Drill into specific concept pages in a Phase 1.5 follow-up if needed.
- 6 Wizard Zines free-zine landing pages (1.5–1.9 KB each) — marketing-light; the actual zine content is in the linked PDF (gated behind email signup).

**Source list adjustments made during execution:**

- Replaced `bpftrace-reference` (turned out to be a 141-byte index) with `bpftrace-language` (71 KB) + `bpftrace-stdlib` (56 KB). Net +1 source; net +127 KB content.

**License posture (from session-start verification):**

- `wizardzines.com` pages — verified live: footer has print/errors/educators/shipping/privacy links but **no Creative Commons or license statement**. 7 entries (6 free zines + comics index) marked `license_note: unknown`. Body still ingested for our private corpus per user steer.
- `brendangregg.com` — public domain (Brendan's own statement). Marked `redistribute-ok`.
- `iovisor/bcc`, `bpftrace/bpftrace`, `brendangregg/perf-tools`, `jpetazzo/container.training`, `dastergon/postmortem-templates`, `pagerduty/response.pagerduty.com` — Apache 2.0 / CC BY 4.0 / public domain. `redistribute-ok`.
- `sre.google/sre-book/*` — CC BY-NC-ND 4.0. Marked `redistribute-ok` for our private corpus, with `notes` flagging the no-modify/no-commercial restriction.
- `jvns.ca/*` posts — CC BY-NC-SA 4.0 per site footer. Marked `redistribute-ok`. Patched `jvns-tracing-systems` from the original `reference-only` to reflect this.

**Deferred to later sessions:**

- OCR for image-only PDFs (tesseract installation + pymupdf `get_textpage_ocr()` wiring).
- Per-parser variants for `manpage` and `mintlify` (forward-looking metadata; trafilatura currently handles both adequately).
- Wizard Zines individual comic URLs — harvest from the comics-index page (407 KB extracted markdown contains the link list).
- Cindy Sridharan's free O'Reilly chapter (PDF, paywalled landing).
- jpetazzo blog, awesome-sre, postmortem-templates, containers-from-scratch — dropped from this session per Plan agent (would belong in `docker.runtime` / `linux.primitives` or are curation lists that dilute FTS).

**Next phases for this domain:**

- **Phase 3** (Concepts/Commands/Config): extract the framework names (USE/RED/Four Golden Signals/TSA/Off-CPU), the diagnostic commands (`perf`, `bpftrace`, `bcc-tools/*`), and the structured prompts (postmortem template) into `methodology.concepts`, `methodology.commands`, `methodology.config_keys`.
- **Phase 4** (Failure-modes): mostly cross-references — methodology rarely has its own failure-modes; the value is in linking *which methodology applies to which docker/linux/devin failure-mode*. Land in `methodology.relationships`.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-1-sou-floofy-lampson.md`
- Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`
- Pipe-able session prompt: `domains/_shared/sessions/phase-1-source-corpus.md`
