# Plan — `methodology/sre-debugging`

> Stub form. Phases A and B were done at the domain level in session 1.1 (44 sources / 1.27 MB into `methodology.{sources,documents}` + FTS).

## Context

Google SRE Book chapters + PagerDuty incident-response runbook. The "what does a healthy operations practice look like" half of the methodology layer: monitoring signals, SLI/SLO/SLA, error budgets, incident-commander roles, blameless postmortem template, on-call hygiene.

Underpins all incident/failure-mode work in docker/linux/devin — the postmortem template fields, four-golden-signals, and IC role names land here so cross-domain failure-modes can cite them.

## Phase status

| Phase | Status | Where |
| --- | --- | --- |
| A — Survey | DONE | `methodology.sources WHERE subdomain='sre-debugging'` (12 sources, mostly T1) |
| B — Document ingest | DONE | `methodology.documents` (12 docs, ~183 KB total). FTS built. |
| C — Concepts/Commands/Config-keys | **THIS SESSION** | extract/{concepts,config_keys}.json → `methodology.concepts/config_keys` |
| D — Failure-modes | DEFERRED | Horizontal phase. SRE chapters describe failure *response*, not failure modes themselves. |
| E — Relationships | DEFERRED | Horizontal phase. |

## Phase C scope

Targets:
- ~30 concepts
- 0 commands (SRE prose has playbooks, not CLI commands — those belong in docker/linux)
- ~35 config_keys

Sources prioritized:

- `sre-monitoring-signals` — Four Golden Signals (canonical), 5 concepts + 5 config_keys
- `sre-slos` (45 KB) — SLI/SLO/SLA structure, ~8 concepts + ~10 config_keys (definition fields)
- `sre-emergency-response` (38 KB) + `sre-managing-incidents` (31 KB) + `sre-being-oncall` — incident roles + escalation, ~10 concepts + ~5 config_keys
- `sre-postmortem-culture` (32 KB) + `sre-example-postmortem` — postmortem template fields, ~6 concepts + ~15 config_keys
- `sre-effective-troubleshooting` — generic playbook concepts, ~5 concepts
- `pagerduty-incident-response` (26 KB) — anything not already in the SRE chapters, ~5 concepts

## Phase C non-droppable hooks

- `methodology.four-golden-signals`
- `methodology.sli` / `methodology.slo` / `methodology.sla`
- `methodology.error-budget`
- `methodology.blameless-postmortem`
- `methodology.incident-commander`
- `methodology.cascading-failure`
- `methodology.cfg.postmortem-template.summary`
- `methodology.cfg.postmortem-template.action-items`
- `methodology.cfg.postmortem-template.root-causes`
- `methodology.cfg.postmortem-template.timeline`

## Open questions

(populated during execution)
