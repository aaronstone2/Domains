# `linux/systemd` — PROGRESS log

Per-leaf log; rolls up into `domains/linux/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.4 — 2026-05-03 — DONE

**Outputs:** 107 concepts / 9 commands / 311 config_keys = **427 rows** (plan target 386; landed 11% over). Config-key-densest leaf as planned — 311 directives across 15 scopes.

**Concept kind distribution:** concept 49, feature 31, file 8, subsystem 7, state 7, driver 3, protocol 2.

**Commands (9 of 9 planned):** systemctl, journalctl, systemd-analyze, systemd-run, systemd-cgls, systemd-cgtop, loginctl, coredumpctl, systemd-tmpfiles. ~150 flags + ~22 examples.

**Config_keys scopes (15):** systemd-exec-directive 71, systemd-resource-control-directive 30, journal-field 27, systemd-path-variable 23, systemd-unit-directive 23, systemd-service-directive 22, journald-conf-directive 19, systemd-socket-directive 18, systemd-timer-directive 13, systemd-tmpfiles-directive 11, systemd-mount-directive 9, systemd-path-directive 8, coredump-conf-directive 7, systemd-scope-directive 5, systemd-slice-directive 4.

**Verified:**
- ✓ 0 orphan source_ids
- ✓ 0 empty source_ids
- ✓ 0 PK collisions (after fixing one ID typo `linux.systemd-systemd-subsystem` → `linux.systemd.systemd-subsystem` via UPDATE in DB and Edit in JSON)
- ✓ Spot-check 5 random rows: all sane

**Method delta:** ID typo caught after load. Fixed in DB via UPDATE, synced JSON via Edit. No re-load needed.

**Source attribution:**
- systemd.exec(5) (230 KB) primary for systemd-exec-directive scope (71 directives — the largest scope in any leaf)
- systemctl(1) (102 KB) sole source for systemctl command
- systemd.unit(5) (92 KB) primary for systemd-unit-directive
- systemd.service(5) (72 KB) primary for systemd-service-directive
- systemd.resource-control(5) (64 KB) primary for systemd-resource-control-directive
- systemd-analyze(1) (59 KB) sole source for systemd-analyze
- systemd(1) (54 KB) primary for manager concepts
- journalctl(1) (43 KB) primary for journalctl
- systemd.socket(5) (37 KB) primary for systemd-socket-directive
- journald.conf(5) (24 KB) primary for journald-conf-directive
- systemd-run(1) (23 KB) sole source for systemd-run
- systemd.mount(5) (21 KB) primary for systemd-mount-directive
- loginctl(1) (20 KB) sole source for loginctl
- systemd-tmpfiles(8) (20 KB) primary for systemd-tmpfiles + tmpfiles-directive
- systemd.timer(5) (18 KB) primary for systemd-timer-directive
- systemd-coredump(8) (15 KB) + coredumpctl(1) (9 KB) primary for coredump
- journal-fields(7) (15 KB) primary for journal-field scope
- systemd.path(5) (7 KB) primary for systemd-path-directive + systemd-path-variable

T2 sources: none (all T1).

**Boundary respect:**
- vs primitives: cgroup MODEL concepts in primitives. systemd-resource-control-directive translations (MemoryMax→cgroup memory.max, CPUQuota→cpu.max, etc.) owned here. Capability concepts in primitives; CapabilityBoundingSet=/AmbientCapabilities= directives owned here.
- vs networking: socket-API concepts in networking. systemd-socket-directive (ListenStream=, ListenDatagram=, Accept=) owned here.
- vs debugging: coredumpctl + systemd-coredump owned here. gdb/strace/perf/etc. in debugging.
- vs filesystem: systemd-mount-directive (.mount unit) owned here. mount(2)/mount(8)/fstab(5) syscalls + tools owned by filesystem.

**P4 failure-mode seeds (deferred):**
1. Service enters 'failed' immediately after start — start-limit hit, ExecStart fails, condition fails
2. Service won't start after reboot — not enabled
3. Service shows 'active (exited)' but should be running — Type=oneshot+RemainAfterExit when should be Type=simple
4. MemoryMax= ignored — MemoryAccounting=no or v1 cgroup
5. Logs missing from journalctl — Storage=none or rotation truncated
6. Slow boot — systemd-analyze blame + critical-chain
7. Service can't bind privileged port — needs CAP_NET_BIND_SERVICE in caps
8. PrivateTmp=yes breaks /tmp visibility — by design
9. ExecReload doesn't work — daemon doesn't handle SIGHUP, or ExecReload= unset
10. OOM killed inside cgroup — MemoryMax= hit, memory.events oom_kill > 0

**Cross-domain seeds (P5):**
- linux.systemd.cfg.rc.MemoryMax ↔ primitives.cgroup-v2-control-file.memory-max ↔ docker --memory
- linux.systemd.cfg.rc.CPUQuota ↔ primitives.cgroup-v2-control-file.cpu-max ↔ docker --cpus
- linux.systemd.cfg.exec.CapabilityBoundingSet ↔ primitives.cap-flag.* ↔ docker --cap-add/--cap-drop
- linux.systemd.cfg.exec.SystemCallFilter ↔ primitives.seccomp-bpf-program ↔ docker --security-opt seccomp=
- linux.systemd.cfg.exec.NoNewPrivileges ↔ primitives.set-no-new-privs ↔ docker --security-opt no-new-privileges
- linux.systemd.cgroup-driver ↔ docker.engine.cfg.daemon.json.cgroup-driver
- linux.systemd.coredump-handling ↔ linux.debugging.cmd.gdb (extracting from coredumpctl)
- linux.systemd.cmd.systemd-analyze 'security' subcommand ↔ container hardening posture

**Source list adjustments:** none.

**Next:** Session 3.5 — `linux/filesystem` (~335 rows; mount/overlayfs/ext4/xfs/lvm/cryptsetup — the final leaf).

## Cross-references

- Plan file (Phase 3): `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`
- Sister leaves: primitives 353, networking 355, debugging 252, systemd 427
- Extraction artifacts: `domains/linux/systemd/extract/{concepts,commands,config_keys}.json`
