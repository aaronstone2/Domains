# product — MetroGraph corpus progress

## Session 1 — 2026-06-26 — repo analysis (A–E in one pass)

Analyzed the real MetroGraph repo (github.com/mark1russell7/Graph, Angular + node-server) via a
3-agent code-analysis workflow, closing the market "design-targets not measured" gap.

- **feature_specs (21)** mapped to the canonical `market.features` axis with REAL implementation paths
  and honest status: **13 shipped, 2 in-progress, 6 planned**. The high-pain wedge features (agent
  orchestration, execution-log step-debugging, advanced query building) are NOT yet shipped — the
  honest gap between vision and code.
- **components (50)** — the Angular/service architecture. **benchmarks (18)** — code-measured facts
  only; every behavioral metric (pane count, HCI cost) is `pending-experimental` + `is_dormant`.
- **roadmap_items (11)** — incl. validation-experiment items (the dormant user studies) that cite the
  refuted market wedge claims; these are the experiments that would flip the wedge, captured as work.
- **claims (17)** spec-grounded, descriptive; ran `verify` (standards+CIs) + `evidence` (all 17 are
  PROXY-ONLY — spec-grounded, not behaviorally validated) + `embed`. 21 `measures` edges wire each
  feature_spec to its market.feature, giving the differentiation pivot real code backing.

Honesty held: 0 behavioral metrics mislabeled `code-measured`; nothing inflated above its code status.
