## Part XI — Forward Research Roadmap

### From caps to a program of work

Every preceding chapter converged on the same disciplined refusal: the thirteen wedge claims that constitute MetroGraph's bet are defensible-in-hypothesis but capped at *supported-by-proxy*, and the corpus marks that ceiling rather than papering over it. This chapter does the only honest thing left to do with a cap — convert it into a forward program. If a claim is held down by the absence of a study, then naming that study precisely — its design, its dependent variables, its sample size, and the exact intake table it would land in — is the difference between a hypothesis and a wish.

The framing throughout is unsparing: **none of the work described here has been run.** The proof of that is structural, not rhetorical. The behavioral-evidence intake tables are empty, and they are empty *now*, by design:

| Intake table | Rows |
| --- | --- |
| `voc.interviews` | 0 |
| `voc.surveys` | 0 |
| `voc.usability_sessions` | 0 |
| `voc.ab_experiments` | 0 |
| `hci.primary_studies` — MetroGraph-specific studies (dormant for MetroGraph) | 0 (of 21 total; the 21 rows are external HCI-literature studies, none MetroGraph-specific) |
| `market.primary_studies` | 0 |

These zeroes are the standing pending-experimental marker for the entire synthesis. A wedge claim cannot rise above proxy because there is no row in `voc.ab_experiments` or `market.primary_studies` to lift it. The roadmap below is therefore a roadmap of *inputs that do not yet exist*. Nothing here should be read as scheduled-and-certain, and — the hardest discipline of all — we do not assume the data will ever arrive. A pre-revenue tool with no behavioral telemetry can name the experiments it needs without presuming it will get to run them.

### The four priority experiments

The strategy layer's recommendation engine surfaces four needed-but-missing MetroGraph studies. Each is tied to exactly the wedge claim it would lift past its proxy ceiling, and each carries a derived priority score — computed, not hand-set — alongside an effort estimate.

| # | Needed study | Lifts claim | Verdict today | Design / DVs | n | Lands in | Priority | Effort |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Metro/schematic vs force-directed layout A/B on schema-comprehension + path-finding | [C:market.claim.force-directed-graph-layout-remains-dominant-but-unoptimized-for-schem] | supported | task time, error rate | ≥40 within-subject | `voc.ab_experiments` / `hci.primary_studies` | 0.350 | m |
| 2 | Surface-area / progressive-disclosure usability vs full-canvas control | [C:market.claim.graph-visualization-clutter-at-scale] | disputed | time-on-task, error count, SUS | ≥30 | `voc.usability_sessions` | 0.116 | m |
| 3 | Direct-manipulation vs chat: visual graph view vs conversational control of the same agent workflow | [C:market.claim.direct-manipulation-outperforms-conversation-graph-exploration] | refuted | success rate, trust calibration, time-to-detect-error | ≥40 | `voc.ab_experiments` | 0.088 | m |
| 4 | Information-foraging: metro vs force-directed on schema-comprehension + path-finding | [C:market.claim.information-foraging-predicts-metro-map-adoption] | refuted | task time, error rate | ≥40 within-subject | `voc.ab_experiments` / `hci.primary_studies` | 0.088 | m |

The verdicts beside these studies are where the honesty bites. Two of the four featured claims read **refuted** today ([C:market.claim.direct-manipulation-outperforms-conversation-graph-exploration], [C:market.claim.information-foraging-predicts-metro-map-adoption]) and one reads **disputed** ([C:market.claim.graph-visualization-clutter-at-scale]). They are listed not as findings about to be confirmed but as hypotheses whose only legitimate route to a higher grade is the specific study named beside them. A refuted claim is not promoted by argument; it is promoted — or stays refuted, or falls further — by the pre-registered experiment that has not yet been conducted. The priority score is the corpus's view of *where the next study buys the most lift*, and it ranks the layout A/B first by a wide margin because that single study touches the largest cluster of dependent wedge claims.

![Figure — Recommendations ranked by a derived priority score (not hand-set). Purple bars are the four needed-but-missing MetroGraph experiments — roadmap items, never assumed as done.](figures/recommendation_priority.png)

### The thirteen wedge experiments and their ceilings

Beneath the four priority studies sits the full ledger. Each of the thirteen wedge claims carries `pending_experimental = TRUE` and a derived cross-domain ceiling, and each is moved by exactly one experiment archetype. Three archetypes recur — a layout A/B (task time + error rate, n≥40 within-subject), a direct-manipulation-vs-chat task-success test (success rate, trust calibration, time-to-detect-error, n≥40), and a progressive-disclosure usability study (time-on-task, error count, SUS, n≥30) — and every one of them lands in a currently empty intake table. The `wedge_experiments` ledger below pairs each claim's standing cap with the calibrated confidence behind it and the single archetype that would move it.

| Wedge claim | Ceiling | Conf. | Needed experiment archetype |
| --- | --- | --- | --- |
| [C:market.claim.agent-observability-through-visualization-improves-trust] | contested | 0.35 | direct-manipulation vs chat |
| [C:market.claim.mixed-initiative-design-ai-ui-parity-prevents-transparency-backfire] | contested | 0.35 | layout A/B |
| [C:market.claim.mixed-initiative-requires-visualization-to-prevent-agent-opacity] | contested | 0.35 | direct-manipulation vs chat |
| [C:market.claim.visual-affordances-enable-interaction-without-training] | contested | 0.35 | direct-manipulation vs chat |
| [C:market.claim.direct-manipulation-outperforms-conversation-graph-exploration] | supported-by-proxy | 0.50 | direct-manipulation vs chat |
| [C:market.claim.force-directed-graph-layout-remains-dominant-but-unoptimized-for-schem] | supported-by-proxy | 0.50 | layout A/B |
| [C:market.claim.graph-visualization-clutter-at-scale] | supported-by-proxy | 0.50 | progressive-disclosure usability |
| [C:market.claim.information-foraging-predicts-metro-map-adoption] | supported-by-proxy | 0.50 | layout A/B |
| [C:market.claim.progressive-disclosure-unlocks-schema-acquisition-in-graphs] | supported-by-proxy | 0.50 | progressive-disclosure usability |
| [C:market.claim.wayfinding-in-schematic-maps-transfers-from-transit-knowledge] | supported-by-proxy | 0.50 | layout A/B |
| [C:market.claim.ai-ui-parity-exclusive-wedge] | weak-proxy | 0.30 | layout A/B |
| [C:market.claim.flight-to-chat-when-ui-confuses-documented] | weak-proxy | 0.30 | direct-manipulation vs chat |
| [C:market.claim.schematic-maps-outperform-force-directed-database-exploration] | weak-proxy | 0.30 | layout A/B |

The gradient is instructive. The six claims at *supported-by-proxy* are the strongest the wedge gets; the four *contested* claims sit lower because the HCI literature contradicts as well as grounds them; the three *weak-proxy* claims are the most exposed. No claim reads higher than supported-by-proxy, and the experiment column is the only lever that can change that. None of these is described as measured or proven on MetroGraph — because none has been.

### The HCI design-hypotheses and their status

The HCI layer is the one place in the corpus with genuine primary backing (46 of 49 claims), and it supplies the theoretical floor under the wedge. Its design-hypotheses are explicitly typed by maturity, which keeps the borrow honest: a hypothesis *grounded* in the general literature is not the same as one *grounded-by-theory* for MetroGraph specifically, which is not the same again as one *untested-for-metro-graph*.

| Status | Meaning | Count |
| --- | --- | --- |
| grounded | Established in the general HCI literature | 5 |
| supported | Backed for the agent-visualization case | 3 |
| grounded-by-theory | Predicted for MetroGraph from theory, not yet tested on it | 5 |
| active | Open design hypothesis under the cognitive-load program | 5 |
| untested-for-metro-graph | No MetroGraph-specific evidence at all | 6 |
| mixed | Evidence cuts both ways | 1 |

The crucial honesty is the distance between the first categories and the last three. The schematic-wayfinding hypotheses — that metro-style layouts cut wayfinding time, that transit familiarity transfers, that stable spatial encoding speeds mental-model construction — are *grounded* in the general literature but map to no MetroGraph claim and have never been run on MetroGraph's actual canvas. The five *grounded-by-theory* hypotheses (animated transitions reduce gaze refixations; infinite-canvas regions distribute load; metro semantics raise information scent; metro layout enables preattentive recognition; 300–500ms is the optimal animation window) are exactly the bridge from literature to product — and exactly the bridge that an experiment, not an argument, must cross. The six *untested-for-metro-graph* hypotheses are blunt about it: edge-crossing load, extraneous-load reduction, the metro-layout advantage, progressive-disclosure acquisition, stable-encoding transfer, and affordance-without-training each carry a fully specified what-would-validate protocol (eye-tracking fixation counts, NASA-TLX subscales, between-subjects success rates) and a verdict of *untested*. The validation criteria are written; the validation is not done.

### The product roadmap: validation experiments and build items

The product roadmap splits cleanly into two kinds of work. The first is **validation experiments tied directly to refuted market claims** — the roadmap's way of saying that a claim the corpus marked false will be revisited only by evidence, never by reassertion.

| Validation experiment | Tests refuted claim | Effort |
| --- | --- | --- |
| User study: visual affordances reduce gulf of execution | [C:market.claim.visual-affordances-enable-interaction-without-training] | high |
| A-grade HCI cost study on 8 critical features vs n8n/Make/Zapier | [C:market.claim.hci-cost-parity-on-critical-features] | high |
| Validate pane-count cognitive penalty (CLT) | [C:market.claim.40-percent-screens-3plus-panes-standard] | medium |
| Measure surface-area reduction: metro-map vs dense canvas | [C:market.claim.wedge-low-surface-area-aesthetic-emerging-pattern] | medium |
| Audit layout-control discoverability | [C:market.claim.layout-controls-scattered-discoverability-failure] | medium |
| Validate orchestration + visualization cluster for data engineers | [C:market.claim.agent-orchestration-feature-gap-data-teams] | medium |
| Low-code UI-complexity tradeoff study | [C:market.claim.low-code-paradox-ui-replaces-code-complexity] | medium |
| Async-collaboration friction study | [C:market.claim.real-time-collaboration-async-friction-mismatch] | medium |

Each row attaches to a claim the corpus currently reports as **refuted**, and the roadmap preserves that verdict. The study is the price of revisiting it.

The second kind is **build work** — the shipped-reality gaps the product chapters documented. Two items are in progress: completing the disabled MongoDB visual query builder, and an enhanced execution-logs and debugging UI. The rest are planned and largely table-stakes: undo/redo and edit history (which needs a transaction/event-log architecture), multi-format export (JSON/SVG/PNG), keyboard shortcuts and a command palette, real-time collaboration, Git integration, an agent/workflow orchestration runtime, and — the performance line that bounds the whole scale story — **render optimization for 10K+ nodes**, where the tool is benchmarked today to roughly 1,000 nodes and needs virtualization to go further. Supporting infrastructure rounds it out: a node-count/frame-rate render budget (none defined today), bundle-size reduction (current 20MB-error / 30MB-warning budgets, target <5MB), and a component-style-budget audit. These build items are not evidence claims; they are the engineering preconditions that make the validation experiments worth running on a product that can actually carry the load.

### The governance remediation roadmap

Governance is the enterprise gate, and the chapter on it reported the honest finding for an early-stage tool: a wall of blocker-severity compliance gaps. The remediation ledger holds roughly two dozen **blocker** items, one **important**, and seven **major**, each with an effort estimate and, where a regulation imposes one, a deadline. Those deadlines are the sharpest items on the whole roadmap, because unlike experiments they are externally clocked.

| Remediation | Severity | Deadline / scope | Effort |
| --- | --- | --- | --- |
| Universal MFA (NIST, phishing-resistant FIDO2) | blocker | March 31, 2025 — **overdue** | high |
| AI-use transparency disclosure | blocker | Aug 2, 2026 — **imminent** | high |
| Machine-readable synthetic-content marking | important | Dec 2, 2026 | medium |
| SOC2 CC1–CC9 controls + audit | blocker | ~6mo build + 6mo audit, $50–100k | ultra |
| FedRAMP authorization (SSP, 323 controls, 3PAO) | blocker | 6–12mo, $50–150k | ultra |
| SOX top-down risk assessment + external audit | blocker | 12–16wk prep + 6mo audit | ultra |
| SSO / OAuth2 / SAML + IdP group sync | blocker | 8–12 weeks | high |
| Mandatory ePHI encryption (TLS 1.3, AES-256) | blocker | 6–8 weeks | high |
| Immutable, queryable audit-log system | blocker | 10–14 weeks | high |
| Workspace-scoped RBAC (Admin/Editor/Viewer) | blocker | 6–8 weeks | high |
| GDPR Art. 17 deletion workflow + DPA template | blocker | — | high |
| EU data-residency deployment (Schrems II) | blocker | 12–16 weeks | ultra |
| Column-level access control + data classification | blocker | — | xl / l |

The shape of the ledger matters. The heaviest items — SOC2, FedRAMP, SOX, EU residency — are *ultra* effort measured in quarters and tens-to-hundreds of thousands of dollars, while the most urgent — the overdue MFA deadline, the imminent August 2026 AI-transparency obligation — are comparatively cheap but already past or nearly due. The roadmap does not pretend any of this is done; the governance gaps remain open, and each line is a dated commitment, not a claim of compliance.

### Handoff to the conclusion

What this chapter hands forward is an inventory of the unknown and the unrun. Four priority experiments, all landing in empty intake tables. Thirteen wedge claims, every one capped and every one carrying a single named study as its only route upward. A graded HCI hypothesis set whose strongest items are *grounded-by-theory* and whose MetroGraph-specific evidence is *untested*. A product roadmap whose validation experiments exist precisely because the claims they test came back refuted. A governance ledger of open blockers with external deadlines, some already overdue. The conclusion inherits this as the raw material for its accounting of limits: the ceiling is supported-by-proxy because the intake is zero, and the only honest path upward is the program named here — pre-registered, not-yet-run, and never assumed to arrive.
