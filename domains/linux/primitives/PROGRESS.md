# `linux/primitives` — PROGRESS log

Per-leaf log; rolls up into `domains/linux/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.1 — 2026-05-03 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`; pipe-able session prompt `domains/_shared/sessions/phase-3-deep-extraction.md`. Continued from linux Phase 1 (172 sources / 4.86 MB chars, BM25 FTS built). Filtered to 33 docs / 1.07 MB in `subdomain=primitives`.

**Outputs:**

| Table | Rows landed | Plan target | Plan range | Status |
|---|---:|---:|---|---|
| `linux.concepts` (`id LIKE 'linux.primitives.%'`) | **126** | 115 | 75–135 | ✓ within range |
| `linux.commands` | **3** | 7 | 5–10 | ⚠ under (4 commands deferred — sources not in corpus) |
| `linux.config_keys` | **224** | 165 | 140–195 | ⚠ 15% over ceiling (acceptable; content density is high) |

Total rows landed: **353**. Plan target was 287; landed 23% over.

**Concept kind distribution:**

| Kind | Landed | Plan |
|---|---:|---:|
| concept | 52 | 35 |
| primitive | 29 | 28 |
| feature | 14 | 22 |
| state | 13 | 12 |
| subsystem | 8 | 8 |
| file | 8 | 8 |
| driver | 2 | 2 |

`concept` is over plan because the namespace/cgroup/signal/cred surface is conceptually rich — many things plan listed as `feature` more naturally read as `concept` (e.g., mount-propagation modes are concepts, not features). `feature` correspondingly under. Subsystem/file/driver/state/primitive on target.

**Config_keys scope distribution:**

| Scope | Landed | Plan |
|---|---:|---:|
| cap-flag | 40 | 40 |
| cgroup-v2-control-file | 29 | 40 |
| kernel-cmdline | 26 | 80 |
| clone-flag | 21 | 20 |
| proc-sys-file | 19 | 35 |
| cgroup-v1-controller | 17 | 35 |
| mount-flag-MS_* | 12 | (not in original plan; absorbed from filesystem leaf cross-reference) |
| prctl-option | 11 | 15 |
| seccomp-action | 8 | 8 |
| iostat-field | 8 | 12 |
| sigaction-flag | 7 | 12 |
| namespace-proc-file | 7 | 5 |
| keyring-operation | 7 | 8 |
| signal-safety-rule | 4 | 10 |
| pthread-attr | 4 | 8 |
| credential-flag | 4 | 6 |

`kernel-cmdline` (26 vs plan 80) is the biggest deviation — the full kernel-parameters page enumerates ~500 boot parameters, but the interview-likely subset fits in ~25 (init=, root=, ro/rw, mem=, panic=, console=, loglevel=, quiet, splash, mitigations=, intel_iommu=, intel_pstate=, cgroup_no_v1=, systemd.unified_cgroup_hierarchy=, transparent_hugepage=, hugepagesz=, hugepages=, ipv6.disable=, audit=, lsm=, selinux=, enforcing=, nokaslr, crashkernel=). The bulk of kernel-parameters.html is driver-specific tunables that won't surface in a Docker/Linux interview scenario. `cgroup-v1-controller` similarly trimmed because cgroup v2 is the modern default.

**Commands landed (3 of 7 planned):**

1. `linux.primitives.cmd.unshare` — 21 flags, 3 examples (`man7-unshare-1`)
2. `linux.primitives.cmd.nsenter` — 16 flags, 3 examples (`man7-nsenter-1`)
3. `linux.primitives.cmd.pivot-root` — 2 flags, 2 examples (`man7-pivot-root-8`)

Total flag definitions: **39**. Total example invocations: **8**.

**Commands deferred to Phase 1.5 (need source addition before extraction):**

- `setpriv(1)` — capability/uid/gid manipulation tool — **add `man7-setpriv-1` source**
- `capsh(1)` — capability inspection / shell-with-caps — **add `man7-capsh-1` source**
- `getpcaps(1)` — read process capabilities — **add `man7-getpcaps-1` source**
- `taskset(1)` — CPU affinity — **add `man7-taskset-1` source**

These are util-linux / libcap shipped tools, all on man7.org. Estimated ~30 KB combined source content; would add ~25-40 command flags. Pull in during a future Phase 1.5 gap-fill session.

**Verified (acceptance per plan):**

- ✓ Counts hit target order-of-magnitude for concepts and config_keys; commands under (deferred).
- ✓ 0 orphan source_ids (anti-join `linux.{concepts,commands,config_keys}.source_ids[]` against `linux.sources` returned 0 rows).
- ✓ 0 rows with empty source_ids array.
- ✓ 0 PK collisions (INSERT would have errored otherwise).
- ✓ Concept kind distribution within ±20% on most kinds; only `concept` and `feature` swapped weight as noted above.
- ✓ Config_key scope buckets all populated; cap-flag at exact plan target; clone-flag/seccomp-action/iostat-field on target.
- ✓ Spot-check 5 random rows per table: all sane; source_ids resolve.

**Method delta vs plan:** None substantive. The plan specified motherduck MCP for SQL; MCP was disconnected (consistent with linux Phase 1.5 / docker engine 3.1 precedent), so used `duckdb` CLI directly. Loaded via `INSERT INTO linux.<table> SELECT * FROM read_json_auto(..., format='array')` with explicit `columns={...}` STRUCT spec on the `commands` table per documented methodology lesson. No FK constraint trips this session (no INSERT OR REPLACE; just initial INSERTs into empty tables).

**Source attribution diligence:**

- `kernel-docs-kernel-parameters` (~500 KB) — used for `kernel-cmdline` scope only. Did not exhaustively mine — the high-frequency interview-likely subset is ~25 entries; the rest is driver-specific tuning out of scope.
- `kernel-docs-cgroup-v2` (124 KB) — primary source for ~25 cgroup v2 concepts + 16 cgroup-v2-control-file rows.
- `man7-capabilities-7` (53 KB) — every cap-flag row + most cap-related concepts.
- `man7-clone-2` + `man7-prctl-2` + `man7-seccomp-unotify-2` + `man7-keyrings-7` + `man7-signal-7` — tight per-row attribution; multi-source where concepts span (e.g., `set-no-new-privs` cites both prctl-2 and capabilities-7).
- `ubuntu-wiki-apparmor` (T2) — used as secondary source on `apparmor-profile-model` only. No sole-source rows.
- LSM index/SELinux/AppArmor docs (1-2 KB each — slim) — anchor concepts only; no config_keys mined (those would belong in linux/primitives only if SELinux booleans / AppArmor profile syntax were extracted, which is out of scope here).

**Boundary respect (vs other linux leaves):**

- **vs `linux/networking`:** concepts ABOUT network namespaces (lifecycle, scope) live here; the network-stack details (IP routing, sockets, iptables, conntrack) are owned by `linux/networking`. `proc-sys-file` scope here EXCLUDES `net.*` sysctls (those go in networking).
- **vs `linux/filesystem`:** `mount-flag-MS_*` could live in either place. Per the plan's overlap rules, the kernel-side flag definitions live HERE; `linux/filesystem` will reference them when documenting the `mount(8)` `-o` option surface. Same for `mount-syscall` semantics — owned here as a primitive, referenced from filesystem.
- **vs `linux/systemd`:** cgroup MODEL concepts here (cgroup-v2-control-file scope = the kernel interface). systemd's per-directive translations (`MemoryMax=`, `CPUQuota=`, `Slice=`) are owned by `linux/systemd` in the `systemd-resource-control-directive` scope. They're related but distinct rows. Capabilities live HERE; systemd's `CapabilityBoundingSet=` directive lives in `linux/systemd` and references back.
- **vs `linux/debugging`:** ftrace/perf/eBPF concepts owned by `linux/debugging`. The `iostat-field` scope here documents `/proc/diskstats` field semantics (kernel-side); the `iostat(1)` tool man page extraction belongs in `linux/debugging`.

**Deferred to P4 (failure-modes, horizontal):**

The following primitive-related failure-mode seeds surfaced during reading but are NOT mined now (strict P3 boundary). Sketch for the future P4 pass:

1. **"docker stop hangs for 10s then SIGKILLs"** — pid-1-init-semantics: container init ignores SIGTERM because no handler installed and PID 1 drops default-action signals. Diagnosis: `nsenter -t <pid> -p ps`; check if init is tini/dumb-init or naive shell. Fix: `--init` flag, or use exec-form CMD, or ship a real init.
2. **"zombie processes accumulate inside container"** — pid-1 init not reaping orphans. Diagnosis: `docker exec <c> ps -o pid,ppid,state,cmd | grep Z`. Fix: tini/dumb-init.
3. **"cannot create user namespace EPERM"** — kernel.unprivileged_userns_clone=0 (Debian) or user.max_user_namespaces=0. Diagnosis: `sysctl kernel.unprivileged_userns_clone user.max_user_namespaces`. Fix: bump sysctls.
4. **"OOM-killed inside cgroup but host has memory free"** — cgroup memory.max hit. Diagnosis: `cat /sys/fs/cgroup/<cg>/memory.events`; expect `oom_kill > 0`. Fix: raise memory.max (systemd MemoryMax=).
5. **"CPU throttled despite low usage"** — cpu.max quota too low. Diagnosis: `cat /sys/fs/cgroup/<cg>/cpu.stat` — `nr_throttled` > 0 means throttling. Fix: raise quota or remove (cpu.max=max).
6. **"capability X dropped but binary still works"** — file capabilities or ambient set restoring it. Diagnosis: `getcap <bin>`; `cat /proc/<pid>/status | grep Cap`. Fix: `setcap -r` to clear file caps.
7. **"setuid binary doesn't gain privileges"** — caller has no_new_privs set. Diagnosis: `cat /proc/<pid>/status | grep NoNewPrivs`. Fix: launch from process without NNP (often blocked intentionally — that's the security feature working).
8. **"seccomp filter installed without CAP_SYS_ADMIN fails"** — no_new_privs not set. Diagnosis: check NNP. Fix: `prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)` before seccomp install.
9. **"mount inside container doesn't show on host"** — MS_PRIVATE propagation on the parent mount. Diagnosis: `findmnt -o TARGET,PROPAGATION`. Fix: remount with --make-shared on host before container start, OR change container's bind-mount to MS_REC|MS_SHARED.
10. **"unkillable process in D state"** — uninterruptible sleep stuck in IO. Diagnosis: `cat /proc/<pid>/stack`; `cat /proc/<pid>/wchan`. Fix: usually requires reboot (NFS hang, broken disk, kernel bug).

**Potential cross-domain relationship seeds (for P5):**

Edges to wire in Phase 5 (linux.primitives → other domains):

- `linux.primitives.cgroup-v2` ↔ `docker.engine.cgroup-v2` (same concept, docker side mentions container surfacing)
- `linux.primitives.cap-flag.*` ↔ `docker.engine.cmd.container-run` flag `--cap-add` / `--cap-drop`
- `linux.primitives.linux-namespace` ↔ `docker.engine.linux-namespace` (docker.engine has it as `primitive` kind row)
- `linux.primitives.cgroup-v2-control-file.memory.max` ↔ `docker.engine.cmd.container-run` flag `--memory`
- `linux.primitives.cgroup-v2-control-file.cpu.max` ↔ `docker.engine.cmd.container-run` flag `--cpus`
- `linux.primitives.cgroup-v2-control-file.pids.max` ↔ `docker.engine.cmd.container-run` flag `--pids-limit`
- `linux.primitives.seccomp-bpf-program` ↔ `docker.engine.cmd.container-run` flag `--security-opt seccomp=...`
- `linux.primitives.set-no-new-privs` ↔ `docker.engine.cmd.container-run` flag `--security-opt no-new-privileges`
- `linux.primitives.cgroup-v2` ↔ future `linux.systemd.cgroup-v2-integration`
- `linux.primitives.mount-namespace-propagation` ↔ future `linux.filesystem.mount-bind-rec`

**Source list adjustments made during execution:** none. The 33 primitives docs from session 1.1 + 1.5 were used as-is; no new primitives sources surfaced as gaps during P3.

**Next:** per the linux Phase 3 plan, next session is **`linux/networking` (Session 3.2)** — same per-leaf workflow, target 110 concepts / 32 commands / 220 config_keys. After: `linux/debugging` (3.3), `linux/systemd` (3.4), `linux/filesystem` (3.5).

## Cross-references

- Plan file (Phase 3): `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`
- Plan file (Phase 1): `~/.claude/plans/read-domains-shared-sessions-phase-1-so-sorted-shannon.md`
- Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`
- Pipe-able session prompts: `domains/_shared/sessions/phase-3-deep-extraction.md`, `phase-1-source-corpus.md`
- Sister-leaf precedent: `domains/docker/engine/PROGRESS.md` (90 / 16 / 217 = 323 rows)
- Methodology pilot precedent: `domains/methodology/{use-red-method,sre-debugging,visual-zines}/PROGRESS.md`
- Extraction artifacts: `domains/linux/primitives/extract/{concepts,commands,config_keys}.json`
