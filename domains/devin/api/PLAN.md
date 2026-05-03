# Plan — `devin/api`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

> **Scope note.** This leaf hosts BOTH the `api` subdomain (auth/PAT/keys overview pages, 9 sources) AND the `api-endpoints` subdomain (238 per-endpoint REST refs). Per the PREAMBLE leaf list, no separate `api-endpoints` leaf folder exists; everything lands in this folder. The 238 endpoint pages each yield one `commands` row.

## Context

**Why this leaf exists.** The Devin API is the programmatic surface — every customer integration (CI gates, scheduled-session orchestration, attachment uploads, knowledge-playbook management, secrets manipulation) goes through it. The auth model is Personal Access Tokens (PATs) with scoped permissions, plus organization-level API keys. The endpoint surface spans v1, v2, and v3 namespaces covering: sessions, agents, attachments, knowledge, playbooks, secrets, repositories, snapshots, hypervisors, audit-logs, consumption, groups, infrastructure, members, organizations, idp-groups, ip-access-list, metrics, notes, queue, roles, schedules, service-users, tags, users, guardrail-violations, git-{connections,permissions}, self. **Failure modes here surface as 401 (token expired/revoked), 403 (insufficient scope), 429 (rate limit), 422 (invalid payload), and 5xx (transient back-end issues).**

**How it composes upward.** The API is the public face of everything: it hands sessions off to `devin/devbox`, references credentials from `devin/integrations`, mounts `devin/mcp` servers, executes `devin/knowledge-playbooks`, and exposes everything to enterprise via `devin/enterprise` (SSO/RBAC). Underneath, the API depends on standard HTTP(S) plumbing.

## Inputs already available (P1 deliverables)

- **api subdomain (9 docs):** ~38,001 chars total, ~4,222 chars avg. Headline source: `devin-docs-api-authentication` (covers PATs in BM25 verification — top-1 for "personal access token scope").
- **api-endpoints subdomain (238 docs):** ~1,067,665 chars total, ~4,486 chars avg. Each is a single REST endpoint reference in raw markdown (parser=github-md, .md suffix served by Mintlify). The 238 cover v1+v2+v3 across all the namespaces listed above.

## Phase A — Survey ✅ done by P1

247 sources catalogued combined. The endpoint expansion from ~160 (Explore-agent estimate) to 236 was discovered by parsing `docs.devin.ai/llms.txt` programmatically — see Session 1.1.

## Phase B — Document ingest ✅ done by P1

All 247 docs in `devin.documents`, FTS-indexed.

## Phase C — Structured extraction (THIS SESSION — full depth, all 238 endpoints)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.api.*`.

- [ ] **Concepts pass.** Target ~25 rows covering the auth + general-API plane (the 9 api docs). `kind` values: `auth | scope | resource | feature | api-version`. Concepts: `personal-access-token`, `api-key`, `service-user`, `pat-scope`, `pat-rotation`, `api-rate-limit`, `pagination-cursor`, `idempotency-key`, `webhook-callback`, `api-versioning-v1`, `api-versioning-v2`, `api-versioning-v3`, `error-code-401`, `error-code-403`, `error-code-422`, `error-code-429`, `audit-log-entry`, `consumption-metric`, `guardrail-violation`, etc.
- [ ] **Commands pass.** Target ~245 rows — **one per endpoint** in `api-endpoints` plus a small handful for the 9 `api` overview docs (e.g., "create PAT", "rotate PAT" surfaced in auth docs). Each `commands` row uses the HTTP method + path as the `command` field (e.g., `POST /v1/sessions`), `purpose` summarizes what the endpoint does, `flags[]` lists request body / query params / path params, `examples[]` shows a representative invocation. Use `id = devin.api.cmd.<verb>-<slug>` (e.g., `devin.api.cmd.post-v1-sessions-create`).
- [ ] **Config keys pass.** Target ~15 rows. `scope` values: `auth | rate-limit | webhook | api-client`. Auth-side config: token scope flags, allowed scopes list, IP-access-list keys.

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates:
- 401 from expired PAT (rotation didn't propagate).
- 403 from missing scope (e.g., session-write scope absent).
- 429 from rate limit (per-org cap hit during scripted batch operation).
- 422 from invalid payload (agents.md schema mismatch in session-create body).
- 404 from referencing a session ID across orgs (cross-tenant leakage prevention).

## Phase E — Relationships (DEFERRED to horizontal P5)

- api.personal-access-token ↔ enterprise.sso-identity-mapping
- api.session-create ↔ devbox.session-startup
- api.knowledge-create ↔ knowledge-playbooks.knowledge-source
- api.secrets-* ↔ devbox.secrets-manager (lifecycle alignment)

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP.

## Open questions

- The 238 endpoint extractions are ~mostly mechanical (URL pattern + HTTP method + raw markdown body). To stay fast: read the full set of titles + URLs first, group by URL prefix family, write the JSON in batches per family. Don't read every body verbatim — read the family's representative endpoint, then synthesize the family's other rows by URL pattern.

## Bulk-endpoint extraction strategy (concrete)

The 238 endpoints follow predictable families. Plan:

1. `SELECT id, url FROM devin.sources WHERE subdomain='api-endpoints' ORDER BY url` → one query, get the full sorted URL list.
2. Group by URL prefix path family: `/v1/sessions/*`, `/v2/sessions/*`, `/v3/sessions/*`, `/v1/attachments/*`, `/v1/knowledge/*`, `/v1/playbooks/*`, `/v1/secrets/*`, etc.
3. For each family, read one representative doc body to learn the response/request shape, then write `commands` rows for every member of the family with the family's known shape.
4. Edge cases (admin-only endpoints, beta endpoints) get individual reads.

This yields ~238 rows but with bounded per-row reading.
