# Plan — `devin/product`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** This is the broadest leaf — it catalogs Devin's user-facing features, plans/tiers, modes, capabilities, deployment options, multi-agent fleet semantics, web search, single-threaded-write, verification mode, proactive mode, wake-up mode, follow-ups, voice mode, attachments, and the full release-notes timeline (2024 / 2025 / 2026). **Failure modes here are mostly UX-shaped (a feature isn't enabled for the org, a plan tier doesn't include the capability, the deployment option isn't supported on a self-hosted install) rather than runtime crashes.**

**How it composes upward.** Product features cite the runtime-and-API substrate underneath — every product feature (e.g., "single-threaded write") implies API surface (devin/api), DevBox runtime support (devin/devbox), and possibly knowledge-playbook integration (devin/knowledge-playbooks). Done last so the runtime/API anchors exist for cross-references.

## Inputs already available (P1 deliverables)

- 33 documents, ~634,417 chars total, ~19,225 chars avg.
- Top sources by size: `devin-docs-sitemap` (264 KB — sitemap text dump), `devin-docs-llms-index` (51 KB), `devin-docs-release-notes-2025` (47 KB), `devin-docs-release-notes-2026` (39 KB), `devin-docs-release-notes-overview` (36 KB), `devin-docs-release-notes-2024` (23 KB), `devin-docs-product-playbooks` (BM25 top hit for "slack integration message delivery"), `devin-docs-onboard-agents-md`.

## Phase A — Survey ✅ done by P1

33 sources catalogued. Use-cases / tutorials / gallery (~25 pages) deferred per Session 1.1; not blocking P3.

## Phase B — Document ingest ✅ done by P1

All 33 docs in `devin.documents`, FTS-indexed.

## Phase C — Structured extraction (THIS SESSION)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.product.*`.

- [ ] **Concepts pass.** Target ~60 rows. `kind` values: `feature | mode | plan | role | deployment | capability | release-note`. Concepts: `single-threaded-write`, `verification-mode`, `proactive-mode`, `wake-up-mode`, `multi-agent-fleet`, `cloud-agent`, `web-search`, `voice-mode`, `attachments`, `follow-ups`, `pull-request-mode`, `chat-mode`, `task-mode`, `slack-integration` (cross-link to integrations.slack-integration), `notion-integration` (cross-link), `linear-integration` (cross-link), `playbooks-feature`, `knowledge-feature`, `secrets-feature`, `repositories-feature`, `snapshots-feature`, `team-feature`, `org-feature`, `core-plan`, `team-plan`, `enterprise-plan`, `plan-cloud-deploy`, `plan-self-hosted`, `plan-byov-cloud`, `plan-multi-tenant`, `plan-single-tenant`. Plus 2024/2025/2026 release-notes feature deltas as `kind=release-note` rows when they introduce a new concept (`web-search-launch`, `voice-mode-launch`, `multi-agent-launch`, etc.).
- [ ] **Commands pass.** Target ~10 rows. Devin-CLI / web-UI commands surfaced in product docs (start-session, stop-session, attach-file, configure-playbook).
- [ ] **Config keys pass.** Target ~25 rows. `scope` values: `feature-flag | plan-feature | mode-config`. Each plan tier has a featureset; each mode has a small config surface.

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates:
- Feature unavailable on plan (Core trial limits).
- Self-hosted deployment missing a feature available only on cloud.
- Voice-mode misconfiguration (audio device permissions in the browser).
- Multi-agent fleet contention (over-provisioning).
- Wake-up-mode triggering during an active session (race condition).

## Phase E — Relationships (DEFERRED to horizontal P5)

- product.<feature> ↔ devbox.<runtime-object> for every feature with runtime backing.
- product.<feature> ↔ api.<endpoint> for every feature with API surface.
- product.<plan> ↔ enterprise.<feature-flag> for every plan-gated feature.

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP.

## Open questions

- Release-notes entries are timestamped events. Do they get one concept row each, or one umbrella `release-2025-q3` row that lists every feature delta? Decision: one row per *new feature introduced* (kind=release-note), citing the release notes URL. Pure bug-fix entries skipped.
