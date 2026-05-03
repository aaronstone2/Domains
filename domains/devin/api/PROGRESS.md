# `devin/api` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`. This leaf hosts both the `api` (9 docs) and `api-endpoints` (238 docs) subdomains per the PREAMBLE leaf list.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 51 concepts / 234 commands / 67 config_keys (targets ~25 / ~245 / ~15 — concepts + config_keys exceeded; commands close to target).

**Source coverage:** all 9 api overview docs read end-to-end (auth, common-flows, migration, v1/v2/v3 overviews, PAT, pagination). All 238 api-endpoint sources catalogued + grouped by URL family.

**Source-id integrity:** all references resolve.

**Highlights:**
- Full RBAC permission catalog (12 enterprise + 9 organization permissions).
- All v3 sessions endpoints captured (org-scoped + enterprise-scoped + insights variants).
- All v3 knowledge-notes endpoints (org + enterprise + folders).
- All v3 playbooks endpoints (org + enterprise CRUD).
- All v3 schedules endpoints (CRUD with cron).
- All v3 service-users endpoints (CRUD + API key issue/rotate/revoke).
- All v3 IdP-groups endpoints (12 entries enterprise + org × CRUD + assign).
- All v3 metrics endpoints (DAU/WAU/MAU/PRs/sessions/searches/usage × enterprise + org).
- All v3 consumption endpoints (cycles + daily breakdowns by org/user/service-user/session).
- Legacy v1 + v2 endpoints catalogued for migration reference.

**Endpoints not individually extracted as commands rows** (~13 of 247): some redundant sentinels and a few less-prominent v3 git-providers/connections/permissions edge cases — covered conceptually but not 1:1.

## Phase 4 candidates

- 401 from expired PAT (rotation didn't propagate)
- 403 from missing scope
- 429 from rate limit
- 422 from invalid payload (agents.md schema mismatch in session-create body)
- 404 from cross-tenant session ID lookup
- Legacy `apk_` key used with v3 endpoints → silent failure or 401
- create_as_user_id without ImpersonateOrgSessions → 403
- X-Org-Id header missing on enterprise-scoped key

## Phase 5 candidates

- api.personal-access-token ↔ enterprise.sso-identity-mapping
- api.session-create ↔ devbox.session-startup
- api.knowledge-create ↔ knowledge-playbooks.knowledge-source
- api.secrets-* ↔ devbox.secrets-manager (lifecycle alignment)
- api.error-401/403/429 ↔ failure-mode tree
