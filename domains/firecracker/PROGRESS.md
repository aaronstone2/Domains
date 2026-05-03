# `firecracker` — PROGRESS log

Per-domain progress for the AWS Firecracker microVM knowledge domain.
Phase plans live in `_PHASE-1-PLAN.md` (per phase). Per-leaf detail in `<leaf>/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.2 — 2026-05-02 — DONE

**Scope decision**: Two new domains added together (`firecracker` + `ecs`) because cross-cutting research (cognition.ai/blog/what-we-learned-building-cloud-agents) revealed Devin's DevBox uses microVM isolation + hypervisor snapshotting — Firecracker-pattern (FC not named explicitly). Plan: `~/.claude/plans/purring-pondering-gosling.md`.

**Outputs:**

- 35 / 39 sources fetched, staged, loaded into `firecracker.{sources,documents}`. Mean 21,530 chars/doc; 0 thin docs. Largest: kvm-api (323k), fc-nsdi20-paper PDF (78k), fc-swagger-spec YAML (60k).
- BM25 FTS index `fts_firecracker_documents` built. 5 verification queries pass; predicted top-1 in top-3 for all.
- 10 leaves scaffolded via `pnpm leaf add`: vmm (8 sources), jailer (1), security (5 incl. seccomp/seccompiler/kernel-policy/SECURITY.md), snapshots (4), networking (3), vsock (1), api (3), kvm (3), setup (2), comparable-systems (4 e2b — 4 more failed). Plus 1 NSDI paper + 2 AWS blogs + 2 production writeups.

**Failures (4 known, non-blocking):**

- e2b-docs-sandbox-overview, e2b-docs-sandbox-lifecycle, e2b-docs-filesystem, e2b-docs-commands — all flagged TODO-verify URLs in plan; e2b doc paths probably restructured. Phase-1 follow-up: WebSearch correct URLs and re-fetch with `--source-id`.

## Phase 3 — Concept/command/config_keys/failure_modes extraction

### Session 3.2 — 2026-05-02 — DONE — high-tier leaves Phase C

Plan: `~/.claude/plans/firecracker-p3-vertical.md`. Per-domain unit (P1+P3 vertical) per the doctrine in `domains/_shared/sessions/PREAMBLE.md`.

**Pre-prep:**
- Added `fc-repo-faq` (FAQ.md, 12k chars) — Phase-1.5 patch surfaced by P3 plan-mode meta-research.
- Mid-session added `fc-docs-ballooning` (21k chars) when extraction surfaced it as a referenced-but-missing source.
- Firecracker now: **37 sources**.

**Per-leaf extraction (high-tier set):**

| Leaf | Concepts | Commands | Config keys | Notes |
|---|---|---|---|---|
| `kvm` | 30 | 52 | 16 | Densest leaf. ioctl reference per fd-class (system/vm/vcpu/device); 50+ KVM ioctls including KVM_RUN, KVM_SET_USER_MEMORY_REGION, KVM_GET_DIRTY_LOG, KVM_IRQFD/IOEVENTFD; 16 KVM_CAP_* config_keys. |
| `api` | 25 | 38 | 18 | All 38 swagger operationIds → command rows. Concepts cover Unix-socket transport, pre-boot vs runtime states, PUT vs PATCH semantics, snapshot create/load operations. |
| `vmm` | 25 | 12 | 19 | Anchored on NSDI paper + design.md + getting-started + FAQ. CLI-flag config_keys, kernel-arg config_keys (reboot=k, console=ttyS0), host-sysctl config_keys (vm.min_free_kbytes, hugepages, fd ulimit). |
| `snapshots` | 19 | 8 | 12 | Cognition-aligned subsystem. Concepts cover full vs diff, MAP_PRIVATE vs UFFD backends, dirty-page protocol, VMGenID, network-disruption-on-resume, cgroup-v1 latency tax, snapshot-portability constraints. |
| `jailer` | 12 | 5 | 12 | Single-doc concentrated leaf. Cgroup setup (v1+v2), chroot pivot, uid/gid drop, netns join, resource limits, daemonize, new-pid-ns, /dev mknod passthrough. |
| `comparable-systems` | 8 | 0 | 0 | e2b proxy for Devin DevBox architecture inference. Includes 'devin-devbox-likely-pattern' inferred-architecture row, sandbox fan-out pattern, SDK-over-sandbox-API abstraction. |
| **TOTAL** | **119** | **115** | **77** | |

**Acceptance:**
- ✓ Concepts ≥100 (target 133, hit 119).
- ⚠ Commands 115 vs floor 120 — 5 short. Acceptable: kvm + api carry the bulk; the deficit is in lower-priority vmm/jailer leaves where commands are sparse by nature (most actions are API calls under api leaf, not standalone CLI commands).
- ✓ Config_keys ≥60 (target 80, hit 77).
- ✓ Per-leaf JSON files in `domains/firecracker/<leaf>/extract/`.
- ✓ All loads succeeded; orphan-source-id check returns only valid cross-domain ref to `devin-cognition-cloud-agents` (lives in devin schema, valid by design — failure_modes/concepts source_ids is VARCHAR[] with no FK).

**Infra notes (this session):**
- DuckDB lock contention with respawning motherduck MCP processes was persistent — required killing PID-targeted orphans 4 times during the session. Pattern is the same as Session 1.2's note in `_shared/PROGRESS.md`. Documented in user-memory `feedback_motherduck_orphan_kill.md` (saved after this session).

**Deferred to Session 3.3:**
- Phase C for fill-out leaves: `security`, `networking`, `vsock`, `setup`. Targets ~48 concepts, 10 commands, 30 config_keys.

**Deferred to Session 3.4:**
- Phase D failure_modes (target 70+): mine 15 high-engagement FC GitHub issues + 5 e2b/infra issues + scattered errors from prod-host-setup/seccomp/network-setup docs + Fly community + FC FAQ (now ingested).
- Phase E intra-firecracker relationships. Cross-domain (firecracker→linux/devin/aws) deferred to horizontal Phase 5 per PREAMBLE doctrine.

**Next:** Pipe `domains/_shared/sessions/phase-3-deep-extraction.md` for Session 3.3 (fill-out leaves).

### Session 3.3 — 2026-05-03 — DONE — fill-out leaves Phase C

**Per-leaf extraction (fill-out set: security, networking, vsock, setup):**

| Leaf | Concepts | Commands | Config keys | Notes |
|---|---|---|---|---|
| `security` | 17 | 0 | 18 | Seccomp boundary + thread-keyed filter structure + custom-filter override + kernel-policy matrix + minimal-boot Kconfig + ACPI-vs-MPTable transition. 18 guest-kernel CONFIG_* + boot-arg config_keys. |
| `networking` | 15 | 7 | 12 | TAP backend, NAT/bridge/namespaced-NAT routing patterns, MMDS V1 vs V2, default IP, token TTL, snapshot non-persistence of MMDS data. Token-bucket rate limiter detail. |
| `vsock` | 7 | 3 | 0 | Single-doc concentrated. CID/port addressing, UDS multiplexing, host-initiated CONNECT/OK handshake, guest-initiated per-port UDS pattern, snapshot reset, vsock_override on restore. |
| `setup` | 14 | 5 | 12 | Production hardening: SMT off, KSM off, swap off, Rowhammer, kvm-pit overhead mitigation, signal-handler deadlock risk, host-kernel quiet/loglevel recommendation, rootfs+kernel build patterns. 12 cgroup-v1 + sysfs + modprobe config_keys. |
| **TOTAL (3.3)** | **53** | **15** | **42** | |

**Cumulative across both 3.2 + 3.3:**

| Table | Total | Plan target | Status |
|---|---|---|---|
| `firecracker.concepts` | 172 | 188 (cap) / 160 (floor) | ✓ above floor |
| `firecracker.commands` | 130 | 168 (cap) / 150 (floor) | ⚠ 20 short of floor (commands concentrated in kvm + api by leaf nature; floor was aspirational) |
| `firecracker.config_keys` | 119 | 110 (cap) / 100 (floor) | ✓ exceeded cap |

All 10 leaves now have non-zero concept rows. Commands deficit is distributed across vmm/jailer/networking/setup where most "actions" surface as API calls (already counted under api leaf, 38 commands) or kernel/host operations rather than CLI commands.

**Verified:**
- Per-leaf JSON files written to `domains/firecracker/<leaf>/extract/{concepts,commands,config_keys}.json` and loaded via `INSERT INTO firecracker.<table> SELECT * FROM read_json_auto(...)`.
- Same DuckDB-lock contention with respawning motherduck MCP processes; killed via `Get-CimInstance ... | Stop-Process` pattern as needed.

**Deferred to Session 3.4:**
- Phase D failure_modes (target 70+): mine 15 high-engagement FC GitHub issues + 5 e2b/infra issues + scattered errors from prod-host-setup + seccomp + network-setup docs + Fly community + FC FAQ.
- Phase E intra-firecracker relationships. Cross-domain rels deferred to horizontal Phase 5.

**Next:** Pipe `domains/_shared/sessions/phase-3-deep-extraction.md` for Session 3.4 (failure_modes + relationships — the gold layer).

### Session P4.fc + P5.fc — 2026-05-03 — DONE — firecracker first slice

**Doctrine clarification (this session):** Per PREAMBLE.md line 33, failure_modes belong to master Phase 4 and relationships to master Phase 5, both running horizontally across the corpus AFTER all domains have P1+P3 landed. The older `phase-3-deep-extraction.md` doc lists them as Phase 3 outputs — that's stale. PREAMBLE wins.

User decision: do the firecracker slice now anyway (interview-prep deadline). Labeled correctly as "Phase 4 first slice / Phase 5 first slice for firecracker." Cross-domain `affected_concepts` references (linux/devin/aws) deferred to the eventual horizontal P4/P5 pass.

Plan: `~/.claude/plans/purring-pondering-gosling.md` (the doctrine delta) + `~/.claude/plans/firecracker-p3-vertical.md` §5 (the original Session 3.4 design).

**Phase 4 first slice — `firecracker.failure_modes` (71 rows):**

| Source-leaf file | Rows | Coverage |
|---|---|---|
| `vmm/extract/failure_modes.json` | 20 | boot/init/OOM/signal/shutdown — kernel 6.1 panic #4881, AMD Zen MSR 0x10a #815, KVM init Error(13) #2268, /dev/kvm busy, page-alloc-failure, exit code 12 OOM, OOM despite available #1573, KVM_EXIT_SHUTDOWN seccomp #1456, signal-handler seccomp #1064, panic-handler mremap #1088, signal-handler deadlock, x86 no-poweroff, missing reboot=k, serial-console boot perf, missing CONFIG_VIRTIO_BLK, missing CONFIG_ACPI, cross-arch guest, pci=off mismatch, KVM_EXIT_INTERNAL_ERROR, KVM_EXIT_FAIL_ENTRY nested |
| `snapshots/extract/failure_modes.json` | 12 | CRC mismatch, cgroup-v1 latency #2129, GIC v2↔v3 mismatch, MSR_IA32_TSX_CTRL non-preservation, TSC freq mismatch, CPUID divergence, virtio block FLUSH not syncing #2172, VMGenID early-boot crash, diff-snapshot without track_dirty, mem_file deleted while VM running, UFFD handler crash, network disrupt after resume |
| `networking/extract/failure_modes.json` | 15 | virtio-net LRO #3905, TAP CAP_NET_ADMIN, ip_forward disabled, NAT masquerade missing, MMDS unreachable, MMDS V1 SSRF, MMDS data lost on snapshot, single-queue TAP cap, rate-limit req exceeds bucket #259, vsock CONNECT pre-init #1253, vsock stream errors #1751, UDS path collision in clones, missing CONFIG_VIRTIO_VSOCKETS, vhost-vsock host module missing, guest-initiated vsock no host listener |
| `setup/extract/failure_modes.json` | 24 | kvm-pit CPU overhead, host-kernel-logs slow restore, SMT enabled, KSM enabled, swap enabled, fd ulimit too low, --no-seccomp prod, debug binary prod, drive Unsafe-cache data loss, drive backing file missing, pre-boot-only after boot, jailer cgroup-v2 subtree-control trap, jailer chroot perms, virtio-balloon overcommit (Fly community), e2b UFFD process killing race PR#148, e2b client restart cascade #127, e2b clock drift #89, e2b health-check cascade #130, virtio-net TX scatter-gather #420, dirty-page tracking overhead, hugepages not reserved, smt:true machine-config, API on TCP attempt, action without prerequisites |
| **TOTAL** | **71** | exceeded 70+ target |

**Phase 5 first slice — `firecracker.relationships` (231 rows):**

| Source | Pattern | Rows |
|---|---|---|
| `extract/relationships-curated.json` (hand-written cross-leaf) | snapshots↔kvm (cpuid/msr/tsc/dirty-log requires/uses), jailer↔security/vmm (complements/implements-layer-of), api↔snapshots/networking/vsock/vmm (implements/depends-on/is-one-of-the-6-devices), comparable-systems↔fc (runs-on/abstracts), production-checklist↔mitigations | 69 |
| Auto-derived from failure_modes.affected_concepts | `(fm_id, affected_concept_id, 'affects', source_ids[1])` per unnest | 146 |
| Auto-derived from KVM_CAP config_keys | `(kvm_cap_id, 'firecracker.vmm.firecracker-vmm', 'required-by', source_ids[1])` | 16 |
| **TOTAL** | | **231** (exceeded 200+ target) |

**Verification — all PASS:**
- ✓ `count(failure_modes)` = 71 (target 70+)
- ✓ Every `unnest(affected_concepts)` resolves in `firecracker.{concepts,commands,config_keys,failure_modes}` (0 true orphans after fixing 2 `firecracker.snapshots.snapshot-load` typos → `firecracker.api.cmd.load-snapshot`)
- ✓ Every failure_mode has ≥1 diagnostic_step + ≥1 fix_step + non-null confidence
- ✓ `last_verified` = 2026-05-03 on all rows
- ✓ `count(relationships)` = 231 (target 200+)
- ✓ Every relationship `from_id` and `to_id` resolves in firecracker entity tables (0 orphans)

**Cumulative firecracker domain (after P1.2 + 3.2 + 3.3 + P4.fc + P5.fc):**

| Table | Total |
|---|---|
| sources | 37 |
| documents | 37 |
| concepts | 172 |
| commands | 130 |
| config_keys | 119 |
| failure_modes | 71 |
| relationships | 231 |

**Deferred to horizontal Phase 4 (later, after other domains' P3):**
- Resolve cross-domain `affected_concepts` refs (e.g. `firecracker.jailer.jailer` → `linux.seccomp` once linux concepts exist)
- Resolve cross-domain `relationships` rows (per the deferred-rels list captured in `_PHASE-1-PLAN.md`)

**Firecracker vertical: COMPLETE.** Next vertical: `ecs` P3 (sketched in firecracker-p3-vertical.md §6) OR resume the documented order (docker → linux → devin → k8s).
