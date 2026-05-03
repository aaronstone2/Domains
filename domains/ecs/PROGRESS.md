# `ecs` — PROGRESS log

Per-domain progress for the AWS ECS (on bare-metal EC2) knowledge domain.
Phase plans live in `_PHASE-1-PLAN.md` (per phase). Per-leaf detail in `<leaf>/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.2 — 2026-05-02 — DONE

**Scope decision**: Added together with `firecracker` per session plan (`~/.claude/plans/purring-pondering-gosling.md`). ECS bare-metal coverage is for substrate-comparison context (containers-on-bare-metal vs in-microVMs), not directly Devin-relevant — but the Nitro System layer is a clean cross-link to `firecracker.kvm`.

**Outputs:**

- 21 / 21 sources fetched, staged, loaded into `ecs.{sources,documents}`. Mean 18,240 chars/doc. 0 fetch failures. Largest: ecs-agent-changelog (121k), ecs-dg-task-defs-params (87k), ecs-dg-service-defs-params (44k), ecs-agent-readme (37k), ecs-dg-optimized-ami (17k).
- BM25 FTS index `fts_ecs_documents` built. 4 verification queries pass.
- 6 leaves scaffolded via `pnpm leaf add`: launch-types (3 sources), task-defs (2), agent (8 incl. amazon-ecs-agent + amazon-ecs-init READMEs/CHANGELOG/proposals), networking (1 + 2 from agent's `proposals/` dir), nitro-baremetal (4 incl. AWS bare-metal + Nitro + nested-virt docs), troubleshooting (1).
- `paths.py:DOMAIN_SCHEMAS` and `queries/cross_domain.sql:meta.all_*` views extended.

**Known thin docs (3, non-blocking):**

- `ecs-dg-agent`, `ecs-dg-agent-update`, `ecs-dg-capacity-providers` returned 0 chars under trafilatura. These are AWS Developer Guide *hub pages* whose main content is just intro + section nav (links out to sub-pages). Trafilatura's main-content detection drops them as boilerplate. Phase 1.5 follow-up: replace with sub-page URLs OR add a playwright fallback OR custom AWS-docs parser. For now, surrounding sources cover the conceptual ground (e.g., `ecs-dg-instance-draining`, `ecs-dg-agent-config` cover the nearby topics).

**Verified:**

- FTS Q6 (awsvpc ENI) → ecs-agent-changelog top-1 (3.106), ecs-dg-task-networking #2
- FTS Q7 (agent registration) → ecs-agent-changelog top-1, ecs-dg-agent-config #3 (in top-5)
- FTS Q8 (bare metal Nitro) → ecs-ec2-nitro top-1 (6.991), ecs-aws-baremetal-announce #4
- Single-term `metal` → ecs-aws-baremetal-announce top-1, ecs-ec2-nitro #2
- Substring: ecs-dg-task-networking has `awsvpc` AND `bridge` ✓
- meta.all_documents includes ecs (21 rows)

**Substring miss (non-blocker):**

- `ecs-agent-readme` does NOT contain `ECS_CONTAINER_INSTANCE_ARN` literal — README links out to docs rather than inlining env vars. `ecs-dg-agent-config` (3,390 chars) is the canonical env-var reference and is loaded.

**Infra changes (this session, shared with firecracker):**

- See `domains/firecracker/PROGRESS.md` for shared infra changes (paths.py, cross_domain.sql, FK gotcha, MCP cleanup).

**Deferred:**

- 3 0-char hub-page sources — sub-page replacement OR playwright fallback in Phase 1.5.
- ECS Best Practices Guide deep ingest (only the index landed; sub-pages deferred).
- ECS Managed Instances (newer 2024 launch type) — not in Phase 1 MVP; add when needed.
- `relationships` rows — Phase 5.

**Next:** `firecracker` Phase 3 first (higher-leverage interview-prep). `ecs` Phase 3 follows. Recommended ecs leaf order when we get there: `agent` → `nitro-baremetal` → `task-defs` → `networking` → `launch-types` → `troubleshooting`.

## Phase 3 — Concepts/commands/config_keys extraction

### Session E1 — 2026-05-03 — DONE — agent + task-defs Phase C

Plan: `~/.claude/plans/purring-pondering-gosling.md`. Per the doctrine reframe: Sessions E1+E2 are legit Phase 3 (concepts/commands/config_keys); Session E3 is "P4.ecs + P5.ecs first slice."

**Outputs:**

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `agent` | 25 | 8 | **61** (target 30 — 2x) |
| `task-defs` | 18 | 2 | 70 (target 60 — exceeded) |
| **TOTAL E1** | **43** | **10** | **131** |

**Highlights:**
- **`agent` leaf**: ECS_AGENT_* env-var coverage came in much richer than estimated (61 vs 30 target). Anchored on amazon-ecs-agent README + ecs-init README + introspection-API doc + draining doc. Concepts include ACS protocol, introspection API (port 51678 endpoints), task IAM endpoint (169.254.170.2), CNI plugins, ENI trunking (HDE), Spot draining, container-instance state machine (ACTIVE↔DRAINING↔INACTIVE), engine-auth, cgroup task-level limits, image-cleanup policy, signal-handler caveats from ecs-init.
- **`task-defs` leaf**: 70 config_keys mined from ecs-dg-task-defs-params (87k char ref doc). Coverage spans task-level (family, taskRoleArn, executionRoleArn, networkMode, runtimePlatform, ephemeralStorage, ipcMode, pidMode, placementConstraints, proxyConfiguration, volumes, EFS volume sub-fields), container-level (name, image, cpu, memory, memoryReservation, command, entryPoint, environment, environmentFiles, secrets, essential, portMappings, mountPoints, volumesFrom, dependsOn, healthCheck sub-fields, logConfiguration sub-fields, repositoryCredentials, user, workingDirectory, privileged, readonlyRootFilesystem, dockerLabels, dockerSecurityOptions, ulimits, linuxParameters sub-fields including capabilities/devices/initProcessEnabled/sharedMemorySize/tmpfs, firelensConfiguration, systemControls, dnsServers, extraHosts), service-level (desiredCount, deploymentConfiguration, deploymentCircuitBreaker, capacityProviderStrategy, placementStrategy, healthCheckGracePeriodSeconds).

**ECS cumulative after E1:** 43 concepts, 10 commands, 131 config_keys.

**Acceptance vs E1 plan §7:** ✓ concepts ≥35, ✓ commands ≥8, ✓ config_keys ≥75 (hit 131).

**Deferred to E2:** Phase C for launch-types, nitro-baremetal, networking, troubleshooting.
**Deferred to E3:** P4.ecs failure_modes (50+ rows) + P5.ecs relationships (incl. cross-domain to firecracker).

**Next:** Session E2 — fill-out leaves Phase C.

### Session E2 — 2026-05-03 — DONE — fill-out leaves Phase C

**Per-leaf:**

| Leaf | Concepts | Commands | Config keys |
|---|---|---|---|
| `launch-types` | 12 | 4 | 8 |
| `nitro-baremetal` | 10 | 2 | 5 |
| `networking` | 12 | 4 | 8 |
| `troubleshooting` | 5 | 0 | 2 |
| **TOTAL E2** | **39** | **10** | **23** |

**Cumulative ECS after E1+E2:** 82 concepts / 20 commands / 154 config_keys.

**Notable:**
- `launch-types`: full coverage of EC2 / Fargate / Fargate Spot / External / Managed Instances launch types + capacity-provider mechanics (base+weight, managedScaling, managedTerminationProtection) + AMI variants + SSM-parameter pattern.
- `nitro-baremetal`: Nitro System components (Nitro Card, Security Chip, Hypervisor) + Nitro version matrix (v2-v6 cumulative features) + bare-metal use cases + nested-virt support + boot-time characteristic + cross-domain link to firecracker.
- `networking`: 4 network modes + ENI trunking (HDE) + per-task SG + assignPublicIp + Service Connect/Cloud Map + TMDS v3/v4 endpoint mechanics.
- `troubleshooting`: stoppedReason taxonomy + CannotPullContainerError sub-classes + ResourceInitializationError sub-classes + placement-failure reasons + service event log deciphering.

**Acceptance vs E2 plan §7:** ✓ concepts ≥70 (hit 82), ✓ commands ≥18 (hit 20), ✓ config_keys ≥95 (hit 154).

**Next:** Session E3 — P4.ecs failure_modes (50+) + P5.ecs relationships (incl. cross-domain to firecracker).

### Session P4.ecs + P5.ecs — 2026-05-03 — DONE — ecs first slice

Per the doctrine reframe (PREAMBLE.md line 33): failure_modes/relationships are master Phase 4/5, run as "first slice for ecs" given interview-prep deadline + cross-domain refs to firecracker (now feature-complete) are resolvable.

**Outputs:**

| Source-leaf | failure_modes |
|---|---|
| `agent` | 9 (+ 15 batch2 = 24 — agent leaf is the catch-all for agent/storage/exec/SSM/codedeploy/etc.) |
| `task-defs` | 11 (CannotPullContainerError variants, ResourceInitializationError sub-classes, placement, OOM, health-check, deployment circuit breaker) |
| `networking` | 8 (ENI quota/exhaustion, SG misconfig, host-mode port conflict, task-IAM-host-mode, ALB cascade, awsvpc no VPC endpoint, IMDS leak) |
| `troubleshooting` | 7 (ASG scale-in, Spot interruption, Container Insights config, bare-metal boot timeout, IAM perms, scheduled-task EventBridge, AL2 EOL) |
| **TOTAL** | **50** (target met) |

**Relationships (134 total):**
- 36 hand-curated cross-leaf + cross-domain (`extract/relationships-curated.json`)
- 4 cross-domain rels writable for the first time: `ecs.launch-types.fargate → firecracker.vmm.firecracker-vmm runs-on`, `ecs.nitro-baremetal.bare-metal-instance → firecracker.kvm.kvm-subsystem enables-nested-kvm-on`, `ecs.nitro-baremetal.nitro-hypervisor → firecracker.vmm.firecracker-vmm adjacent-substrate`, `ecs.nitro-baremetal.bare-metal-instance → firecracker.setup.production-checklist recommended-host-config`. Fulfills the deferred TODO list from firecracker P5.fc.
- 98 auto-derived from `failure_modes.affected_concepts` via SQL: `INSERT INTO ecs.relationships SELECT id, unnest(affected_concepts), 'affects', source_ids[1] FROM ecs.failure_modes`.

**Verified:** zero orphan from_id/to_id/affected_concepts (after fixing 1 typo `ecs.agent.cgroup-task-level-limits` → `ecs.agent.task-cpu-mem-limit`).

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

**ECS vertical: COMPLETE.** All 4 deferred firecracker→ecs cross-domain rels fulfilled. Cross-refs to docker/linux/devin (not yet extracted) still defer to horizontal P5.
