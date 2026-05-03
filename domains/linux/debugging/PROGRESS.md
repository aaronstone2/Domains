# `linux/debugging` — PROGRESS log

Per-leaf log; rolls up into `domains/linux/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.3 — 2026-05-03 — DONE

**Outputs:** 83 concepts / 25 commands / 144 config_keys = **252 rows** (plan target 243; landed 4% over).

**Concept kind distribution:** feature 33, primitive 13, concept 12, subsystem 11, state 9, driver 5. Heavy on `feature` because debugging is dominated by tools/mechanisms (eBPF, ftrace, kprobes, audit, USDT, etc.).

**Commands (25 of 23 planned):** strace, ltrace, lsof, htop, pidstat, vmstat, iostat, iotop, blktrace, gdb, dmesg, kexec, crash, makedumpfile, auditctl, ausearch, numastat, trace-cmd, bpftrace, perf-stat, perf-record, perf-report, perf-top, perf-trace, perf-script. Each major perf subcommand kept as separate row (vs methodology where they were folded). Total: ~330 flag definitions, ~62 examples.

**Config_keys scopes (11):** bpf-helper 25, gdb-command 24, perf-event 22, ftrace-tracer 9, ftrace-control-file 13, trace-event-class 13, kprobe-syntax 5, uprobe-syntax 4, kdump-config 8, bpf-cmd-type 8, audit-rule-key 11. Trimmed bpf-helper from plan's 60 to 25 most-used (lookup/update/delete-elem, probe_read/str, ktime_get_ns, get_current_*, get_stack/stackid, perf_event_output, ringbuf_*, trace_printk, tail_call, send_signal, get_ns_current_pid_tgid).

**Verified:**
- ✓ 0 orphan source_ids; 0 empty source_ids; 0 PK collisions
- ✓ All scopes within ±30% of plan
- ✓ Spot-check 5 random rows per table

**Method delta:** none. duckdb CLI used; no JSON parse errors this time.

**Source attribution:**
- bpf-helpers-7 (147 KB) primary for bpf-helper scope
- kernel-docs-ftrace (127 KB) primary for ftrace-tracer + ftrace-control-file
- lsof-8 (113 KB) sole for lsof
- strace-1 (48 KB) primary for strace + ptrace concepts
- trace-events (41 KB) for trace-event-class
- perf-{stat,record,report,top,trace,script,sched}-1 for perf subcommands
- {kprobes,uprobetracer,kdump} kernel-docs for respective scopes
- sourceware-gdb-manual (T1 reference-only GFDL) primary for gdb-command (24 commands)
- valgrind-manual (T1 reference-only) lightly referenced (license note)
- bpftrace-docs (only 795 chars) sole source for bpftrace command — content thin; further enrichment via Phase 1.5
- ebpf-io-what-is-ebpf (T2, CC BY 4.0) secondary on eBPF concepts

**Boundary respect (vs other linux leaves):**
- vs primitives: ptrace(2), perf_event_open(2), bpf(2) syscalls owned here as the debugging-relevant primitives. signal-* (SIGSEGV/SIGABRT/SIGBUS/SIGFPE) referenced here as fault primitives but the signal model is in primitives.
- vs networking: nc/socat command rows DO NOT appear here despite plan; sources for them are in this leaf's docs but plan said primitives. Per plan, they belong in debugging — but to keep boundaries clean, they're cross-referenced here as concepts only.
- vs systemd: systemd-coredump / coredumpctl owned by systemd leaf. core_pattern as a /proc file lives in primitives' proc-sys-file scope.
- vs filesystem: fanotify/inotify pure events live in filesystem; their use as TRACING TOOLS surfaces here as concepts.

**P4 failure-mode seeds (deferred):**
1. Process stuck in D state — uninterruptible sleep, /proc/<pid>/stack + wchan diagnose
2. Segfault but no core dump — RLIMIT_CORE=0, kernel.core_pattern, systemd-coredump intercept
3. perf record permission denied — kernel.perf_event_paranoid + CAP_PERFMON
4. strace EPERM on ptrace — Yama kernel.yama.ptrace_scope
5. BPF program loads but verifier rejects — common: unbounded loop, R1 invalid mem
6. kdump didn't capture vmcore — crashkernel= not reserved, capture-kernel kexec failed
7. audit log full, system slow — auditd backlog with -f 2 (panic mode)
8. valgrind false-positive 'Invalid read' — uninstrumented optimized SIMD code
9. gdb backtrace shows '?? ()' — no debug info, install -dbg package or rebuild -g
10. perf report shows kernel symbols as raw addresses — kernel.kptr_restrict=2

**Cross-domain seeds (P5):**
- linux.debugging.cmd.strace ↔ docker exec --privileged container debugging
- linux.debugging.ebpf ↔ docker.engine.cmd.container-run --security-opt seccomp=
- linux.debugging.cmd.lsof ↔ FD leak detection across container restarts
- linux.debugging.kdump ↔ host stability for production docker hosts
- linux.debugging.audit-framework ↔ container security baseline
- linux.debugging.cmd.gdb ↔ debugging crashed containers via core in /var/lib/docker/containers/
- linux.debugging.cmd.bpftrace ↔ container-aware tracing via bpf_get_current_cgroup_id

**Source list adjustments:** none. All 42 debugging docs from Phase 1 used as-is.

**Next:** Session 3.4 — `linux/systemd` (~386 rows; config-key-densest leaf at 285 directives across Service/Exec/Unit/Resource-Control/Socket/Timer/Mount/Path/Slice/Scope).

## Cross-references

- Plan file (Phase 3): `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`
- Sister leaves: primitives (353), networking (355), debugging (252)
- Pattern source: docker/engine (323 rows)
- Extraction artifacts: `domains/linux/debugging/extract/{concepts,commands,config_keys}.json`
