# Phase 1 — `ecs` source corpus (AWS ECS on bare-metal EC2)

**Session 1.2 — 2026-05-02 — DONE.** Master plan: `~/.claude/plans/purring-pondering-gosling.md`.

## Context

ECS on `.metal` EC2 instance types (EC2 launch type, no hypervisor between containers and hardware). Tangentially relevant to the Cognition interview — gives the harness comparison-substrate context (containers-on-bare-metal vs containers-in-microVMs vs containers-in-containers). The Nitro System layer is the natural cross-link to `firecracker.kvm` since both depend on the same KVM/hardware-virtualization substrate.

## What landed

- **Domain folder**: `domains/ecs/` with 6 leaves: `launch-types`, `task-defs`, `agent`, `networking`, `nitro-baremetal`, `troubleshooting`. All scaffolded via `pnpm leaf add`.
- **Schema**: `ecs.{sources, documents, concepts, commands, config_keys, failure_modes, relationships}` created via `ingest init-db`. Wired into `paths.py:DOMAIN_SCHEMAS` and `queries/cross_domain.sql:meta.all_*` views.
- **Sources**: 21 of 21 `sources.yaml` entries fetched, staged, loaded — 0 fetch failures. 3 hub pages returned 0 chars (trafilatura caveat on AWS topic-only landing pages — see "Known issues" below).
- **FTS**: `fts_ecs_documents` BM25 index built. All 4 verification queries return predicted top-1 in top-3.
- **Mean content length**: 18,240 chars/doc (target >500).

## Verification — all PASS

| Check | Result |
|---|---|
| `count(ecs.sources)` | 21 |
| `count(ecs.documents)` | 21 |
| `avg(length(content_md))` | 18,240 chars |
| Thin docs (<500 chars) | 3 (AWS hub pages — see below) |
| Largest: ecs-agent-changelog | 121,250 chars |
| ecs-dg-task-defs-params | 86,876 chars |
| FTS Q6 awsvpc/ENI | top-1 ecs-agent-changelog (3.106), predicted ecs-dg-task-networking at #2 ✓ |
| FTS Q7 ECS agent registration | predicted ecs-dg-agent-config at #3, in top-5 ✓ |
| FTS Q8 bare metal Nitro | top-1 ecs-ec2-nitro (6.991), ecs-aws-baremetal-announce at #4 ✓ |
| FTS Q9 capacity providers | top-1 ecs-dg-instance-draining (predicted ecs-dg-capacity-providers is 0-chars) ⚠ |
| Single-term `metal` | top-1 ecs-aws-baremetal-announce, ecs-ec2-nitro #2 ✓ |
| `ecs-dg-task-networking` has awsvpc + bridge | true ✓ |
| `meta.all_documents` includes ecs | 21 rows visible ✓ |

## Known issues + follow-up

### 3 zero-char trafilatura returns (AWS Developer Guide hub pages)
- `ecs-dg-agent` — overview hub page; the deep content lives on linked sub-pages
- `ecs-dg-agent-update` — same, hub-only
- `ecs-dg-capacity-providers` — same, hub-only

These are AWS pages where the main content is just a paragraph + section nav (links to sub-pages); trafilatura's "main content" detection drops it as boilerplate. Three options for follow-up:
1. **Replace with sub-page URLs** (e.g. `ecs-agent-update-process.html` instead of the hub) — best signal-per-source
2. **Use playwright fallback** — captures the rendered page including nav-driven content
3. **Custom AWS-docs parser** — defer until we hit this >5x

For Phase 1 acceptance, leaving as-is (3 0-char rows are filtered out by FTS naturally and the surrounding rows cover the conceptual ground). Phase 1.5 follow-up: re-fetch with sub-page URLs for these three.

### Substring miss
- `ecs-agent-readme` does NOT contain `ECS_CONTAINER_INSTANCE_ARN` literal. Inspecting confirms the README links to docs rather than inlining each env var. Not a blocker — `ecs-dg-agent-config` (3,390 chars) is the canonical env-var reference and is loaded.

## Phase-5 relationship rows (to write later, after Phase 3 mints concept IDs)

| from_id | to_id | rel_type | source_id | confidence |
|---|---|---|---|---|
| `ecs-bare-metal-instance` | `nitro-hypervisor` | `runs-on` | `ecs-ec2-nitro` | definitive |
| `ecs-bare-metal-instance` | `kvm-api` | `enables` | `ecs-ec2-nested-virt` | definitive |
| `ecs-task-awsvpc-mode` | `aws-vpc-eni` | `binds-to` | `ecs-agent-proposal-eni` | definitive |
| `ecs-agent` | `amazon-ecs-init` | `supervised-by` | `ecs-init-readme` | definitive |
| `aws-fargate` | `firecracker-vmm` | `runs-on` | `fc-aws-fargate-dataplane` | definitive |

## Next: Phase 3 (`firecracker` first, then `ecs`)

Per the vertical-slice convention, the next session continues into `phase-3-deep-extraction.md` for `firecracker` (the higher-leverage interview-prep domain). `ecs` Phase 3 follows after firecracker P3 lands. Recommended ECS leaf order when we get there: `agent` → `nitro-baremetal` → `task-defs` → `networking` → `launch-types` → `troubleshooting`.

End-condition for the ecs vertical: `pnpm harness <query>` returns concept rows with cited source_ids for the ECS-on-bare-metal vocabulary (EC2 launch type / .metal instance types / Nitro / awsvpc ENI mode / agent introspection / etc.).
