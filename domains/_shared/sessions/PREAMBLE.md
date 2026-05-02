# Preamble — read this every session

Universal context. Every per-phase doc in this directory references this file. Re-read it whenever you start a session — the operating context is dense and decays if I have to re-explain it.

---

## Who I am, what I'm doing

I'm Aaron Stone (aaron@bubble.graphics). I'm interviewing for **AI Support Engineer at Cognition**, makers of Devin.ai.

Cognition told me the interview will be:

> - Connection to a Docker, Linux VM, screen-share troubleshooting
> - Usage of any external sources is allowed (Google, AI, etc.)
> - Evaluated based on efficiency, clarity of thought, and communication
> - Demonstrate curiosity, ask clarifying questions if you are unclear before jumping to any solutions, show you able to think through trade-offs and explain the why behind your thinking

I don't know whether they'll literally put the Devin AI DevBox on the VM with a fomented issue, or whether it'll be an arbitrary Linux/Docker debugging scenario. I'm preparing for both.

## What we're building

A **comprehensive, queryable knowledge corpus** stored in DuckDB at `_db/knowledge.duckdb`, that catalogs:

- Every component of Devin — configurations, files, APIs, technologies, integrations, MCP wiring, DevBox runtime details
- Trustworthy debugging sources for Devin, Docker, Docker debugging, Kubernetes, Linux primitives, Linux networking, Linux debugging tools, systemd, container runtime internals
- **Tables mapping every possible problem that can occur with the Devin product** (small surface area — feasible)
- More generally, tables mapping problems and debugging procedures for arbitrary Docker setups

The end-state deliverable is a **debugging harness** at `packages/harness/` that I will run during the interview. It performs fast lookups, walks playbooks, captures system state, and (most importantly) gives me the citations and reasoning to **explain the why** out loud — which is what they're evaluating.

## Approach commitments (these are NOT up for debate per session)

- **Multi-session, multi-phase research.** ~30 sessions over ~3–4 weeks.
- **Each domain gets its own folder** under `domains/`: `devin/{product, devbox, integrations, api, mcp, knowledge-playbooks, enterprise}`, `docker/{engine, compose, build-buildkit, runtime, networking, security}`, `linux/{primitives, networking, debugging, systemd, filesystem}`, `k8s/{core, debugging, networking, runtime}`, `methodology/{use-red-method, sre-debugging, visual-zines}`.
- **Each domain has its own multi-phased PLAN.md** (copied from `domains/_shared/PLAN.template.md`) and `PROGRESS.md`.
- **Catalog all trustworthy sources.** Tier them T0/T1/T2/T3. Track license. Don't republish proprietary docs.
- **Knowledge composes across domains.** SQL `meta.all_*` views; the `memory` MCP for the conceptual graph; cross-domain `relationships` rows.
- **Programmatically queryable end-state.** Future research sessions pull from the existing corpus rather than re-discovering — every session leaves the corpus richer.
- **K8s is in scope as a peer domain to Docker.** Lower priority than Docker/Linux/Devin but not skipped.

## The plan-mode meta-research pattern (CRITICAL — do not skip)

**Every session in this project starts in plan mode and runs its own meta-research before executing.** This is the same pattern we used to design the master plan; it's why the master plan is strong, and we apply the same discipline at every level.

The five-phase plan-mode workflow (per Claude Code's plan-mode):

1. **Phase 1 — Initial Understanding.** Launch Explore agents IN PARALLEL (1–3 max) to survey the domain. Don't deep-read; map the territory: sitemaps, table-of-contents, GitHub repo trees, key sub-pages.
2. **Phase 2 — Design.** Launch Plan agent(s) (1–3) to design the per-leaf implementation: which sources, which extraction strategy, which schemas/tables get filled, what verification looks like.
3. **Phase 3 — Review.** Use `AskUserQuestion` to clarify high-leverage forks (timeline, scope, depth). Don't ask about plan approval — that's `ExitPlanMode`'s job.
4. **Phase 4 — Final Plan.** Write the per-leaf `PLAN.md` from `domains/_shared/PLAN.template.md`, plus update `PROGRESS.md`.
5. **Phase 5 — `ExitPlanMode`** to request approval.

After approval: execute the per-leaf phases **A–E** (Survey → Document Ingest → Concepts/Commands/Config Extraction → Failure Modes → Relationships).

**Why this matters:** the irreducible work in each domain is the failure-modes layer. Everything before it is mechanical (URLs, fetch, manpage parse). The meta-research finds the high-leverage moves and avoids 80%-mechanical / 20%-actually-useful traps. Skip it and you waste a session on the wrong sources.

## Repo / corpus architecture

```
_db/
  knowledge.duckdb      # single canonical store, schema-per-domain
  knowledge_graph.json  # memory MCP — typed entity-relation graph
  raw/                  # gitignored — fetch cache, hash-keyed per source
domains/
  _shared/
    schema.sql          # base DDL applied to each domain schema
    sources.yaml        # global tiered source registry
    queries/
      cross_domain.sql  # meta.all_* views
      fts_index.sql     # BM25 FTS PRAGMA per domain
    ingest/             # uv-managed Python pipeline (fetch, extract, load)
    sessions/           # ← these per-phase docs (you are here)
    PLAN.template.md    # copy this to each leaf
  devin/{product,devbox,integrations,api,mcp,knowledge-playbooks,enterprise}/
  docker/{engine,compose,build-buildkit,runtime,networking,security}/
  linux/{primitives,networking,debugging,systemd,filesystem}/
  k8s/{core,debugging,networking,runtime}/
  methodology/{use-red-method,sre-debugging,visual-zines}/
packages/
  cli/                  # existing scaffolding — pnpm domain add, pnpm package add
  harness/              # interview-day debugging harness
```

Each domain's leaf folder has the conventional structure: `README.md`, `PLAN.md`, `PROGRESS.md`, `sources.yaml` (optional leaf-local), `raw/` (gitignored), `extract/` (committed JSON facts), `queries/`.

## DuckDB schema (per domain)

`sources(id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes)` · `documents(source_id, section_path, content_md)` · `concepts(id, name, kind, description, source_ids[], aliases[])` · `commands(id, command, purpose, flags[STRUCT], examples[STRUCT], source_ids[])` · `config_keys(id, scope, key, type, default_value, description, source_ids[])` · `failure_modes(id, symptom, error_patterns[], root_cause_class, affected_concepts[], diagnostic_steps[STRUCT], fix_steps[STRUCT], confidence, last_verified, source_ids[])` · `relationships(from_id, to_id, rel_type, source_id)`.

Cross-domain views in `meta` schema. FTS via DuckDB's `fts` extension on `documents`.

## MCP / tooling stack

| Tool | Use |
|------|-----|
| `motherduck` MCP | All DB queries during research and at runtime. Pointed at `_db/knowledge.duckdb` with `--read-write`. |
| `filesystem` MCP | Cross-tool consistent reads/writes under `domains/**`. |
| `memory` MCP | Knowledge graph at `_db/knowledge_graph.json`. |
| `context7` MCP | Live, version-current library docs (Docker SDK, kubectl, runc, …). Prefer over WebFetch. |
| `playwright` MCP | JS-rendered docs, DevBox UI capture, exhaustive crawling when sitemap incomplete. |
| Explore agent | Phase 1 (Initial Understanding) per session. |
| Plan agent | Phase 2 (Design) per session. |
| Local `duckdb` CLI | Direct interactive queries outside Claude. |

## Tier conventions

- **T0** — primary live capture (DevBox process tree, real `daemon.json`, captured `docker info`)
- **T1** — official vendor docs / kernel docs / man pages / specs
- **T2** — respected secondary (books, conference talks by recognized practitioners)
- **T3** — high-quality blogs, canonical StackOverflow answers

## License conventions

- **redistribute-ok** — CC, Apache, BSD, GPL, public domain. Safe to ingest content into the corpus.
- **reference-only** — proprietary docs (Docker Inc., Cognition Devin docs). Store URL/title/short snippets only; cite, do not republish.
- **unknown** — assume reference-only until verified.

## Reuse map (don't reinvent)

| Need | Reuse |
|------|-------|
| Workspace + scaffolding | Existing `packages/cli` and `pnpm package add` (already documented in `CLAUDE.md`). |
| HTML→Markdown | `trafilatura` (Python, BSD). |
| URL fetching | `httpx` + `tenacity` retries. Respect robots.txt. |
| DuckDB queries | `motherduck` MCP, or `duckdb` CLI. |
| DuckDB Node bindings | `duckdb-async` (in the harness). |
| Live library docs | `context7` MCP. |
| JS-rendered pages / DevBox UI | `playwright` MCP. |
| Knowledge graph | `memory` MCP. |
| Source-ranked methodology | Brendan Gregg USE method, Google SRE Ch. 12, Julia Evans zines. |

## Don't do these

- **Don't write a custom HTML parser.** Trafilatura first. Custom parsers only for sources where trafilatura genuinely loses signal (some man pages with critical SYNOPSIS structure).
- **Don't build a custom workspace tool.** `pnpm package add` exists.
- **Don't redistribute proprietary docs.** Cite + URL only for `license_note: reference-only`.
- **Don't commit raw fetch caches.** They're gitignored under `domains/**/raw/` and `_db/raw/`. Source-of-truth is the URL + extracted JSON.
- **Don't skip the plan-mode meta-research.** Phase 1 (Explore) is cheap; Phase 4 (failure-modes) is irreducible work. The first protects the second from waste.

## Interview-day evaluation criteria — keep in mind every session

- **Efficiency** — the harness must give me an answer faster than re-Googling.
- **Clarity of thought** — the corpus structure must support narrating "I'm checking X because Y, which would prove/disprove Z".
- **Communication** — every claim cites a `source_id`. Read the URL out loud if needed.
- **Curiosity / clarifying questions** — drill the habit; the harness should facilitate "wait, before I dig in, can you tell me X?"
- **Trade-off thinking** — the chains in `meta.all_relationships` are how I explain "fixing this here vs. there".
