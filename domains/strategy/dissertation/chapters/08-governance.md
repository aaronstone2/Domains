## Part VIII — Governance & Compliance

The preceding chapter handed forward the data-access and lineage surfaces every enterprise
buyer expects to be governed: the connections MetroGraph opens against a customer's
warehouse, the queries it issues, the previews it renders, the graphs it persists. This
chapter accounts for what governs them today — nothing — and does so without softening. Of
everything the corpus weighs, the governance finding is the one that needs no proxy, no
comp, and no pending experiment to be believed: it is read directly off the shipped code
and the published requirement texts. In the precise vocabulary of this dissertation it is
the most clearly TRUE/CONFIRMED finding in the whole synthesis, and also the least
flattering. The discipline here is to report the gap at full size and then frame it
correctly — as the logical consequence of an alpha-stage product, not a design failure —
converting each blocker into a dated roadmap item that bounds, but does not condemn, the
enterprise opportunity.

### The headline: thirteen viz features, zero governance controls

MetroGraph ships a credible early-stage visualization platform with no governance whatsoever.
Its node, edge, and graph exploration features — enumerated in the product chapter — reach
users with no authentication, no authorization, and no audit logging
[C:claim.metrograph.early-stage-governance]. Stated at the level of the control surface:
the product is single-user, not multi-tenant, with ZERO governance controls shipped — no
authentication, no RBAC, no audit logging, no data classification, no column-level access
control, and no masking [C:governance.claim.early-stage-no-governance]. Read against the
feature ledger, the same finding sharpens: thirteen core data-visualization features are in
users' hands while the governance controls that enterprise and regulated markets require —
RBAC, SSO, audit logging, observability — number zero [C:claim.metro.governance-gap-auth].

Two properties make this a CONFIRMED finding rather than a graded hypothesis. First, its
evidence grade is `code`: it is established by reading the repository, not by inferring from
a comp or a survey. Second, it is a statement of absence, and absence is cheap to verify and
impossible to overstate — there is no risk of inflation when the claim is "this control does
not exist." That asymmetry is why governance carries the corpus's firmest verdicts even
though, like every domain other than HCI and VoC, it is **zero primary-backed**: no
usability study or A/B test underwrites these claims, and none is needed, because the claim
is about the code's contents, not about a behavioral effect on a user.

### From sixty requirements to eleven distinct gaps

The requirement corpus for governance is deliberately over-enumerated. It pulls the literal
control texts from EU AI Act, FedRAMP Rev5, GDPR (Articles 5, 15, 17, 28, 32, 33, 44–50),
HIPAA 2026, NIS2 Article 20, PCI-DSS 4.0.1, SOX/PCAOB AS 2201, SOC2 TSC, and ISO 27001 Annex
A, then maps each to a MetroGraph gap. Because many frameworks demand the same underlying
control — MFA appears in HIPAA, PCI, ISO A.8.5, and SOC2 CC6 alike — the raw gap rows
over-count. There are 47 gap rows in total, distributed by severity as follows.

| Gap severity (raw rows) | Count |
| --- | ---: |
| blocker | 22 |
| major | 22 |
| important | 1 |
| minor | 2 |

These 47 framework-keyed rows deduplicate to a much smaller set of distinct engineering
deficits, and the headline strategic finding collapses them honestly. MetroGraph has **11
compliance gaps that gate enterprise adoption** across three segments
(enterprise-data-teams, cdo-data-leadership, governance-quality-teams), of which **5 are
blockers** (no auth, no RBAC, no audit logging, no data classification, no column access)
and **6 are major gaps** that materially reduce governance posture; total estimated
remediation is roughly **8 person-months** [C:governance.claim.11-blocking-gaps]. The
downstream strategy domain, reading the same evidence against a wider segment set, counts more
gating gaps — the difference is one of segment coverage, not of any new control being
discovered, and both readings describe the identical shipped reality.

The control-coverage ledger tells the same story from the supply side: of the controls the
frameworks demand, 42 have **no** coverage, 9 have **partial** coverage, and 5 are merely
**planned**. The relationship algebra records this as 45 `gates` edges (a requirement
blocking a segment) against only 23 `satisfies` edges — gate edges outnumber satisfactions
roughly two to one, the graph-level restatement of "early-stage."

![Figure — Open compliance gaps gating the enterprise segment, by severity. The blocker count is the honest finding for an early-stage tool — each blocker becomes a dated roadmap item.](figures/governance_gaps.png)

### The five blockers and six majors

The distinct gaps, with the remediation effort the corpus attaches to each, are below. The
effort column is the engineering estimate from the gap remediation rows; it is what makes the
~8-person-month total and the cost/timeline handoff to the finance chapter auditable rather
than asserted.

| Distinct gap | Severity | Remediation effort (est.) |
| --- | --- | --- |
| No authentication (SSO/OAuth/SAML + MFA) | blocker | 8–12 wks SSO; 4–6 wks MFA |
| No role-based access control (RBAC) | blocker | 6–8 wks (XL) |
| No immutable audit logging | blocker | 10–14 wks (XL) |
| No data classification (PII/PHI tagging) | blocker | L |
| No column/field-level access control | blocker | XL |
| Lineage not formalized as queryable data | major | M |
| No role-aware masking UI | major | M |
| No workspace/project isolation | major | L |
| No JML (joiner-mover-leaver) provisioning API | major | M |
| No query audit trail | major | M |
| No access-review reports | major | M |

The authentication blocker is the keystone, because almost everything else depends on a
notion of identity. Shipping SSO/OAuth/SAML plus RBAC plus audit logging — the table-stakes
triad — is what would unlock the Enterprise Data Teams segment; these controls are
prerequisite to SOC2 and ISO 27001 and non-negotiable in enterprise security questionnaires
[C:claim.metrograph.sso-roadmap-gates-enterprise]. The audit-logging blocker is
independently load-bearing for compliance: MetroGraph lacks the comprehensive audit logging
that GDPR Article 32 and SOC2 CC6.1/CC7.2/CC7.3/CC8.1 require to demonstrate who accessed
customer data, when, from where, and what they did [C:claim.metro.audit-logging-absent].
Without an identity layer and an immutable log, the remaining controls cannot even be
expressed.

### The regulatory clock

Beyond the framework requirements that gate adoption structurally, a set of dated regulatory
deadlines determines *when* each gap stops being optional. The corpus separates these by
verdict with care: deadlines that are published and current are `supported`, while future
rulings and not-yet-finalized rules stay `speculative`, no matter how widely anticipated.

| Regulatory event | Date / status | Verdict |
| --- | --- | --- |
| EU AI Act Art. 50 transparency obligations | Aug 2, 2026 (fines to €35M / 7% turnover) | supported [C:governance.claim.eu-ai-act-enforcement-aug-2-2026-transparency] |
| PCI-DSS 4.0.1 universal MFA for all CDE access | Mar 31, 2025 — deadline passed (overdue) | supported [C:governance.claim.pci-4-0-1-universal-mfa-deadline-passed] |
| NIS2 Art. 20 executive personal liability | Enforceable as of June 2026 | supported [C:governance.claim.nis2-article-20-personal-liability-enforcement] |
| FedRAMP Rev5 "Class C" (323 NIST 800-53 controls) | July 2026 terminology migration | supported [C:governance.claim.fedramp-rev5-class-c-migration-july-2026] |
| SOX/PCAOB AS 2201 top-down risk-based ITGC | Fiscal years from Dec 15, 2026 | supported [C:governance.claim.sox-pcaob-2026-top-down-risk-approach] |
| HIPAA 2026 universal ePHI encryption mandatory | Proposed; final rule not yet issued | supported [C:governance.claim.hipaa-2026-encryption-mandatory-ehr] / [C:governance.claim.hipaa-2026-no-final-rule-issued] |
| AWS European Sovereign Cloud (Schrems hedge) | Launched Jan 2026, Brandenburg DE | supported [C:governance.claim.aws-sovereign-cloud-eu-data-residency] |
| Schrems III challenge to EU-US DPF | Ruling expected late 2026 | speculative [C:governance.claim.schrems-iii-ruling-expected-late-2026] |
| HIPAA 2026 6-year tamper-proof audit-log retention | Pending rule detail | speculative [C:governance.claim.hipaa-2026-audit-logs-6-year-retention] |

The honesty boundary is visible in the last three rows. PCI's universal-MFA mandate is a
hard, past deadline, so it is reported flatly as overdue
[C:governance.claim.pci-4-0-1-universal-mfa-deadline-passed], and the framework's later
clarification that phishing-resistant FIDO2 may substitute for traditional MFA in
non-administrative access is likewise current
[C:governance.claim.pci-4-0-1-phishing-resistant-mfa-allowed]. NIS2 Article 20's shift of
liability onto named executives is recorded as supported because the directive is in force
and member states may impose personal liability and management bans
[C:governance.claim.nis2-article-20-management-liability]. But the Schrems III invalidation
and the not-yet-published HIPAA final-rule specifics remain **speculative** — they are
litigation-risk and regulatory-pending, and the corpus refuses to promote them to a deadline
the product must hit. The standing GDPR transfer constraint underneath them is graded TRUE on
its own footing: post-Schrems II, EU personal data on US servers requires an Adequacy
Decision, BCRs, or SCCs with supplementary technical controls, and MetroGraph implements no
data localization [C:claim.metro.data-residency-schrems-ii].

### The one partial control, and the lineage advantage hidden in the model

There is exactly one place where the coverage ledger reads better than zero. MetroGraph's
connection manager stores credentials encrypted at rest, which partially satisfies the
"encrypted at rest" requirement — but with no TLS enforcement, no cipher-suite audit, and no
way for a customer to verify connections use strong encryption
[C:governance.claim.connection-secrets-stored]. This is the only partial coverage the corpus
will credit; nothing else should be read as shipped.

Against that thin positive sits a genuine, latent design advantage. MetroGraph's
node-and-edge graph model *naturally encodes data lineage* — source nodes flow to transform
nodes flow to output nodes — so lineage is the visual primitive itself, not a bolt-on
afterthought [C:governance.claim.lineage-is-implicit]. The honesty caveat rides in the same
breath: lineage is not yet formalized as queryable data, not exported to compliance tools
(Collibra, Alation), and not accompanied by impact-analysis UI. It is an *architectural*
head start on a major gap, not a shipped control. Formalizing it — extracting
source/transform/sink edges into a lineage table, exposing upstream/downstream search,
supporting export — is an M-effort item, materially cheaper than building lineage on a
platform whose data model does not already shape it. This is the one place the governance
chapter contributes a forward asset rather than a debt.

### The honest reframe: stage, not failure

The temptation with a finding this stark is either to bury it or to wield it as an
indictment; the corpus does neither. The absence of governance controls is not a design flaw
but the logical consequence of product stage — these are strategic roadmap items for
enterprise expansion, not bugs [C:claim.metrograph.honest-gap-is-roadmap-item]. Every
blocker in the table above carries `becomes_roadmap_item = true`, which is what licenses the
reframe: a gap that converts cleanly into a dated, effort-estimated work item is a backlog,
and a single-user alpha is *supposed* to have this backlog. MetroGraph is a capable
early-stage visualization tool that is simply unsuitable for regulated and enterprise
segments until its auth layer ships [C:claim.metrograph.early-stage-governance].

The certification path makes the timeline concrete and is the chapter's central message to
finance. SOC2 Type II requires documented audit logging (CC6, CC7), change management (CC8),
and access controls with MFA — MetroGraph has none of these shipped — so a Type II
certificate requires a 4–6 month build followed by a 6-month audit observation window before
the certificate is even possible [C:claim.metrograph.no-soc2-path-without-audit]. That
~12-month floor, layered on top of the ~8 person-months of feature remediation
[C:governance.claim.11-blocking-gaps], is the cost-and-timeline weight this chapter hands to
Part IX: enterprise revenue cannot be recognized before the gate clears, so the gate *bounds
the timing* of the enterprise line in the financial model rather than discounting its size.
The dated remediation items themselves — MFA, SSO, RBAC, audit logging, data classification,
column access, plus the EU-residency and DPA work [C:claim.metro.gdpr-dpa-blocker],
[C:claim.metro.data-deletion-capability-missing] — are what Parts X and XI carry into the
roadmap and the recommendation portfolio.

### Verdict mix and what each grade certifies here

The 33 governance claims partition into a verdict mix that is itself the chapter's
epistemics in miniature: **4 CONFIRMED, 9 TRUE, 15 supported, and 5 speculative.** Three of the four
CONFIRMED claims are code-grade observations read straight off the repository — the
zero-governance absence, the one partial encrypted-credentials control, and the implicit-lineage
design property — and the fourth is the research-grade synthesis that aggregates the gaps into
the 11-blocking-gaps count. The absence claims carry the firmest footing because there is
nothing to inflate in a statement of what is not there; the synthesis claim's effort estimate
is the one piece of this group that remains an estimate, carried as such. The nine TRUE claims are requirement-grounded: they read a
published control text (GDPR Art. 17/28/32, SOC2 CC6/7, the SSO/RBAC gate) against the
product and find it wanting, certain in direction but resting on regulatory interpretation
rather than a line of code. The fifteen supported claims are the current, dated regulatory
facts — deadlines and enforcement states that are real but external to MetroGraph. The five
speculative claims — Schrems III, the HIPAA final rule's specifics, NIS2 first-enforcement
timing — are precisely the ones the corpus declines to harden, holding them as risks to
monitor rather than deadlines to hit.

Critically, none of these verdicts is primary-backed, and the chapter does not pretend
otherwise: governance is 0/33 on derived primary evidence. But unlike the wedge claims
elsewhere in this dissertation — whose ceiling is capped at supported-by-proxy precisely
because the experiments that would raise them have not run — the governance findings do not
need primary behavioral evidence to be CONFIRMED. "There is no audit log" is settled by
reading the code; no usability session could make it more or less true. That is the
distinction this corpus exists to mechanize, and governance is where it reads cleanest: a
maximally honest, maximally firm finding that the enterprise gate is real, its blockers are
countable, its clock is dated, and its remediation is a roadmap — not a verdict to be argued,
but a backlog to be built.
