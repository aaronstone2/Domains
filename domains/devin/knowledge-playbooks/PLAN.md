# Plan — `devin/knowledge-playbooks`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** Knowledge and playbooks are how customers persist organizational context across Devin sessions. Knowledge sources are durable, indexed text blobs; playbooks are parameterized procedural recipes. Secrets are first-class siblings (referenced from playbooks, materialized into DevBox at session start). **Failure modes here surface as knowledge-source indexing drops, playbook parameter validation failures, secret-resolution misses (playbook references a secret name that doesn't exist), and knowledge-search relevance issues.**

**How it composes upward.** Playbooks invoke against `devin/devbox` (the runtime where they execute) and reference `devin/integrations` (the SCM credentials they may need). Knowledge sources are searched at session-context-build time; secrets are mounted into DevBox.

## Inputs already available (P1 deliverables)

- 4 documents, ~22,889 chars total, ~5,722 chars avg.
- Headline sources: `devin-docs-product-playbooks` (BM25 top hit for "slack integration message delivery"), playbook secret-reference docs, knowledge sources docs.
- Note from Session 1.1 BM25 verification: "playbook secret reference" query missed top-5 — phrasing too generic vs. dedicated secrets page. Corpus content is fine; relevance ranking weakness only.

## Phase A — Survey ✅ done by P1

4 sources catalogued. Smallest leaf in devin.

## Phase B — Document ingest ✅ done by P1

All 4 docs in `devin.documents`, FTS-indexed.

## Phase C — Structured extraction (THIS SESSION)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.knowledge-playbooks.*`.

- [ ] **Concepts pass.** Target ~15 rows. `kind` values: `knowledge-source | playbook | secret | feature | parameter`. Concepts: `knowledge-source`, `knowledge-source-text`, `knowledge-source-url`, `knowledge-source-file`, `knowledge-search`, `knowledge-indexing`, `playbook`, `playbook-step`, `playbook-parameter`, `playbook-trigger`, `playbook-output`, `secret`, `secret-reference`, `secret-rotation`, `secret-scope`.
- [ ] **Commands pass.** Target ~5 rows. CLI/UI commands: `create-knowledge-source`, `update-knowledge-source`, `run-playbook`, `add-secret`, `rotate-secret`.
- [ ] **Config keys pass.** Target ~15 rows. `scope` values: `knowledge-source | playbook | secret`. Examples: `knowledge-source.indexing-frequency`, `playbook.timeout`, `playbook.parameter.required`, `secret.scope`, `secret.rotation-policy`.

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates:
- Knowledge-source indexing stuck (large corpus, slow IO).
- Playbook parameter validation rejecting a typo.
- Secret reference unresolved at runtime (name mismatch).
- Knowledge-search relevance miss (P1 BM25 verification surfaced this for "playbook secret reference").
- Playbook trigger condition not met (silently skipped).

## Phase E — Relationships (DEFERRED to horizontal P5)

- knowledge-playbooks.playbook ↔ devbox.devbox-runtime (execution context)
- knowledge-playbooks.secret ↔ devbox.secrets-manager (mounting)
- knowledge-playbooks.playbook ↔ integrations.<provider> (credential reference)
- knowledge-playbooks.knowledge-source ↔ api.knowledge-* endpoints

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP.

## Open questions

- The "playbook secret reference" BM25 miss in P1 verification suggests our docs don't use the phrase "secret reference" prominently. Worth checking if the secrets-page actually contains the canonical phrase during extraction; if not, Phase 4 failure-mode rows should explicitly use the user's likely phrasing.
