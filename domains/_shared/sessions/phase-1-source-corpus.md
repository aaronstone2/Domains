# Phase 1 — Source corpus build-out (per domain)

> **Run this once per domain. The first time you run it, ask which domain to start with: `devin` / `docker` / `linux` / `k8s` / `methodology`.**

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this entire file as your first message, OR say: *"Run domains/_shared/sessions/phase-1-source-corpus.md."*

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md) — universal context (interview goal, repo conventions, MCP stack, plan-mode pattern)

## Goal of this session

Land **every relevant source for the chosen domain** as a row in `<domain>.sources` and its cleaned markdown body in `<domain>.documents`. No structured extraction (concepts/commands/failure-modes) — that's Phase 3. This session is broad and shallow.

After this, FTS lookups against `meta.all_documents` work for the chosen domain.

## Inputs

- `domains/_shared/sources.yaml` — already seeded with ~50 entries spanning all domains
- `domains/_shared/ingest/` — fetch + extract + load pipeline
- `_db/knowledge.duckdb` — schemas already created (Phase 0)

## Plan-mode meta-research (do not skip — Phases 1–5 of the plan-mode workflow)

You start in plan mode. Run the standard five-phase workflow:

### Phase 1 — Initial Understanding (Explore agents IN PARALLEL)

Launch up to 3 Explore agents to map the territory of the chosen domain BEYOND what's already in `sources.yaml`. Goal: end with a deduplicated, tier-ranked, license-noted source list ready to extend `sources.yaml`. Don't deep-read; map.

Sample agent prompts (adapt to chosen domain):

- **Devin** — exhaustive crawl of `docs.devin.ai` (use `playwright` MCP — Mintlify is JS-rendered; the sitemap may miss pages); cognition.ai/blog archive; Cognition GitHub orgs (`CognitionAI`, `usacognition`, `devin-open-source`); status page archive at `devinstatus.com`; release-notes.
- **Docker** — full sitemap of `docs.docker.com` (it has GitHub mirror at `docker/docs` — prefer markdown source); Compose Spec markdown; OCI Runtime Spec; containerd docs; Docker Engine API reference; troubleshooting / common-error pages specifically.
- **Linux** — kernel.org admin-guide pages; man7.org index for the relevant categories (1, 2, 5, 7, 8); systemd man pages at freedesktop.org; netfilter docs; tcpdump.org.
- **K8s** — kubernetes.io/docs/concepts and /docs/tasks/debug exhaustively; CRI spec; common-error pages.
- **Methodology** — Brendan Gregg site; Julia Evans free zines (PDFs); CC-licensed Google SRE chapters; jpetazzo training materials; Liz Rice talks/slides if linkable.

### Phase 2 — Design (Plan agent)

Launch one Plan agent with full Phase 1 context. Have it propose:

- Which sources to *add* to `sources.yaml` (with tier/license/parser annotations)
- Which sources need a **custom parser** (Mintlify pages may need `playwright` rendering; man pages may benefit from a `manpage` parser preserving DIAGNOSTICS sections; GitHub markdown via raw URL is much cleaner than the rendered page)
- Order of fetching (start with the smallest/most-machine-readable; finish with the largest)
- Verification strategy: sample queries that should return sensible top-10 from FTS

### Phase 3 — Review (`AskUserQuestion`)

Confirm with me:
- Any sources you're unsure about including (license / proprietary concerns)
- Whether the proposed custom parsers are worth building this session or deferring to a later session

### Phase 4 — Final Plan

Write the per-domain expansion to `domains/<domain>/_PHASE-1-PLAN.md` and update `domains/_shared/sources.yaml` with the new entries (atomically — single PR-style edit).

### Phase 5 — `ExitPlanMode`

## Execute (after plan approval)

```powershell
cd domains\_shared\ingest

# Verify the ingest tool is healthy
uv run python -m ingest list --domain <chosen-domain>

# Fetch + extract + load all sources for this domain
uv run python -m ingest fetch --domain <chosen-domain>

# Some sources will fail (paywalled, rate-limited, JS-rendered, redirected).
# Re-run with --source-id <failing-id> after debugging each one.

# Build FTS index for this domain
duckdb ..\..\..\_db\knowledge.duckdb -c "INSTALL fts; LOAD fts; PRAGMA create_fts_index('<chosen-domain>.documents', 'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);"
```

## Per-domain notes

- **Devin** — `docs.devin.ai` is Mintlify-rendered. trafilatura on the rendered page may produce thin output; if so, switch to `playwright` MCP-based capture (render → grab markdown). The `/llms.txt` index gives the canonical page list; the sitemap is good too. License: `reference-only` — store snippets, not full corpus.
- **Docker** — prefer the GitHub mirror `github.com/docker/docs` for raw markdown. License on docs is proprietary; treat extracted text as `reference-only`. Compose Spec and OCI Runtime Spec are Apache 2 → `redistribute-ok`.
- **Linux** — kernel.org is GPL-licensed (redistribute-ok). man7.org content is GPL/redistribute-ok. systemd freedesktop.org is LGPL/redistribute-ok.
- **K8s** — CC BY 4.0 (`redistribute-ok`).
- **Methodology** — Brendan Gregg site is public domain (redistribute-ok); Julia Evans zines are CC BY 4.0 free PDFs (`reference-only` for *paid* zines but the free debugging/networking zines are fine); SRE books CC-licensed online.

## Verification

- [ ] `SELECT count(*) FROM <domain>.sources` matches the count in `sources.yaml` filtered to that domain (sans known-failures).
- [ ] `SELECT count(*), avg(length(content_md)) FROM <domain>.documents` is non-trivial (mean >500 chars).
- [ ] Pick 3 random documents → eyeball-check rendered markdown is sane.
- [ ] FTS query `SELECT * FROM <domain>.documents WHERE fts_main_<domain>_documents.match_bm25(source_id, '<obvious term>') IS NOT NULL ORDER BY ... LIMIT 5` returns sensible results.
- [ ] Update `domains/<domain>/PROGRESS.md` with: sources added, sources failed (and why), date, next steps.

## When this is done across all 5 domains

Move to [`phase-2-devbox-capture.md`](./phase-2-devbox-capture.md) (Devin DevBox live capture) and then [`phase-3-deep-extraction.md`](./phase-3-deep-extraction.md) (per-leaf concepts/commands/failure-modes).
