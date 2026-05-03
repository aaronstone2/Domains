# Plan — `devin/enterprise`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** Enterprise covers the org/admin/security/compliance plane — SSO providers, RBAC roles, IP allowlists, audit-log retention, IDP-group sync, environment best practices, single-tenant deployment configurations, BYOC (bring-your-own-cloud), and enterprise-only feature flags. **Failure modes here surface as SSO redirect loops, IDP-group sync drops, role/scope mismatches at session start, IP-allowlist deny-all misconfigurations, and audit-log retention overruns.**

**How it composes upward.** Enterprise is the gating layer — every product feature passes through enterprise's RBAC and SSO checks. It surfaces directly in `devin/api` (PAT / API-key scopes are derived from RBAC roles) and in `devin/devbox` (the IP allowlist applies to the DevBox firewall).

## Inputs already available (P1 deliverables)

- 10 documents, ~57,890 chars total, ~5,789 chars avg.
- Headline sources: `enterprise-environment-best-practices`, `enterprise-security-ip-access-lists`, plus org admin / SSO setup pages.
- Per-provider SSO subpages (azure / oidc / okta / saml) deferred from P1; integrations subpages (artifacts / git-integrations / github-enterprise-server / azure-devops) also deferred.

## Phase A — Survey ✅ done by P1

10 sources catalogued. Per-provider SSO and integration sub-pages deferred — not blocking P3 but worth noting in PROGRESS.md as P1.5 enrichment candidates.

## Phase B — Document ingest ✅ done by P1

All 10 docs in `devin.documents`, FTS-indexed.

## Phase C — Structured extraction (THIS SESSION)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.enterprise.*`.

- [ ] **Concepts pass.** Target ~20 rows. `kind` values: `feature | role | provider | policy | deployment | compliance`. Concepts: `sso-saml`, `sso-oidc`, `sso-azure-ad`, `sso-okta`, `idp-group-sync`, `rbac-role`, `service-account`, `ip-access-list`, `ip-access-list-entry`, `audit-log-retention`, `audit-log-export`, `single-tenant-deployment`, `byoc-deployment`, `vpn-config`, `enterprise-environment-best-practices`, `data-residency`, `compliance-soc2`, `compliance-iso27001`, `org-admin-role`, `member-role`, `service-user-role`.
- [ ] **Commands pass.** Target ~5 rows. Org-admin commands: `add-ip-allowlist-entry`, `rotate-org-api-key`, `assign-rbac-role`, `sync-idp-groups`, `export-audit-log`.
- [ ] **Config keys pass.** Target ~25 rows. `scope` values: `sso | idp | rbac | ip-allowlist | audit-log | byoc | data-residency`. Examples: `sso.saml.entity-id`, `sso.oidc.client-id`, `idp.azure.tenant-id`, `rbac.default-role`, `ip-allowlist.cidr`, `audit-log.retention-days`, `byoc.aws-region`.

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates:
- SSO redirect loop (entity-id mismatch).
- IDP-group sync stale (group membership change not reflected in Devin).
- IP-allowlist misconfig blocking org admin's own IP.
- Audit-log export hits retention floor mid-export.
- BYOC region not supported by Devin's underlying provider.

## Phase E — Relationships (DEFERRED to horizontal P5)

- enterprise.sso-saml ↔ api.personal-access-token (PAT issuance gated by SSO group)
- enterprise.ip-access-list ↔ devbox.firewall-allowlist (config mirrored)
- enterprise.rbac-role ↔ api.pat-scope (scope derived from role)
- enterprise.byoc-deployment ↔ devbox.devbox-runtime (BYOC affects runtime location)

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP.

## Open questions

- Per-provider SSO subpages (azure / oidc / okta / saml) deferred from P1. If P3 needs richer config keys for them, ingest them as a P1.5 patch.
