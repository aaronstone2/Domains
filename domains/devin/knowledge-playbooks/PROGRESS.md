# `devin/knowledge-playbooks` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 19 concepts / 8 commands / 15 config_keys (targets ~15/~5/~15 — exceeded all).

**Source coverage:** All 4 knowledge-playbooks docs (product-knowledge, product-playbooks, product-using-playbooks, product-secrets, knowledge-onboarding). Cross-referenced into `devin/api` (knowledge/playbook/secret API rows), `devin/integrations` (Jira/Linear macro labels), `devin/enterprise` (cascading secret precedence + best practices), `devin/devbox` (blueprint knowledge sections + secret reference syntax).

**Source-id integrity:** all references resolve.

**Highlights:**
- 3-tier knowledge model (enterprise / org / repo) with additivity semantics.
- Knowledge note schema (name / trigger / body).
- Playbook macro identifier system + label-trigger flow into Jira/Linear/Slack.
- Default-playbook setting per integration.
- Secret cascade precedence (enterprise → org → repo, more specific wins).
- "Never YAML" secret rule.
- Programmatic CRUD via Devin MCP server (devin_playbook_manage + devin_knowledge_manage).
- Knowledge suggestions (AI-generated pending entries).

## Phase 4 candidates

- Knowledge-source indexing stuck (slow IO on large corpus).
- Playbook parameter validation rejecting typo.
- Secret reference unresolved at runtime (name mismatch).
- Knowledge-search relevance miss (BM25 P1 verification surfaced this for "playbook secret reference").
- Playbook trigger condition not met (silently skipped).
- Same-name secret at multiple tiers — wrong tier wins.
- Macro label collision (two playbooks with same `!macro`).

## Phase 5 candidates

- knowledge-playbooks.playbook ↔ devbox.devbox-runtime (execution context)
- knowledge-playbooks.secret ↔ devbox.secrets-manager (mounting)
- knowledge-playbooks.playbook ↔ integrations.<provider> (credential reference)
- knowledge-playbooks.knowledge-source ↔ api.knowledge-* endpoints
- knowledge-playbooks.macro ↔ integrations.jira-playbook-label / integrations.linear-synced-playbook-label
