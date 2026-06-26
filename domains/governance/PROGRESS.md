# governance — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## 2026-06-26 — A–E: compliance posture + segment-gating gaps (Wave 1)

3-agent Explore (SOC2/ISO27001 / GDPR-CCPA / data-governance) → **36 requirements** (real framework
controls: SOC2 CC6-CC8, ISO Annex A.5/A.8, GDPR Art. 5/15/17/28/32/44-50), **33 controls** mapped to
market.features, **32 compliance_gaps**, 13 claims. **49 edges**: controls→features (`satisfies`),
gaps→segments (`gates`).

**The de-risk deliverable — what gates the enterprise ICP:** **14 blocker gaps**, 16 major, 2 minor.
The `enterprise-data-teams` segment is gated until MetroGraph ships **SSO/SAML** (8-12wk), **RBAC**
(6-8wk), **MFA** (4-6wk), **immutable audit logging** (10-14wk), a **GDPR DPA + sub-processor flow**,
and an **EU data-residency / Schrems-II** path. `cdo-data-leadership` is gated by **SOC2 Type II
readiness** (~6mo build + 6mo observation, $50-100k audit).

**Honesty:** an early-stage tool legitimately has many gaps — that's the finding, not an embarrassment.
`controls.is_shipped` set only where the product domain shows the feature exists; every blocker gap
carries `becomes_roadmap_item=true` and a sized remediation, feeding the Wave-4 roadmap. Nothing
overstates MetroGraph's posture.

`ingest verify` (13 evaluative-standard claims) + `embed` (13 vectors) run.
