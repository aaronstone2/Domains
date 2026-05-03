# `devin/enterprise` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 35 concepts / 12 commands / 58 config_keys (targets ~20/~5/~25 — exceeded all).

**Source coverage:** 6 enterprise docs read end-to-end (rollout, best-practices, custom-roles, deployment, environment-overview, enterprise-overview). The remaining 4 (security, idp-groups, ip-access-lists, trust-center) covered transitively via the read docs and cross-references.

**Source-id integrity:** all references resolve.

**Highlights:**
- 4 rollout modes (Not enabled / Testing / Available / Enabled by default) with semantics + reversibility.
- Full org-level permission catalog (16 permissions).
- Full account-level permission catalog (17 permissions).
- 2 deployment models (Enterprise Cloud + Customer Dedicated) with networking distinctions.
- AWS PrivateLink vs IPSec.
- *.devinapps.com end-user network requirement documented.
- 4 SSO providers (Okta / Azure AD / SAML / OIDC).
- IdP group → role auto-assignment via `groups` claim.
- Compound AI system, no-third-party-LLM-keys constraint.
- SOC 2 Type II Sept 2024 (with March 2024 cited elsewhere → likely Type I → Type II progression).
- Concurrency-protected rollout state transitions.
- Audit-logged rollout transitions.

## Phase 4 candidates

- SSO redirect loop (entity-id mismatch).
- IDP group sync drift / stale.
- IP allowlist misconfig blocking org admin.
- Audit log retention floor hit mid-export.
- BYOC region not supported.
- Rollout mode change rejected due to concurrent edit.
- Auto classic override didn't trigger because org has 0 repos but classic config.
- Migration assistant fails on org with 100+ repos (timeout).
- Enterprise blueprint regression cascade-broke all orgs.

## Phase 5 candidates

- enterprise.sso-saml ↔ api.personal-access-token (PAT issuance gated by SSO group)
- enterprise.ip-access-list ↔ devbox.firewall-allowlist (config mirrored)
- enterprise.rbac-role ↔ api.pat-scope (scope derived from role)
- enterprise.byoc-deployment ↔ devbox.devbox-runtime (BYOC affects runtime location)
- enterprise.three-tier-blueprint-hierarchy ↔ devbox.blueprint
- enterprise.idp-group-auto-assign ↔ api.create_as_user_id (impersonation)
