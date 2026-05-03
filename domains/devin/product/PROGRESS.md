# `devin/product` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 58 concepts / 11 commands / 15 config_keys (targets ~60/~10/~25 — concepts on target; commands on target; config_keys under target — most product-tier config is feature-flag/UI-path style, intentionally lighter).

**Source coverage:** Headline docs read end-to-end (devin-review, computer-use, slash-commands, ask-devin, knowledge, playbooks, session-insights, scheduled-sessions, secrets, skills, session-tools, testing-and-recordings, instructing-effectively, good-vs-bad, when-to-use, sdlc-integration, deployment-capabilities, getstarted-intro, bot-comment-settings). Release notes (2024/2025/2026 + overview) skimmed for release-event concepts. Cognition blogs (cloud-agents, multi-agents-working, swe-check-10x-faster, swe-1-6 / preview, devin-2, jan-25-update, how-cognition-uses-devin, devin-can-now-manage-devins, devin-for-terminal, agent-trace) read for feature concepts. Sitemap.xml + llms.txt referenced as concept rows but not parsed verbatim.

**Source-id integrity:** all references resolve (one fix-up applied — removed broken `cognition-blog-devin-review` source-id from the devin-review concept since that blog post wasn't part of P1's source set).

**Highlights:**
- Devin Review feature catalog: 7 sub-features (smart diff, copy/move, bug-catcher, GitHub compat, codebase-aware chat, PR workflow actions, code changes from chat).
- Multi-agent / Manage Devins / Schedule Devins coordinator pattern.
- SWE-Check + SWE-1.6 model coverage.
- Computer Use (recent, evolving).
- Skills + Knowledge + Playbooks + Scheduled Sessions + Session Insights as distinct product features.
- Release-note concept rows for major dated events (Devin 2.0, 2.1, 2.2, Sonnet 4.5 preview, audio in Slack, usage-based billing launch, enterprise accounts launch, DeepWiki launch, DeepWiki MCP launch, Codemaps, AI Data Analyst, Devin in Windsurf, Devin can Schedule/Manage Devins, Devin for Terminal).
- Itaú case study captured (17K engineers, 5–6× faster migrations, 70% auto-remediation, 2× test coverage).
- Engineer fluency + review-volume-shift operational concepts from Cloud Agents blog.

## Phase 4 candidates

- Feature unavailable on plan tier.
- Self-hosted deployment missing a feature available only on cloud.
- Voice-mode misconfig (audio-device permissions in browser).
- Multi-agent fleet contention.
- Wake-up-mode triggering during active session.
- Devin Review bug-catcher false-positive flooding reviewers.
- Computer-Use selector miss (UI element not detected).

## Phase 5 candidates

- product.<feature> ↔ devbox.<runtime-object> for every feature with runtime backing
- product.<feature> ↔ api.<endpoint> for every feature with API surface
- product.<plan> ↔ enterprise.<feature-flag> for plan-gated features
- product.devin-review ↔ integrations.github-app
- product.scheduled-sessions ↔ api.schedule-resource
- product.knowledge-feature ↔ knowledge-playbooks.knowledge-source
