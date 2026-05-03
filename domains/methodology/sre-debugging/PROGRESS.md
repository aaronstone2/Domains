# `methodology/sre-debugging` — PROGRESS log

Per-leaf log; rolls up into `domains/methodology/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.1 — 2026-05-02 — DONE

**Outputs:**

- **38 sre-debugging concepts** in `methodology.concepts`. Covers Four Golden Signals, monitoring vocabulary (white-/black-box, dashboard, alert, page, alert-fatigue, symptoms-vs-causes), SLI/SLO/SLA + error budget, availability/durability/yield/nines/QPS, percentile + tail latency, incident-management roles (IC, Ops Lead, Comms Lead, Planning Lead) + ICS/IMAG/Wheel of Misfortune, postmortem framework + blameless-postmortem + postmortem-trigger + contributing-cause + action-item + postmortem-review, plus cascading-failure + recursive-separation-of-responsibilities + incident-handoff + incident-declaration-criteria + command-post + incident-state-document.
- **0 sre-debugging commands** — SRE prose describes process and roles, not CLI commands. Commands belong in docker/linux/devin domains.
- **36 sre-debugging config_keys** in `methodology.config_keys`. Scopes: `postmortem-template` (18 fields including timeline, action_items struct array, what_went_well/wrong/lucky), `slo` (6 fields: target, threshold, measurement_window, aggregation_region, included_requests, error_budget), `sli` (4 fields: metric_type, aggregation, measurement_frequency, collection_side), `four-golden-signals` (4 fields: latency, traffic, errors, saturation), `incident-document` (3 fields: incident_id, commander, command_post), `incident-declaration` (1 field: criteria).

**Sources extracted from:**

- `sre-monitoring-signals` — Four Golden Signals canonical chapter (Google SRE Book Ch. 6)
- `sre-slos` — SLI/SLO/SLA structure, error budget, availability/durability/yield/nines, percentile latency
- `sre-managing-incidents` — Incident Command System, IC/Ops/Comms/Planning roles, command post, live incident state document, handoff protocol, incident declaration criteria, cascading failure
- `sre-postmortem-culture` — Blameless postmortem culture, postmortem triggers, contributing causes, action items, postmortem review process, Wheel of Misfortune
- `sre-example-postmortem` — Concrete postmortem template fields (date, authors, status, summary, impact, root_causes, trigger, resolution, detection, action_items table with type+owner+bug, lessons_learned with what_went_well/wrong/lucky, timeline, supporting_information)

**Verified (ran via motherduck SQL):**

- Row counts: 38 concepts / 36 config_keys. (Targets were 30 / 35.)
- Source-ID integrity: 0 orphan `source_ids` references.
- Canonical-hook presence: all SRE referent IDs resolve (four-golden-signals, sli, slo, sla, error-budget, blameless-postmortem, incident-commander, cascading-failure, alert-fatigue).
- Random-sample eyeball: descriptions faithful to source.

**Deferred (intentional):**

- `sre-effective-troubleshooting` — generic troubleshooting playbook, partial overlap with brendangregg-methodology already covered. Could add 4-6 troubleshooting-flow concepts if needed.
- `sre-emergency-response` (38 KB) — case studies + emergency response playbooks; concept density relatively low (mostly narrative).
- `sre-being-oncall` (20 KB) — on-call ergonomics; lifestyle/process concepts not yet surfaced.
- `pagerduty-incident-response` — anything not duplicating SRE Book chapters; could add 3-5 PagerDuty-specific concepts (severity tiers, escalation policies).

**Defer-list (per PREAMBLE doctrine):**

- `methodology.failure_modes` — horizontal Phase 4 after every domain has P3. SRE chapters describe failure *response*, not failure *modes*; the value here is being the `affected_concepts` referent for docker/linux failure-modes.
- `methodology.relationships` — horizontal Phase 5.

## Cross-references

- Plan file: `~/.claude/plans/groovy-yawning-raven.md`
- Concepts JSON: `extract/concepts.json` (38 entries)
- Config_keys JSON: `extract/config_keys.json` (36 entries)
