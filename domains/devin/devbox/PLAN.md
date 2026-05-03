# Plan — `devin/devbox`

> Per-leaf plan. Per the doctrine in `domains/_shared/sessions/PREAMBLE.md`, P1 (sources + ingest) was executed at the **domain** level, not per-leaf — see `domains/devin/PROGRESS.md` Session 1.1. Phases A and B below are therefore complete by inheritance. This file primarily describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** DevBox is the runtime substrate Devin executes inside — a sandboxed Linux VM with a hypervisor-managed snapshot/clone lifecycle, a stateful working filesystem, an embedded VS Code server, and a bundle of cross-cutting subsystems (secrets manager, firewall allowlist, port forwarding, machine credentials). Every Devin session boots from a snapshot, mutates a machine, optionally checkpoints back to a new snapshot, and shuts down. **Failure modes here surface as session-startup queueing, snapshot corruption, secret-resolution mismatches, port-forward dead-ends, IP-allowlist blocks, VS Code-server crashes, hypervisor scheduling delays, and machine resource exhaustion.** The Cognition VM screen-share interview is most likely to probe this leaf — DevBox debugging is the company's actual day job.

**How it composes upward.** DevBox underpins almost everything: it's the execution context for `devin/integrations` (SCM connections from inside the box), `devin/api` (the API hands sessions off to DevBox), `devin/mcp` (MCP servers run inside DevBox), and `devin/knowledge-playbooks` (playbooks execute against a DevBox snapshot). Underneath, DevBox underpins-on `docker/runtime` (containerized services), `linux/primitives` (cgroups, namespaces, networking), and likely `linux/filesystem` (CoW snapshot semantics — see `cognition-blog-blockdiff` and the BlockDiff README).

## Inputs already available (P1 deliverables)

- 17 documents in `devin.documents` filtered by `source_id` join on `devin.sources WHERE subdomain = 'devbox'`. Total ~265,912 chars; mean ~15,642 chars.
- The headline source: `devin-status-incidents-archive` (191,770 chars of pretty-printed JSON, parser=json-passthrough). Contains 47+ public incident records — a goldmine for Phase D failure-modes.
- The CoW-snapshot blog post: `cognition-blog-cloud-agents` (and `cognitionai-blockdiff-readme`).
- `devin-docs-onboard-agents-md` — `agents.md` schema is the single most-cited DevBox config artifact.
- `domains/_shared/schema.sql` STRUCT shapes for concepts/commands/config_keys.
- The methodology shape examples — `domains/methodology/sre-debugging/extract/concepts.json`, `domains/methodology/use-red-method/extract/commands.json`, `domains/methodology/sre-debugging/extract/config_keys.json`.

## Phase A — Survey ✅ done by P1

All 17 devbox sources catalogued in `devin.sources` with tier/license set. No additional sources surfaced during P3 prep. If P3 reveals gaps (a referenced concept that no doc explains), patch back into `domains/_shared/sources.yaml` mid-session per the dynamic-P1 doctrine.

## Phase B — Document ingest ✅ done by P1

All 17 docs in `devin.documents` with FTS index `fts_devin_documents` covering them. Spot-check: 3 random docs read sane (no nav-junk dominating).

## Phase C — Structured extraction (THIS SESSION)

**Goal:** populate `devin.concepts`, `devin.commands`, `devin.config_keys` with rows tagged to `devin.devbox.*` IDs. The agent (Claude Code) is the extractor — see *"Extraction model"* in `domains/_shared/sessions/phase-3-deep-extraction.md`.

- [ ] **Concepts pass.** Target ~50 rows. `kind` values: `subsystem | runtime-object | feature | file | network | credential`. Highest-confidence concepts to capture: `snapshot`, `snapshot-cache`, `machine`, `hypervisor`, `devbox-runtime`, `vscode-server`, `secrets-manager`, `firewall-allowlist`, `port-forward`, `agents.md`, `environment.yaml`, `setup.yaml`, `blueprint`, `vpn`, `ip-access-list`, `cloud-agent`, `web-search`, `single-threaded-write`, `multi-agent-fleet`, `verification-mode`, `proactive-mode`, `wake-up-mode`, `deepwiki`, `blockdiff`, `swebench-eval-harness`. Each row cites `source_ids[]` (typically 1–3 sources).
- [ ] **Commands pass.** Target ~25 rows. Devin-CLI / shell commands surfaced in docs: snapshot create/restore/list, machine start/stop/exec, port-forward open, secret get/set, integration connect, etc. Skip commands without ≥1 concrete `examples[]` invocation.
- [ ] **Config keys pass.** Target ~50 rows. `scope` values to use: `agents-md | environment-yaml | setup-yaml | snapshot | machine | secrets | firewall | network | vpn | playbook | api-token`. Mine from `agents.md` schema docs, `environment.yaml` references, snapshot config, hypervisor flags surfaced in docs.
- [ ] **Verify after each load.** Counts hit target. Source-id integrity check passes (every `source_ids[]` element resolves in `devin.sources`).

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Per the PREAMBLE doctrine, P4 runs horizontally across the corpus once all P3s land. **Seed candidates from this session, kept as a list in `PROGRESS.md`** so the future P4 session has a head start:

- Status incidents archive (47+ records): session queueing delays, scheduled-session startup crashes, Slack delivery failures, GitHub webhook drops, IP allowlist blocking, snapshot mutation lag, hypervisor scheduling pauses, port-forward route loss, secrets-manager rotation pauses.
- Common-issues page references: VPN connection setup failures, agents.md misconfiguration symptoms, secrets resolution misses, repository indexing stalls.

## Phase E — Relationships (DEFERRED to horizontal P5)

P5 wires cross-domain `relationships` rows. Note here for future linking:

- DevBox snapshot ↔ docker/runtime checkpoint/restore
- DevBox snapshot-cache ↔ linux/filesystem CoW (BlockDiff blog explains the semantics)
- DevBox firewall-allowlist ↔ linux/networking netfilter / iptables
- DevBox machine ↔ docker/engine container lifecycle (the running session is essentially containerized)
- DevBox secrets-manager ↔ linux/primitives credential storage / keyrings
- DevBox cgroups isolation ↔ linux/primitives cgroups v2
- agents.md schema ↔ devin/api session-create endpoint payload schema

## Reuse map

- `domains/_shared/schema.sql` — STRUCT shapes for concepts/commands/config_keys.
- `domains/methodology/{sre-debugging,use-red-method}/extract/*.json` — concrete shape examples.
- `domains/devin/PROGRESS.md` — full P1 source manifest and BM25 query test results.
- `motherduck` MCP — query devin.documents directly; load JSON via `read_json_auto`.
- `memory` MCP — for the small entity-graph skeleton seeded in Phase 6 of the session.

## Open questions (defer / track)

- The `devbox` subdomain has 17 docs but live capture (P2) is deferred. When P2 runs, expect new concepts (running daemons, mounted filesystems, real env vars) — current concepts.json should be additive-friendly, not exhaustive.
- BlockDiff's CoW algorithm is documented in a blog + tiny README. Concept rows for it should cite both; if depth is needed, future P3 enrichment may want to ingest the BlockDiff source code as a third source.
