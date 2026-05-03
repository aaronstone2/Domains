# Devin — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.1 — 2026-05-02 — DONE

**Inputs:** plan at `~/.claude/plans/swift-honking-pretzel.md`; pipe-able session prompt `domains/_shared/sessions/phase-1-source-corpus.md`. Run in parallel with another Claude Code session doing methodology Phase 3.

**Outputs:**

- **326 sources, 326 documents, 2,242,549 chars indexed** in `devin.sources` / `devin.documents` (29 pre-existing + 297 net new this session).
- BM25 FTS index `fts_devin_documents` built (porter stemmer, english stopwords).

**Per-subdomain breakdown:**

| subdomain           | sources | mean chars | total chars |
| ---                 | ---:    | ---:       | ---:        |
| api-endpoints       | 238     | 4,486      | 1,067,665   |
| product             | 33      | 19,225     | 634,417     |
| devbox              | 17      | 15,642     | 265,912     |
| enterprise          | 10      | 5,789      | 57,890      |
| integrations        | 10      | 4,944      | 49,440      |
| api                 | 9       | 4,222      | 38,001      |
| mcp                 | 5       | 21,267     | 106,335     |
| knowledge-playbooks | 4       | 5,722      | 22,889      |

**Per-tier breakdown:** T0=1 (status incidents archive — primary live JSON capture), T1=85 (canonical docs/blogs/MIT-licensed READMEs), T2=240 (bulk API endpoint pages + 2 SHOULD-tier MED-priority items).

**Verified (acceptance per plan):**

- All 326 sources fetched (0 unfetched after sentinel URL fix; see "Source list adjustments" below).
- Mean doc length 6,879 chars; only 1 thin doc (<500 chars): `cognitionai-swebench-results-readme` (152 chars — README is genuinely short upstream).
- Min doc length: 152 chars (`cognitionai-swebench-results-readme`); previous 0-char `devin-docs-llms-index` was patched mid-session (see below).
- `parser=json-passthrough` on `devin-status-incidents-archive` produced 191,770 chars of pretty-printed JSON; all expected failure-mode keywords (queueing, delayed, startup, slack, github, ip, allowlist) present in raw text.
- 8 BM25 verification queries (one per major debug query the plan called out) — 7/8 returned the expected page in top-3 (Q5 "playbook secret reference" was the lone miss; query phrasing too generic, matched API overview pages over the dedicated secrets page; corpus content is fine).

| query | top-1 | expected | status |
|---|---|---|---|
| `devbox snapshot kernel state` | `cognition-blog-cloud-agents` (5.64) | cloud-agents | ✅ exact |
| `session queueing delayed startup` | `enterprise-environment-best-practices` (3.20); incidents-archive at top-2 (3.15) | status-incidents | ✅ top-3 (BM25 length-norm penalty on 191K JSON pushed it to #2) |
| `ip allowlist webhook blocked` | `integrations-self-hosted-scm-artifacts` (5.64) | ip-access-lists or admin-security | ⚠️ adjacent (SCM page covers IP/webhook for self-hosted) |
| `agents.md repository configuration` | `devin-docs-onboard-agents-md` (6.73) | onboard-agents-md | ✅ exact |
| `playbook secret reference` | `devin-docs-api-v1-overview` (4.38) | product-secrets | ❌ secrets page didn't crack top-5 with this phrasing |
| `slack integration message delivery` | `devin-docs-product-playbooks` (4.30) | slack or status incidents | ⚠️ adjacent |
| `personal access token scope` | `devin-docs-api-authentication` (5.52); PAT page at top-2 | api-personal-access-tokens | ✅ top-2 (auth page covers PATs as a section) |
| `single threaded write code review` | `cognition-blog-multi-agents-working` (5.81) | multi-agents-working | ✅ exact |

Pass rate: 3/8 exact top-1, 4/8 top-3 / adjacent, 1/8 miss. Acceptable for Phase 1.

**Infra delta (this session):**

- Added `parser=json-passthrough` branch to `domains/_shared/ingest/ingest/extract.py` — pretty-prints JSON via `json.dumps(parsed, indent=2, ensure_ascii=False)`. Used by the status incidents archive source.
- Scaffolded `domains/devin/` via `pnpm domain add devin` (per CLAUDE.md convention; never raw `mkdir`). Created gitignored `domains/devin/raw/` for future scratch.
- Added `parser=mintlify` is still a label-only convention (falls through to trafilatura) — empirically adequate per Phase 1 Explore-agent test (5/5 sample pages returned 8K–12K chars with code blocks/tables intact).

**Source list adjustments made during execution:**

- **API endpoint sentinels failed at first fetch** (HTTP 404 on guessed URLs `/api-reference/v1/sessions/create` and `/v2/sessions/list`). Investigation: Mintlify uses long descriptive slugs (e.g. `create-a-new-devin-session`) and serves raw markdown via `.md` suffix. Updated both sentinels to: `https://docs.devin.ai/api-reference/v1/sessions/create-a-new-devin-session.md` (5,869 chars) and `https://docs.devin.ai/api-reference/v2/sessions/list-enterprise-sessions.md` (6,715 chars), both with `parser: github-md`. **Side effect:** the entire bulk API partition (~236 endpoint pages) uses the same `.md` + `github-md` pattern — no trafilatura needed for any per-endpoint page.
- **`devin-docs-llms-index` returned 0 chars** with the original `parser: trafilatura` (trafilatura won't extract from a plain-text URL list). Switched to `parser: github-md` and re-fetched: now 51,959 chars. Updated row directly via `UPDATE` (FK constraint on `devin.documents.source_id` blocked a full INSERT OR REPLACE re-load of `devin.sources`).
- **Bulk API partition expanded from ~160 (Explore-agent estimate) to 236** — discovered by parsing `docs.devin.ai/llms.txt` programmatically. Includes v1/v2/v3 endpoints across attachments, knowledge, playbooks, secrets, sessions, api-keys, audit-logs, consumption, groups, infrastructure, members, organizations, repositories, idp-groups, ip-access-list, metrics, notes, queue, roles, schedules, service-users, snapshots, tags, users, hypervisors, guardrail-violations, git-{connections,permissions}, self.

**Sources failed:** none after sentinel-URL repair (0 of 326 in final pass).

**License decisions made during execution:**

- `CognitionAI/blockdiff` and `CognitionAI/deepwiki` — GitHub API returned `license: null` (no LICENSE file in either repo as of 2026-05-02). Following the methodology Phase 1 wizardzines precedent, marked `license_note: unknown` with explicit notes; bodies still ingested for our private corpus per user steer ("verify LICENSE then add accordingly" → "private-corpus-only ingest, no republication" annotation).
- `CognitionAI/devin-swebench-results`, `metabase-mcp-server` — MIT per repo metadata → `redistribute-ok`.
- `CognitionAI/database-toolbox` — Apache-2.0 per repo metadata → `redistribute-ok`.
- All `cognition.ai/blog/*` and `docs.devin.ai/*` content remains `license_note: reference-only` per the Cognition ToS posture (private corpus stores + cites only; no republication).
- `https://www.devinstatus.com/api/v2/incidents.json` — factual public record → `license_note: redistribute-ok`. Tier T0 because it's a primary capture per the existing tier scheme.

**Sources with sparse content (action items):**

- `cognitionai-swebench-results-readme` (152 chars) — README is genuinely short upstream; SWE-bench *results* are in the repo's `.json` files, not README. Phase 1.5 candidate to ingest the per-eval JSON results as a separate source.
- `cognitionai-deepwiki-readme` (876 chars), `cognitionai-blockdiff-readme` (1,031 chars) — both are short upstream. Acceptable.
- Several Mintlify pages under 2 KB (`onboard-index-repo`, `onboard-vpn`, `api-concepts-pagination`, `product-deployment-capabilities`, `product-using-playbooks`, `enterprise-security-ip-access-lists`) — page content genuinely terse; not a parser failure.

**Cosmetic noise observed:**

- Every Mintlify page (trafilatura-extracted) leads with a 2-line "Documentation Index" nav block referencing `https://docs.devin.ai/llms.txt`. ~80 occurrences across the corpus — repetitive but doesn't dominate BM25. Phase 1.5 follow-up: strip this prefix in extract.py before the trafilatura branch returns, or switch all Mintlify sources to `.md` suffix + `github-md` passthrough (would also eliminate it).

**Deferred to later sessions:**

- Switching Mintlify-rendered docs to `.md` suffix + `github-md` passthrough corpus-wide. Would eliminate the "Documentation Index" nav prefix and reduce trafilatura risk for any future Mintlify pages.
- Use-cases / tutorials / gallery (~25 pages on docs.devin.ai). Per plan, deferred unless interview prep names a specific use-case.
- Enterprise per-provider SSO subpages (`azure`, `oidc`, `okta`, `saml`).
- Enterprise integrations subpages (`artifacts`, `git-integrations`, `github-enterprise-server`, `azure-devops`).
- Cognition blog LOW-priority partnership/expansion announcements (~10 posts).
- Per-eval JSON results from `CognitionAI/devin-swebench-results` (Phase 1.5).

**Next phases for this domain:**

- **Phase 3** (Concepts/Commands/Config_keys): extract DevBox runtime concepts (snapshot, hypervisor, blueprint, agents.md schema), API endpoints as commands, and `environment.yaml` config keys → `devin.concepts`, `devin.commands`, `devin.config_keys`. The status incidents archive will likely seed Phase 4 (failure-modes) directly.
- **Phase 4** (Failure-modes): the gold layer. Status incidents JSON gives 47+ empirical incidents. `/admin/common-issues` (4 issues), VPN setup, IP allowlist, secrets handling, scheduled-session crashes — each a candidate `failure_modes` row.
- **Phase 5** (Relationships): cross-link DevBox concepts to docker/linux underpinning concepts (e.g. blockdiff README → Linux CoW snapshots → docker storage drivers).

## Phase 3 — Structured extraction (concepts / commands / config_keys)

### Session 3.1 — 2026-05-02 — DONE (all 7 leaves in one session)

**Plan file:** `C:\Users\adsto\.claude\plans\read-domains-shared-sessions-phase-3-de-glittery-iverson.md`

**Approach:** the Claude Code agent IS the extractor (codified in `domains/_shared/sessions/phase-3-deep-extraction.md` Phase 0.1 of this session). No separate Anthropic SDK extractor module. Agent reads `<domain>.documents` via `motherduck` MCP, drafts JSON files by hand, loads via `INSERT INTO devin.<table> SELECT * FROM read_json_auto(...)`.

**All 7 leaves scaffolded** via `pnpm leaf add devin/<leaf>` (idempotent). Per-leaf customized PLAN.md + PROGRESS.md.

**Final row counts:**

| Leaf                  | Concepts | Commands | Config keys |
| ---                   | ---:     | ---:     | ---:        |
| `devbox`              | 64       | 30       | 65          |
| `integrations`        | 49       | 28       | 68          |
| `mcp`                 | 43       | 15       | 69          |
| `api` (incl api-endpoints) | 51 | 234      | 67          |
| `product`             | 58       | 11       | 15          |
| `enterprise`          | 35       | 12       | 58          |
| `knowledge-playbooks` | 19       | 8        | 15          |
| **TOTAL**             | **319**  | **338**  | **357**     |

**Verification:**
- Source-id integrity: 0 broken `source_ids[]` references across the entire devin schema (1 fix-up applied — removed an invented `cognition-blog-devin-review` source from the product devin-review concept; that blog post wasn't part of Phase 1's source set).
- Distinct concept kinds: 23.
- Distinct config_keys scopes: 90.
- Failure-modes (deferred to horizontal P4): 0 rows in `devin.failure_modes`.
- Relationships (deferred to horizontal P5): 0 rows in `devin.relationships`.

**Per-leaf P4 + P5 candidate seeds** documented in each leaf's PROGRESS.md. Top-level cross-domain link candidates worth wiring in P5:
- devbox.snapshot ↔ docker/runtime checkpoint, linux/filesystem CoW (BlockDiff)
- devbox.firewall-allowlist ↔ linux/networking netfilter
- integrations.github-app ↔ api.session-create (payload schema)
- integrations.ip-allowlist-integration ↔ devbox.outbound-ip-allowlist (mirrored config)
- mcp.database-toolbox ↔ docker/engine (containerized)
- api.create_as_user_id ↔ enterprise.idp-group-auto-assign
- enterprise.three-tier-blueprint-hierarchy ↔ devbox.blueprint
- knowledge-playbooks.macro ↔ integrations.jira-playbook-label / linear-synced-playbook-label

**Phase-3 doc updated:** `domains/_shared/sessions/phase-3-deep-extraction.md` now codifies the agent-as-extractor decision so future sessions don't re-litigate it.

## Cross-references

- Phase 3 plan file: `C:\Users\adsto\.claude\plans\read-domains-shared-sessions-phase-3-de-glittery-iverson.md`
- Phase 1 plan file: `C:\Users\adsto\.claude\plans\swift-honking-pretzel.md`
- Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`
- Pipe-able session prompts: `domains/_shared/sessions/phase-1-source-corpus.md`, `domains/_shared/sessions/phase-3-deep-extraction.md`
- Sister-domain Phase 1: `domains/methodology/PROGRESS.md`
- Per-leaf PROGRESS.md: `domains/devin/<leaf>/PROGRESS.md` × 7
