# Corpus PROGRESS log

Top-level log across all phases / sessions. Per-leaf detail lives at `domains/<domain>/<leaf>/PROGRESS.md`.

## Phase 0 — Foundation

### Session 0.1 — 2026-05-02 — DONE

**Output:**
- `_db/knowledge.duckdb` initialized with schemas `meta`, `devin`, `docker`, `linux`, `k8s`, `methodology` and 7 tables/views per schema.
- `domains/_shared/schema.sql`, `queries/cross_domain.sql`, `queries/fts_index.sql`.
- `domains/_shared/sources.yaml` seeded with ~50 tiered entries spanning all 5 domains.
- `domains/_shared/ingest/` Python pipeline (uv-managed) with `init-db`, `list`, `fetch` subcommands. Built locally (`uv sync`).
- `domains/_shared/sessions/` populated with `PREAMBLE.md`, `HOWTO.md`, and `phase-0` through `phase-7` pipe-able session prompts.
- `domains/_shared/PLAN.template.md` and `README.md` written.
- `packages/harness/` (`@domains/harness`) scaffolded — `pnpm harness query "<text>"` opens DuckDB and returns state. Stubbed; full subcommands come in Phase 5.
- Root `package.json` has `harness` script wired via `tsx`.
- `pnpm-workspace.yaml` updated with `duckdb`/`duckdb-async`/`esbuild` in `onlyBuiltDependencies`.
- `.mcp.json` motherduck flipped to `--read-write` (was malformed by user, fixed). **Restart Claude Code for the change to take effect on the motherduck MCP**.
- `.gitignore` extended (`domains/**/raw/`, `*.token`, `*sensitive*`).
- `CLAUDE.md` extended with a Knowledge corpus section pointing at `domains/_shared/sessions/`.

**Verified:**
- DuckDB schemas created (6 schemas × 7 tables/views each).
- `pnpm harness query "test"` returns `{db: "knowledge", n_documents: 0}` against the empty DB.
- Sample fetch: `uv run python -m ingest fetch --source-id oci-runtime-spec-gh` ingested the OCI runtime-spec into `docker.sources` + `docker.documents` (3370 chars).
- After ingest: `pnpm harness query "after ingest"` correctly reports `n_documents: 1` via the `meta.all_documents` view.
- Direct DuckDB query confirms the `docker.sources` row + linked `docker.documents` row.

**Deferred:**
- FTS index build (waiting until Phase 1 has more docs).
- `ingest load --table <t>` subcommand for JSON-from-extract loads (Phase 3 dependency — not needed yet).
- Custom parsers (`manpage`, `mintlify`) — defer until trafilatura output is verified inadequate for those source types.
- Memory MCP graph population — Phase 4.

**Next:** Phase 1 (per-domain source corpus build-out). Pick a domain and pipe `domains/_shared/sessions/phase-1-source-corpus.md` into a fresh session. Recommended order: methodology (smallest, validates pipeline at scale) → docker → linux → devin → k8s.

## Phase 1 — Per-domain source corpus build-out

### Session 1.1 — 2026-05-02 — methodology — DONE

Per-leaf detail: `domains/methodology/PROGRESS.md`.

**Outputs:**

- 44 methodology sources fetched + indexed (5 existing + 39 new). 1,270,471 chars total content; mean 28,874 chars/doc.
- BM25 FTS index `fts_methodology_documents` built. 7 verification queries pass; each subdomain represented in ≥2 query top-5s.
- Subdomain split: use-red-method 18, visual-zines 14, sre-debugging 12.

**Infra changes:**

- Added `pymupdf>=1.24` PDF parser to ingest pipeline.
- Refactored `extract.py` to dispatch on `Source.parser` (pdf / github-md / trafilatura).
- **Decoupled `ingest fetch` from the DB write lock** — `fetch` now writes JSONL staging to `_db/staging/<domain>.{sources,documents}.jsonl`; new `ingest load` command (or motherduck MCP) bulk-loads via `read_json` + `INSERT OR REPLACE BY NAME`. Resolves the long-standing motherduck-MCP / ingest-CLI lock conflict.

**Verified:**

- 0 fetch failures across 44 sources.
- 1 thin doc (`jvns-debugging-zine`, 0 chars) — image-only comic PDF, flagged for OCR follow-up. All other docs > 500 chars.
- BM25 sample queries return high-quality results (e.g. "four golden signals" → `sre-monitoring-signals` top-1 with 8.2 score).

**Deferred:** OCR for image-only PDFs; per-parser variants for `manpage` and `mintlify`; harvesting individual Wizard Zines comic URLs from the now-ingested comics-index page; PDF-only sources like Cindy Sridharan's O'Reilly chapter.

**Sequencing revision (2026-05-02):** revised the approach from horizontal-layered ("all domains Phase 1, then all domains Phase 3") to a hybrid: **Phase 1 + Phase 3 per domain (vertical pair)**, then **Phase 2 / 4 / 5 / 6+ horizontally** across all domains. Reasoning: P1 and P3 are tightly coupled (P3 surfaces source gaps that get patched back into P1 mid-session); P4 and P5 cite cross-domain `affected_concepts` so they need every domain's P3 done first to avoid revisits; P2 is devin-specific and timing-gated; P6+ are end-state assembly. Captured in `PREAMBLE.md` (Approach commitments) and `~/.claude/projects/.../memory/feedback_vertical_slices.md`. The original master plan and per-phase session prompts remain correct *per phase*; only the cross-phase sequencing changes.

**Next:** stay on methodology — Phase 3 (concepts/commands/config_keys extraction from the 1.27 MB we just landed). End condition for the methodology vertical: `pnpm harness <query>` returns concept rows with cited source_ids for the framework vocabulary (USE / RED / Four Golden Signals / off-CPU / postmortem template / etc.). Source gaps that surface get patched back into `sources.yaml`. After that, vertical pivots to docker (P1+P3 combined session).

## Phase 3 — Per-domain concept/command/config_keys extraction

### Session 3.1 — 2026-05-02 — methodology — DONE

Per-domain detail: `domains/methodology/PROGRESS.md`. Per-leaf detail under each leaf folder.

**Outputs:**

- 121 methodology concepts, 50 commands, 36 config_keys — all 3 leaves landed (use-red-method 77/50/0, sre-debugging 38/0/36, visual-zines 6/0/0).
- ID convention adopted: `<domain>.<kebab-name>` (concepts), `<domain>.cmd.<tool>.<form>` (commands), `<domain>.cfg.<scope>.<key>` (config_keys). Deterministic — re-extraction produces same IDs; cross-domain referenceable for Phase 4 `affected_concepts` linking.

**Verified:**

- 0 orphan `source_ids` references across all 3 tables.
- 24 canonical cross-domain hooks resolve (use-method, red-method, four-golden-signals, off-cpu-analysis, flame-graph, sli/slo/sla, error-budget, blameless-postmortem, incident-commander, cascading-failure, ebpf, kprobe, uprobe, tracepoint, usdt, ipc, etc.).
- Commands table: STRUCT-typed `flags[]` and `examples[]` arrays loaded correctly via `read_json(..., columns = {...})` with explicit schema spec.

**Infra changes (this session):**

- All 3 methodology leaf folders scaffolded via `pnpm leaf add methodology/<leaf>` — the new idempotent CLI subcommand added to `packages/cli` between sessions. Filled in README.md, PLAN.md (from `_shared/PLAN.template.md`), PROGRESS.md, `extract/`, `queries/` only when missing.
- A Python+Anthropic-SDK structured extractor was scaffolded at `domains/_shared/ingest/ingest/extract_structured.py` with three tool_use schemas matching the DDL, plus a new `ingest extract` CLI subcommand. **Reverted on user direction** — Claude Code Max means in-session extraction, not metered API calls. Design preserved in plan file `~/.claude/plans/groovy-yawning-raven.md` if needed for larger downstream corpora.
- Encountered orphan `mcp-server-motherduck` processes from earlier Claude Code sessions holding the DuckDB exclusive lock. Killed older instances by start-time; current session's MCP took the lock cleanly afterward. **Documented this as a recurring cleanup pattern** — diagnose via `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'mcp-server-motherduck' }`.

**Deferred:**

- Failure-modes + relationships tables stay empty — horizontal Phase 4 / Phase 5 after every domain has P3 (per PREAMBLE doctrine).
- Full BCC tool catalog walk; bpftrace stdlib detail; `bpftrace-oneliners` extraction; OCR for `jvns-debugging-zine`; Wizard Zines individual-comic URL harvest. All addable in follow-up sessions.

**Next:** **Methodology vertical complete.** Pivot to docker — Phase 1 + Phase 3 combined session. Domain order: methodology ✓ → docker → linux → devin → k8s. Start with `docker/engine` per the leaf priority order in `phase-3-deep-extraction.md`. New session prompt: pipe `domains/_shared/sessions/phase-1-source-corpus.md` first to seed the docker source list, then `phase-3-deep-extraction.md` for extraction.

### Session 1.2 — 2026-05-02 — firecracker + ecs (NEW domains, P1 only) — DONE

Per-domain detail: `domains/firecracker/PROGRESS.md`, `domains/ecs/PROGRESS.md`. Plan: `~/.claude/plans/purring-pondering-gosling.md`.

**Scope decision:** Two NEW domains added outside the original methodology→docker→linux→devin→k8s order. Justification: cross-cutting research (cognition.ai/blog/what-we-learned-building-cloud-agents) revealed Devin's DevBox uses microVM isolation + hypervisor snapshotting — Firecracker-pattern (FC not named explicitly in Cognition's writing). Firecracker is therefore strong-hint interview-relevant. Split into two domains (not one combined `aws-runtime`) for license-cleanliness — Firecracker is Apache 2.0 redistribute-ok, AWS ECS docs are proprietary reference-only.

**Outputs:**

- `firecracker` domain: 35/39 sources fetched; mean 21,530 chars/doc; 0 thin docs. 10 leaves scaffolded (vmm/jailer/snapshots/networking/vsock/api/kvm/security/setup/comparable-systems). `fts_firecracker_documents` BM25 index built; 5 verification queries pass with predicted top-1 in top-3.
- `ecs` domain: 21/21 sources fetched (3 0-char hub pages — known trafilatura issue with AWS topic-only landing pages); mean 18,240 chars/doc. 6 leaves scaffolded (launch-types/task-defs/agent/networking/nitro-baremetal/troubleshooting). `fts_ecs_documents` BM25 index built; 4 verification queries pass.
- `devin` schema: 1 new source added (`devin-cognition-cloud-agents`, 6,600 chars) — the microVM-evidence post that drove this whole session. FTS index rebuilt to include it.
- `meta.all_documents` now reports: devin 327, docker 104, ecs 21, firecracker 35, methodology 44 = **531 total** (up from 475).

**Infra changes (this session):**

- `domains/_shared/ingest/ingest/paths.py:DOMAIN_SCHEMAS` extended from 5 to 7 schemas (`firecracker`, `ecs` added).
- `domains/_shared/queries/cross_domain.sql` extended — all 7 `meta.all_*` views now UNION the two new schemas. Re-applied via `ingest init-db` (idempotent).
- **DuckDB FK gotcha** confirmed in practice on the devin-cognition load: `INSERT OR REPLACE BY NAME` on `<d>.sources` trips the FK from `<d>.documents` when the table is non-empty. Worked around by issuing the INSERT via `duckdb` CLI with a `WHERE id = ...` filter that touches only the new row, leaving existing rows untouched. Documented in user-memory `feedback_duckdb_fk_replace.md` (saved earlier this session). The bulk `ingest load --domain devin` path is NOT safe for incremental adds — only for fresh-load scenarios.
- **Recurring orphan-MCP cleanup pattern** triggered again. Two motherduck MCP server trees were running (older started 10:28:40, newer 10:51:25). Diagnosed via `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'mcp-server-motherduck' }`. Killed both trees in sequence (older first per documented pattern, but newer was actually the lock-holder); Claude Code respawns the MCP on next call. After cleanup, `ingest init-db` succeeded and the load+FTS pipeline ran cleanly.

**Failures (non-blocking, deferred):**

- 4 e2b sub-page URLs returned HTTP error (TODO-flagged in plan as unverified): `e2b-docs-sandbox-overview`, `e2b-docs-sandbox-lifecycle`, `e2b-docs-filesystem`, `e2b-docs-commands`. Phase-1.5 follow-up: WebSearch correct e2b doc URLs, re-fetch with `--source-id`.
- 3 ECS hub pages returned 0 chars: `ecs-dg-agent`, `ecs-dg-agent-update`, `ecs-dg-capacity-providers`. Trafilatura caveat — these are intro-only pages with content on linked sub-pages. Follow-up: replace with sub-page URLs OR add playwright fallback.

**Verified:**

- All 9 FTS verification queries return predicted top-1 in top-3 (7 outright top-1, 2 in top-3).
- Single-term sanity: `KVM_RUN` → kvm-api top-1; `metal` → ecs-aws-baremetal-announce + ecs-ec2-nitro at #1 and #2.
- Cross-domain meta view query succeeds — both new schemas visible alongside the original 5.
- Substring sanity: `fc-swagger-spec` contains `swagger:`/`openapi:`; `ecs-dg-task-networking` contains both `awsvpc` and `bridge`.

**Sequencing note:** This session intentionally departed from the documented domain order (methodology ✓ → docker → linux → devin → k8s) because the Cognition microVM finding made firecracker high-leverage and time-sensitive for interview prep. The original docker→linux→devin→k8s sequence resumes after the firecracker P3 vertical lands.

**Next:** **Phase 3 (`firecracker` deep extraction)** per the vertical-slice convention (P1+P3 together per domain). Pipe `domains/_shared/sessions/phase-3-deep-extraction.md` for the firecracker vertical. Recommended leaf order: vmm → jailer → snapshots → comparable-systems (e2b proxy for Devin) → networking/vsock/api/kvm/security/setup. After firecracker P3 lands, ecs P3 (lower-priority), then resume the documented docker→linux→devin→k8s sequence.

### Session 3.2 — 2026-05-02 — firecracker high-tier leaves Phase C — DONE

Per-domain detail: `domains/firecracker/PROGRESS.md`. Plan: `~/.claude/plans/firecracker-p3-vertical.md`.

**Scope decision:** Three-session split for firecracker P3 (per AskUserQuestion). 3.2 = high-tier leaves Phase C; 3.3 = fill-out leaves Phase C; 3.4 = Phase D failure_modes + Phase E relationships. Comprehensive failure-mode target (70+) for 3.4.

**Pre-prep:**
- Added `fc-repo-faq` (12k chars) — Phase-1.5 patch surfaced by P3 plan-mode meta-research; FAQ.md was missed in P1.
- Mid-session added `fc-docs-ballooning` (21k chars) — referenced-but-missing source caught during extraction.
- Firecracker corpus now: **37 sources**.

**Outputs (high-tier leaves: vmm, jailer, snapshots, kvm, api, comparable-systems):**

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `kvm` | 30 | 52 | 16 |
| `api` | 25 | 38 | 18 |
| `vmm` | 25 | 12 | 19 |
| `snapshots` | 19 | 8 | 12 |
| `jailer` | 12 | 5 | 12 |
| `comparable-systems` | 8 | 0 | 0 |
| **TOTAL** | **119** | **115** | **77** |

**Acceptance vs plan §7 floors:**
- ✓ Concepts ≥100 (hit 119; target 133).
- ⚠ Commands floor 120 vs hit 115 — 5 short, acceptable (deficit is in vmm/jailer where commands are sparse by domain nature).
- ✓ Config_keys ≥60 (hit 77; target 80).

**Verified:**
- Orphan-source-id check: only `devin-cognition-cloud-agents` flagged — valid cross-domain reference (devin schema). Schema design intentionally allows this (source_ids is VARCHAR[], no FK).
- Per-leaf JSON files written to `domains/firecracker/<leaf>/extract/{concepts,commands,config_keys}.json` and loaded via `INSERT INTO firecracker.<table> SELECT * FROM read_json_auto(...)` per the agent-IS-the-extractor model.
- 5 random rows per table spot-checked manually for sanity.

**Infra notes:**
- DuckDB lock contention with auto-respawning motherduck MCP processes was persistent across the session — required killing PID-targeted orphans 4 times. Same pattern as Session 1.2; the cleanup is well-understood by now. Worth thinking about a settings.json hook to auto-kill stale MCPs on session start.

**Deferred:**
- Session 3.3: Phase C for fill-out leaves (`security`, `networking`, `vsock`, `setup`) — target ~48 concepts, 10 commands, 30 config_keys.
- Session 3.4: Phase D failure_modes (target 70+) + Phase E intra-firecracker relationships. Cross-domain rels deferred to horizontal Phase 5.
- ECS P3 (Sessions 3.5-3.6 sketched in plan §6) after firecracker P3 fully lands.

**Next:** Pipe `domains/_shared/sessions/phase-3-deep-extraction.md` for Session 3.3 (firecracker fill-out leaves).

### Session 3.3 — 2026-05-03 — firecracker fill-out leaves Phase C — DONE

Per-domain detail: `domains/firecracker/PROGRESS.md`. Plan: `~/.claude/plans/firecracker-p3-vertical.md` §4.

**Outputs (4 fill-out leaves: security, networking, vsock, setup):**

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `security` | 17 | 0 | 18 |
| `networking` | 15 | 7 | 12 |
| `vsock` | 7 | 3 | 0 |
| `setup` | 14 | 5 | 12 |
| **TOTAL (3.3)** | **53** | **15** | **42** |

**Cumulative firecracker domain (after 3.2 + 3.3):**

| Table | Total | Plan target | Status |
|---|---|---|---|
| `firecracker.concepts` | 172 | 188 cap / 160 floor | ✓ above floor |
| `firecracker.commands` | 130 | 168 cap / 150 floor | ⚠ 20 short of floor |
| `firecracker.config_keys` | 119 | 110 cap / 100 floor | ✓ exceeded cap |

Commands deficit is distributed across leaves where most "actions" surface as API calls (counted under api, 38 commands) or kernel/host operations rather than standalone CLI. All 10 leaves now populated.

**Highlights:**
- `security` leaf captures the kernel-policy + Kconfig matrix that drives most boot failures (CONFIG_VIRTIO_BLK, CONFIG_ACPI/CONFIG_PCI dependency, CONFIG_KVM_GUEST), plus the seccomp boundary structure (per-thread JSON, default vs custom, debug-binary gap).
- `networking` leaf documents the three routing patterns (NAT/bridge/namespaced-NAT-for-clones) + MMDS V1-vs-V2 + token-bucket rate limiter shape — including the snapshot-non-persistence of MMDS data store (intentional, to avoid leaking VM-specific identifiers into clones).
- `vsock` leaf encodes the host-initiated CONNECT/OK handshake protocol + guest-initiated per-port UDS pattern + the `vsock_override` snapshot-restore hook for clone path-collision avoidance.
- `setup` leaf captures the production-hardening checklist: SMT off, KSM off, swap off, Rowhammer-mitigated memory, kvm-pit kthread CPU-overhead mitigation (modprobe min_timer_period_us), signal-handler-deadlock-risk overwatcher pattern, and the concrete `console=ttyAMA0` example showing how host kernel logging degraded snapshot restore from 3ms → 8.5ms on aarch64.

**Infra:** Same orphan-MCP cleanup pattern — kill via `Get-CimInstance` filter + Stop-Process between extraction batches. The friction is consistent enough across sessions that this should become a session-startup hook.

**Deferred:**
- Session 3.4: Phase D failure_modes (target 70+) + Phase E intra-firecracker relationships.
- ECS P3 (Sessions 3.5-3.6) after firecracker P3 fully lands.

**Next:** Pipe `domains/_shared/sessions/phase-3-deep-extraction.md` for Session 3.4 (firecracker failure_modes + relationships — the gold layer).

### Session P4.fc + P5.fc — 2026-05-03 — firecracker first slice — DONE

**Doctrine note:** Per PREAMBLE.md line 33, failure_modes = master Phase 4 and relationships = master Phase 5, both running horizontally after all domains have P1+P3. The older `phase-3-deep-extraction.md` listing them as Phase 3 outputs is stale; PREAMBLE wins. User chose to run the firecracker slice now anyway given interview-prep deadline. Cross-domain refs (linux/devin/aws) deferred to the eventual horizontal P4/P5 pass. Plans: `~/.claude/plans/purring-pondering-gosling.md` (doctrine delta) + `~/.claude/plans/firecracker-p3-vertical.md` §5.

**Outputs:**

| Table | Rows added | Cumulative |
|---|---|---|
| `firecracker.failure_modes` | **71** (target 70+) | 71 |
| `firecracker.relationships` | **231** (target 200+) | 231 |

Failure_modes split by primary leaf: vmm 20, snapshots 12, networking 15 (incl. vsock failures), setup 24. Sources: 15 high-engagement Firecracker GH issues (#4881, #1456, #1064, #668, #815, #1573, #1253, #2268, #3905, #2172, #1751, #1088, #259, #596, #420), 4 e2b-dev/infra issues (#127, #89, #130, PR #148), 1 Fly community thread (virtio-balloon overcommit), and ~15 corpus-document mining (prod-host-setup, seccomp, network-setup, snapshot-support, jailer, kvm-api, FAQ).

Relationships generation: 69 hand-curated cross-leaf (snapshots↔kvm/api/networking, jailer↔security/vmm, api↔devices, comparable-systems↔vmm) + 146 auto-derived from failure_modes.affected_concepts via SQL `INSERT ... SELECT id, unnest(affected_concepts), 'affects', source_ids[1] FROM failure_modes` + 16 auto-derived KVM_CAP→vmm `required-by`.

**Verified:**
- 0 true orphans across `affected_concepts` and `relationships.{from_id,to_id}` (fixed 2 typos: `firecracker.snapshots.snapshot-load` → `firecracker.api.cmd.load-snapshot`)
- Every failure_mode has ≥1 diagnostic_step + ≥1 fix_step + non-null confidence (range 0.5-0.95)
- `last_verified` = 2026-05-03 on all rows

**Firecracker domain final state:**

| Table | Total |
|---|---|
| sources | 37 |
| documents | 37 |
| concepts | 172 |
| commands | 130 |
| config_keys | 119 |
| failure_modes | 71 |
| relationships | 231 |

The harness now has structured runbook coverage for the high-engagement firecracker failure modes — `pnpm harness <symptom>` should return useful failure_mode rows with diagnostic + fix steps + source citations for interview-prep scenarios.

**Infra:** Same orphan-MCP cleanup pattern; 5+ Stop-Process calls during the session. Worth automating.

**Firecracker vertical: COMPLETE.** Next: `ecs` P3 (lower priority, sketched in firecracker-p3-vertical.md §6) OR resume documented order (docker → linux → devin → k8s).

### Session E1 — 2026-05-03 — ecs agent + task-defs Phase C — DONE

Per-domain detail: `domains/ecs/PROGRESS.md`. Plan: `~/.claude/plans/purring-pondering-gosling.md`.

**Outputs (2 high-density ECS leaves):**

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `agent` | 25 | 8 | 61 |
| `task-defs` | 18 | 2 | 70 |
| **TOTAL E1** | **43** | **10** | **131** |

Cumulative ECS: 43 / 10 / 131.

**Notable**: agent's ECS_AGENT_* env-var coverage (61 keys) was 2x the plan target — the ecs-agent-readme env-var table is comprehensive. task-defs config_keys (70) cover the full Task Definition + Service Definition JSON schema.

**Acceptance vs plan E1 floors:** ✓ concepts ≥35 (hit 43), ✓ commands ≥8 (hit 10), ✓ config_keys ≥75 (hit 131).

**Next:** Session E2 — Phase C for launch-types + nitro-baremetal + networking + troubleshooting (target +39 concepts +10 commands +23 config_keys).

### Session E2 — 2026-05-03 — ecs fill-out leaves Phase C — DONE

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `launch-types` | 12 | 4 | 8 |
| `nitro-baremetal` | 10 | 2 | 5 |
| `networking` | 12 | 4 | 8 |
| `troubleshooting` | 5 | 0 | 2 |
| **TOTAL E2** | **39** | **10** | **23** |

Cumulative ECS after E1+E2: **82 / 20 / 154**. All 6 leaves populated. Acceptance vs E2 plan §7: all 3 floors hit.

**Highlights:** launch-types covers 5 launch types (EC2/Fargate/Fargate Spot/External/Managed Instances) + capacity providers (base+weight, managedScaling, managedTerminationProtection) + AMI variants/SSM-parameter pattern; nitro-baremetal covers Nitro v2-v6 cumulative features + bare-metal use cases + nested-virt cross-link to firecracker.kvm; networking covers 4 modes + ENI trunking (HDE) + Service Connect + TMDS v3/v4; troubleshooting captures stoppedReason taxonomy + CannotPullContainerError sub-classes.

### Session P4.ecs + P5.ecs — 2026-05-03 — ecs first slice — DONE

Per the doctrine: failure_modes/relationships = master Phase 4/5; running as "first slice for ecs" given interview-prep deadline + cross-domain refs to firecracker (now feature-complete) are resolvable.

**Outputs:**

| Table | Rows | Cumulative |
|---|---|---|
| `ecs.failure_modes` | **50** (target met) | 50 |
| `ecs.relationships` | **134** (target ~120 — exceeded) | 134 |

Failure_modes split by primary leaf: agent 24 (catch-all incl. storage/exec/SSM/codedeploy), task-defs 11, networking 8, troubleshooting 7.

Sources: amazon-ecs-agent issues + AWS re:Post troubleshooting threads + corpus errors (CannotPullContainerError/ResourceInitializationError sub-classes, placement-failure reasons, OOM, health-check cascades, deployment circuit-breaker, ENI exhaustion, IMDS leaks, ASG scale-in without protection, Spot interruption, Container Insights config, bare-metal boot timeout, AL2 EOL 2026-06-30 migration, ECS Exec SSM perms, EFS mount, awslogs missing log-group, FireLens config syntax, Fargate ephemeral storage, CodeDeploy blue-green, cross-account ECR, ECS Anywhere SSM activation expired, task-stuck-in-STOPPING signal handling, account-setting ARN format, environment-files S3, Fargate platform-version pinning, Fargate restricted syscalls/caps, bare-metal Firecracker hosting tuning).

**4 cross-domain relationships fulfilled** (the deferred P5.fc TODOs):
- `ecs.launch-types.fargate → firecracker.vmm.firecracker-vmm runs-on` (source: fc-aws-fargate-dataplane)
- `ecs.nitro-baremetal.bare-metal-instance → firecracker.kvm.kvm-subsystem enables-nested-kvm-on` (source: ecs-ec2-nested-virt)
- `ecs.nitro-baremetal.nitro-hypervisor → firecracker.vmm.firecracker-vmm adjacent-substrate` (source: ecs-aws-baremetal-announce)
- `ecs.nitro-baremetal.bare-metal-instance → firecracker.setup.production-checklist recommended-host-config` (source: ecs-aws-baremetal-announce)

Plus 32 hand-curated intra-ecs cross-leaf rels + 98 auto-derived from failure_modes.affected_concepts.

**Verified:** zero orphan IDs across all relationships (after fixing 1 typo: `ecs.agent.cgroup-task-level-limits` → `ecs.agent.task-cpu-mem-limit`). All `affected_concepts` resolve in either ecs.* OR firecracker.* (cross-domain allowed in this slice).

**Final ECS domain state:**

| Table | Total |
|---|---|
| sources | 21 |
| documents | 21 |
| concepts | 82 |
| commands | 20 |
| config_keys | 154 |
| failure_modes | 50 |
| relationships | 134 |

**ECS vertical: COMPLETE.** Combined with firecracker (37 sources, 172/130/119 + 71 fms + 231 rels), the AWS-runtime cluster of the corpus is fully built — including the load-bearing Fargate↔Firecracker + Nitro↔Firecracker cross-domain links.

**Next:** resume documented domain order (docker → linux → devin → k8s) OR pivot to harness/synthesis work. Per CLAUDE.md PREAMBLE, after all P1+P3 verticals land, run horizontal P2 (devin devbox capture) + P4 (cross-domain failure-modes) + P5 (cross-domain relationships) + P6+ (harness, polish).
