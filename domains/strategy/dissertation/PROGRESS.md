# `strategy/dissertation` — PROGRESS log

Per-leaf log; rolls up into `domains/strategy/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## 2026-06-29 — Dissertation produced (release-ready)

A single, exhaustive English dissertation consolidating the whole 9-domain corpus + the Strategy-OS
engine + the honesty machinery. Additive: the old market paper
(`domains/market/market-synthesis/extract/paper.md`) was left untouched.

**Deliverables (leaf root):** `dissertation.md` (~49k words, ~108pp) · `dissertation.pdf` (110pp, 2.6 MB,
15 charts) · `dissertation.html`.

**Structure:** Parts I–XII (thesis · method/engine · market · HCI · product+wedge · VoC · ecosystem ·
governance · finance · strategy+bear-case · roadmap · limitations) + Appendices A (full 406-claim ledger)
B (engine/CLI, 21 verbs) C (glossary) D (corpus map) E (relationship taxonomy).

**Build (`build/`, all deterministic, run with system python):**
- `common.py` — DB helpers, glyph vocab, the 14-chapter data-contract spec.
- `packets.py` → `data/<slug>.json` per-chapter citation contracts (+ `_claim_index.json`).
- `figures.py` → `figures/*.png` (15 charts, incl. live Spearman sensitivity via `ingest.mc`).
- `assemble.py` → front matter + chapters + DB-generated Appendices A/D/E + citation annotation.
- `annotate.py` — `[C:id]`→ numbered superscripts + verdict-glyph cited-claim/source indexes.
- `to_pdf.py` — markdown → HTML → PDF (pymupdf.Story + Archive), deflate-compressed.
- `build_all.py` — one command: packets → figures → assemble → render.
- Chapter prose under `chapters/*.md` is the only authored input; everything else regenerates from
  `_db/knowledge.duckdb` (rebuildable via `ingest init-db` + `ingest restore --label 2026Q2-complete`).

**Production pipeline (multi-workflow):** architect → per-chapter draft→flow-edit→honesty-audit
(43 agents) → completeness critic (8/10; closed compintel macro gap, GTM/UX teardown, list verb, real
sensitivity) → adversarial judge panel (rigor 8 · honesty 9 · narrative 7 · completeness 8; per-chapter
fixers) → round-2 verification: **release-ready**, 181 citations all resolve, honesty contract intact.

**Honesty:** every wedge claim capped at supported-by-proxy / pending-experimental; `is_primary_backed`
derived (HCI 46/49, VoC 42/63, rest 0); market verdicts unmutated; empty dormant-intake surfaced as the
pending marker; financials framed as comps/MC estimates, not marks.
