# Plan — `devin/integrations`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** Devin needs to read code from upstream SCM (GitHub / GitLab / Bitbucket / Azure DevOps), write artifacts to package registries (npm, PyPI, container registries), and emit signals back to humans (Slack, Linear, Jira). The `integrations` subdomain catalogs every external system Devin can connect to, the auth flows for each, the IP allowlist + webhook pathways, and the self-hosted-SCM artifact-upload mechanics. **Failure modes here surface as integration-handshake denials, webhook drops, OAuth token expiry, IP allowlist blocks at the SCM end, push permission failures, and self-hosted-runner artifact upload errors.**

**How it composes upward.** This leaf surfaces in `devin/devbox` (integration credentials get materialized inside DevBox at session start) and `devin/api` (session-create endpoint accepts integration-handle parameters). Underneath, it depends on `linux/networking` (netfilter / iptables for IP allowlists), `docker/engine` (containers run the integration sidecars where applicable), and HTTPS/TLS plumbing.

## Inputs already available (P1 deliverables)

- 10 documents in `devin.documents` filtered by `subdomain = 'integrations'`. Total ~49,440 chars; mean ~4,944 chars.
- Headline source: `integrations-self-hosted-scm-artifacts` (covered IP/webhook for self-hosted SCM in BM25 verification).
- Cross-references: many integration auth concepts also appear in `enterprise` (SSO) and `api` (PAT scopes).

## Phase A — Survey ✅ done by P1

10 sources catalogued. Per-provider integration sub-pages (`artifacts`, `git-integrations`, `github-enterprise-server`, `azure-devops`) were deferred per Session 1.1 — if needed during extraction, patch into `sources.yaml` and re-fetch. Don't block this session on missing sub-pages; extract what's available.

## Phase B — Document ingest ✅ done by P1

All 10 docs in `devin.documents`, FTS-indexed.

## Phase C — Structured extraction (THIS SESSION)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.integrations.*`.

- [ ] **Concepts pass.** Target ~30 rows. `kind` values: `integration | provider | webhook | credential | feature | scope`. Concepts to capture: `github-app`, `github-oauth`, `gitlab-integration`, `bitbucket-integration`, `azure-devops-integration`, `slack-integration`, `linear-integration`, `jira-integration`, `notion-integration`, `confluence-integration`, `artifact-upload`, `npm-registry-integration`, `pypi-registry-integration`, `container-registry-integration`, `self-hosted-scm`, `self-hosted-runner`, `webhook-handler`, `webhook-signature-verification`, `ip-allowlist-integration`, etc.
- [ ] **Commands pass.** Target ~10 rows. Devin-CLI / web-UI command flows surfaced in docs: connect-integration, disconnect-integration, rotate-integration-token, test-webhook, list-integrations.
- [ ] **Config keys pass.** Target ~30 rows. `scope` values: `github | gitlab | bitbucket | azure-devops | slack | linear | jira | notion | confluence | artifact-upload | self-hosted-scm`. Each scope has a small set of keys (`webhook-secret`, `app-id`, `client-id`, `client-secret`, `installation-id`, `token`, `region`, `endpoint`, etc.).

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates for P4 (logged in PROGRESS.md):
- IP allowlist denials at SCM webhook ingress.
- OAuth token rotation drops mid-session.
- Webhook signature mismatch causing payload rejection.
- Self-hosted SCM runner artifact-upload TLS failures.
- GitHub-App installation removed mid-session → 403 mid-clone.

## Phase E — Relationships (DEFERRED to horizontal P5)

- integrations.github-app ↔ devin/api.session-create payload
- integrations.webhook-signature-verification ↔ linux/networking TLS handshake
- integrations.ip-allowlist-integration ↔ devbox.firewall-allowlist (mirrored config)
- integrations.artifact-upload ↔ docker/engine registry-push semantics

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP, memory MCP — same as devbox.

## Open questions

- Per-provider integration sub-pages deferred from P1. Decide in P3 whether to fetch them during this extraction or punt to a Phase 1.5 enrichment session.
