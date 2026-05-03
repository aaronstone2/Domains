# `devin/integrations` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 49 concepts / 28 commands / 68 config_keys (targets ~30/~10/~30 — exceeded all).

**Source coverage:** all 10 integration docs read end-to-end (GitHub, GitLab, Bitbucket, Microsoft Teams, Slack, Jira, Linear, Self-Hosted SCM/Artifacts, PR Templates, Overview).

**Source-id integrity:** all references resolve.

**Highlights:**
- Full GitHub App permission catalog (read + read+write columns) — 17 individual config_keys.
- Slack OAuth scopes catalog — 7 scope groups.
- Microsoft Teams Graph + RSC permission catalog — 12 permissions covering both tenant-wide and per-Team/Chat scopes.
- Jira + Linear automation-trigger config (projects/labels/statuses/playbook + edge-detection semantics).
- PR template search-path inventory (6 paths + fallback).
- GPG commit-signing config (GIT_USER_NAME, GIT_USER_EMAIL, base64 private key).
- Self-hosted SCM/artifacts deployment patterns (NLB Layer 4 vs ALB Layer 7 + WAF).

## Phase 4 candidates

- IP allowlist denials at SCM webhook ingress.
- OAuth token rotation drops mid-session.
- Webhook signature mismatch.
- Self-hosted runner artifact-upload TLS failures.
- GitHub-App installation removed mid-session → 403 mid-clone.
- Word-boundary mismatch for Jira `devin` label (`devin_workshop` doesn't trigger).
- Linear synced-playbook-label race during config change.

## Phase 5 candidates

- integrations.github-app ↔ devin/api session-create payload
- integrations.webhook-signature-verification ↔ linux/networking TLS handshake
- integrations.ip-allowlist-integration ↔ devbox.firewall-allowlist (mirrored config)
- integrations.artifact-upload ↔ docker/engine registry-push semantics
