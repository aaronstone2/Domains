# Interview Cheat Sheet — AI Support Engineer

Single-page reference optimized for the interview screen-share. Designed to be open in a side window while you debug.

Backed by the corpus: 415 failure_modes, 1551 relationships, 7 domains. Every fm-id below resolves to `pnpm harness playbook <id>`.

---

## §1 Exit code decoder (read these first)

| Exit code | Decode | Common cause | Quick check |
|---:|---|---|---|
| `0` | success | — | — |
| `1` | generic failure | app-level | check stdout/stderr |
| `2` | usage / argv error | wrong flags or config parse fail | reproduce with `--help` |
| `125` | docker daemon error before container starts | bad image, daemon misconfig | `docker run --help` syntax; `journalctl -u docker` |
| `126` | command found, not executable | `chmod -x` issue, wrong arch | `file <binary>`; verify entrypoint perms |
| `127` | command not found | typo, missing dep, missing PATH | `which <cmd>` inside container |
| `128 + N` | killed by signal N (`128+9=137`, `128+11=139`, `128+15=143`) | see signals table below | `dmesg \| grep killed`; `docker inspect ... .State.OOMKilled` |
| `137` | **128 + SIGKILL(9)** — typically OOM | cgroup memory limit hit | `docker.fm.exit-137-oomkilled`, `k8s.fm.oomkilled` |
| `139` | **128 + SIGSEGV(11)** — segfault | bad memory access | `coredumpctl list`; `gdb -c <core>` |
| `143` | **128 + SIGTERM(15)** — graceful shutdown | normal `docker stop` / `kubectl delete` | usually fine; check `docker.fm.docker-stop-hangs-10s` if took 10s |

**Common signals (subtract 128 from exit code):**
| N | Signal | Meaning |
|---:|---|---|
| 1 | SIGHUP | hangup / reload config |
| 2 | SIGINT | Ctrl+C |
| 9 | SIGKILL | uncatchable kill — almost always OOM-killer (in container context) |
| 11 | SIGSEGV | invalid memory access |
| 13 | SIGPIPE | wrote to closed pipe |
| 15 | SIGTERM | polite stop (catchable) |

---

## §2 Symptom → fm-id (top 40 quick lookups)

**Container / Docker:**

| Symptom | fm-id |
|---|---|
| "exited with code 137" / OOMKilled | `docker.fm.exit-137-oomkilled` |
| can't `docker login` / "unauthorized" | `docker.fm.image-pull-private-registry-auth` |
| "toomanyrequests" rate limit | `docker.fm.image-pull-rate-limit` |
| `docker stop` hangs 10s | `docker.fm.docker-stop-hangs-10s` |
| zombies pile up in container | `docker.fm.zombie-processes-leaking` |
| can't reach internet from container | `docker.fm.container-no-egress-umbrella` |
| iptables flush broke port-forwarding | `docker.fm.iptables-docker-chain-flushed` |
| DNS not resolving inside container | `docker.fm.dns-not-resolving-from-container` |
| `/var/lib/docker` huge | `docker.fm.disk-full-overlay2-leaked` |
| DOCKER chain missing | `docker.fm.iptables-docker-chain-missing` |
| BuildKit cache mount collision | `docker.fm.buildkit-cache-mount-id-collision` |
| `--cap-drop` doesn't actually drop | `docker.fm.cap-not-actually-dropped` |
| Compose `depends_on` race | `docker.fm.compose-depends-on-wrong` |
| Compose secrets vs configs confusion | `docker.fm.compose-secrets-vs-configs` |
| container can ping IP but not hostname | `docker.fm.embedded-dns-misroute` |

**Linux (host):**

| Symptom | fm-id |
|---|---|
| process in D state, SIGKILL won't kill | `linux.fm.process-stuck-d-state` |
| OOM killed but free memory available | `linux.fm.cgroup-memory-oom-kill` |
| CPU low but app slow / throttled | `linux.fm.cpu-throttled` (then `methodology.fm.cpu-utilization-misleading`) |
| `df` shows free but writes fail ENOSPC | `linux.fm.disk-full-but-df-shows-free-space` |
| TCP TIME_WAIT exhaustion / EADDRNOTAVAIL | `linux.fm.tcp-time-wait-port-exhaustion` |
| connections refused under load | `linux.fm.tcp-listen-overflow` |
| conntrack table full | `linux.fm.conntrack-table-full` |
| systemd unit failed to start | `linux.fm.systemd-unit-restart-loop` |
| journal: "Suppressed N messages" | `linux.fm.journald-rate-limited` |
| "operation not permitted" but mode 777 | `linux.fm.lsm-double-restriction` |
| `bpftrace` "function not found" | `linux.fm.kprobe-attach-fails-inlined` |
| flame graph too flat | `linux.fm.flame-graph-flat` |
| inotify watches exhausted | `linux.fm.inotify-watch-limit` |
| RCU stall / soft lockup | `linux.fm.rcu-stall` / `linux.fm.soft-lockup` |
| NUMA imbalance | `linux.fm.numa-imbalance` |

**Kubernetes:**

| Symptom | fm-id |
|---|---|
| pod stuck Pending | `k8s.fm.pod-pending-failedscheduling` |
| FailedScheduling: untolerated taint | `k8s.fm.taint-toleration-mismatch` |
| OOMKilled in pod | `k8s.fm.oomkilled` |
| ImagePullBackOff | `k8s.fm.imagepullbackoff` |
| pod stuck Terminating | `k8s.fm.terminating-stuck` |
| pod stuck CrashLoopBackOff | `k8s.fm.crashloopbackoff` |
| Liveness killing slow-starter | `k8s.fm.liveness-killing-slow-starter` |
| ConfigMap edit not reaching pod | `k8s.fm.configmap-not-updating` |
| Pod can't resolve DNS | `k8s.fm.dns-resolution-fail` |
| DNS slow inside pods (3s lookups) | `k8s.fm.dns-pod-search-too-many` |
| NetworkPolicy blocking traffic | `k8s.fm.networkpolicy-blocking` |
| webhook "context deadline exceeded" | `k8s.fm.admission-webhook-timeout` |
| HPA "unknown" metric | `k8s.fm.hpa-not-scaling` |
| etcd "NOSPACE" | `k8s.fm.etcd-defrag-needed` |
| node NotReady, kubelet PLEG | `k8s.fm.kubelet-pleg-unhealthy` |
| kubectl wrong context | `k8s.fm.kubeconfig-context-wrong` |
| PVC stuck pending / resize stuck | `k8s.fm.pvc-pending` / `k8s.fm.pvc-resize-stuck` |
| `kubectl drain` stuck on PDB | `k8s.fm.pdb-blocks-drain` |
| service has no endpoints | `k8s.fm.service-no-endpoints` |

**Devin:**

| Symptom | fm-id |
|---|---|
| Devin can't reach internal staging | `devin.fm.session-cant-reach-internal-svc` (then VPN/proxy/cert) |
| Snapshot cold-boot slow first session | `devin.fm.snapshot-cold-boot-slow` |
| MCP tool timeout | `devin.fm.mcp-tool-timeout` |
| Slack/GitHub auth stale | `devin.fm.slack-integration-stale-token` / `devin.fm.github-app-perms-stale` |
| ACU runaway burn | `devin.fm.acu-burn-runaway` |
| Session paused with no ask | `devin.fm.session-stuck-paused-without-ask` |
| Devbox disk full | `devin.fm.devbox-disk-full` |
| Self-signed cert (internal Bitbucket etc.) | `devin.fm.internal-svc-cert-untrusted` |

**Methodology:**

| Symptom | fm-id |
|---|---|
| Postmortem turned into trial / blame | `methodology.fm.retro-becomes-trial` / `.postmortem-blame` |
| Alert fatigue / pager thrash | `methodology.fm.alert-fatigue` / `.pager-thrash-from-flap` |
| "Why didn't I notice?" — no baseline | `methodology.fm.no-baseline-cant-debug` |
| CPU% misleading | `methodology.fm.cpu-utilization-misleading` |
| Action items never done | `methodology.fm.action-items-never-done` |
| Wrong methodology applied (e.g. USE on req-throughput) | `methodology.fm.applied-wrong-method` |
| 5-whys terminates at "human error" | `methodology.fm.5whys-not-finding-root` |

---

## §3 Error message taxonomy (when you see X, look up Y)

| Verbatim error contains | Likely fm | Notes |
|---|---|---|
| `pull access denied for X, repository does not exist or may require docker login` | `docker.fm.image-pull-private-registry-auth` | docker's catch-all for 401 |
| `toomanyrequests: You have reached your pull rate limit` | `docker.fm.image-pull-rate-limit` | Docker Hub anonymous limit |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | `docker.fm.cannot-connect-daemon` | dockerd not running OR not in docker group |
| `OOMKilled: true` (in `docker inspect`) | `docker.fm.exit-137-oomkilled` | cgroup memory hit |
| `container init caused: rootfs_linux.go:N: ...` | `docker.fm.runc-bundle-mount-permission-denied` | usually rootless+AppArmor |
| `0/N nodes are available: K Insufficient memory` | `k8s.fm.pod-pending-failedscheduling` | scheduler couldn't fit |
| `had untolerated taint {KEY: VALUE}` | `k8s.fm.taint-toleration-mismatch` | add toleration |
| `admission webhook ... denied the request` | `k8s.fm.validating-webhook-policy-rejects` | policy (kyverno, gatekeeper) blocked |
| `webhook ... context deadline exceeded` | `k8s.fm.admission-webhook-timeout` | webhook took too long |
| `Cannot evict pod ... PodDisruptionBudget` | `k8s.fm.pdb-blocks-drain` | PDB tight; scale up or relax |
| `Failed to pull image ... no basic auth credentials` | `k8s.fm.imagepullbackoff` | imagePullSecret missing/stale |
| `Loop (127.0.0.1:53 -> :53)` | `k8s.fm.coredns-loop-detection` | CoreDNS forward loops |
| `nf_conntrack: table full, dropping packet` (dmesg) | `linux.fm.conntrack-table-full` | raise `nf_conntrack_max` |
| `TCPListenOverflows` (nstat) | `linux.fm.tcp-listen-overflow` | raise `somaxconn` + app backlog |
| `Killed process N (cmd)` (dmesg) | `linux.fm.cgroup-memory-oom-kill` | OOM-killer triggered |
| `start request repeated too quickly` | `linux.fm.systemd-unit-restart-loop` | StartLimitBurst exhausted; `reset-failed` |
| `Could not resolve host` | `devin.fm.session-cant-reach-internal-svc` (or `linux.fm.dns-slow-ndots` / k8s DNS chain) | DNS layer first |
| `self-signed certificate in certificate chain` | `devin.fm.internal-svc-cert-untrusted` | corp CA missing from trust store |
| `bash: line 1: container: No such file or directory` | (literal substitution issue) | playbook had `<container>` placeholder; substitute the real ID |

---

## §4 Five-second mental models

**"It's slow."** → 3 ladder, fastest first: (1) IPC (`perf stat`) → low? CPU stalled. (2) Off-CPU time → futex/io? Lock or block. (3) cgroup `cpu.stat` → throttled? CFS. If all clean → look downstream (tracing).

**"It's slow but the metric says fine."** → percentile bucketing too coarse. `histogram_quantile` lies if buckets stop at 50ms. Add fine-grained buckets in tail (`{0.1, 0.5, 1, 2, 5, 10}`).

**"Container exited 137."** → `128+SIGKILL(9)`. Check `OOMKilled` field → cgroup memory limit. Java? RSS = heap + metaspace + JIT + threads + GC.

**"Process won't die."** → D state. `/proc/<pid>/stack`; `/proc/<pid>/wchan`. `nfs_wait_*` = NFS hang (`umount -fl`). `io_schedule` = block-device hang (smartctl + dmesg).

**"Pod stuck Pending."** → `kubectl describe pod | tail -30`. Events section names the reason verbatim. Map: `Insufficient` / `untolerated taint` / `node affinity` / `unbound PVC` / `free ports` / (no events = scheduler gone OR webhook dead OR quota full).

**"Container can't reach internet."** → 5-layer probe one-liner: `ping 127; ip route; ping <gw>; ping 8.8.8.8; getent hosts X`. First fail = the layer. L4 fail + L3 ok → `ip_forward=0` OR MASQUERADE missing OR firewall.

**"DNS slow inside pod ~3s."** → `ndots:5` + search-amplification. `time getent hosts api.x.com` vs `time getent hosts api.x.com.` (trailing dot). Fix: `dnsConfig.options ndots:2`.

**"systemd unit failed."** → `systemctl status` (summary), `journalctl -u <unit> -e` (real error). Status codes: 203=binary missing, 200=user missing, start-limit-hit=exhausted (need `reset-failed`).

**"Devin can't reach our staging."** → `Could not resolve host` = DNS, not TCP. Need: VPN config, internal DNS push, corp CA. `devin-docs-onboard-vpn` is the canonical setup.

**"Postmortem turned into blame."** → 3 loops: (1) private 1:1 — own the *process* failure not their failure; (2) rewrite doc with *roles* not names, *contributing factors* not "the cause"; (3) adopt blameless template (Google SRE Ch 15) + tracked AIs.

---

## §5 Tools by domain (top 20 — all that's worth memorizing)

**Docker (CLI):**
```
docker inspect <c> --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
docker inspect <c> --format '{{.HostConfig.Memory}}'
docker stats <c>
docker logs --tail 100 -f <c>
docker exec -it <c> sh
docker system df
docker network inspect <net> | jq '.[].IPAM.Config'
docker events --since 5m
```

**Kubectl (top 15):**
```
kubectl describe pod <p> | tail -30                       # Events at bottom
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl logs <p> --previous --tail 100                    # last failed run
kubectl exec -it <p> -- sh
kubectl debug <p> --image=nicolaka/netshoot               # ephemeral container, k8s 1.25+
kubectl describe nodes | grep -E 'Name:|Allocated' -A 5
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl get pods -A --field-selector=status.phase=Pending
kubectl rollout status deploy/<name>
kubectl rollout undo deploy/<name>
kubectl get pdb -A
kubectl get networkpolicy -A
kubectl top pods --containers
kubectl auth can-i <verb> <resource> --as=<sa>
kubectl config current-context                            # ALWAYS verify cluster!
```

**Linux performance (Brendan Gregg-flavored):**
```
top / htop                           # quick CPU/mem snapshot
vmstat 1 10                          # cs, blocked, swap, run-queue
iostat -xz 1 10                      # await/svctm per device
sar -n DEV 1 5                       # network throughput per iface
mpstat -P ALL 1 5                    # per-CPU breakdown
ss -tnp                              # TCP sockets w/ pid
nstat -az | grep -E 'TcpExt|IpExt'   # TCP error counters
ip -s link / ip route show
sudo perf stat -p <pid> -- sleep 10  # IPC; run-time counters
sudo perf record -F 99 -g --call-graph dwarf -p <pid> -- sleep 30
sudo offcputime-bpfcc -p <pid> 30    # off-CPU stacks
sudo execsnoop-bpfcc                 # what's spawning?
sudo opensnoop-bpfcc                 # what files are being opened?
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat /pid==P/ {@[args->filename]=count();}'
strace -ff -e trace=openat,read,write -p <pid>   # syscall trace
ltrace -p <pid>                      # library calls
```

**Linux /proc + /sys (inspect kernel state):**
```
cat /proc/<pid>/stack                # kernel call stack (D-state debugging)
cat /proc/<pid>/wchan                # kernel function blocking
cat /proc/<pid>/status | grep -E 'State|VmRSS|Cap'
cat /proc/loadavg /proc/meminfo /proc/cpuinfo
cat /proc/interrupts                 # IRQ distribution per CPU
cat /proc/pressure/{cpu,io,memory}   # PSI
cat /sys/fs/cgroup/<cg>/memory.events
cat /sys/fs/cgroup/<cg>/cpu.stat     # nr_throttled, throttled_usec
cat /sys/fs/cgroup/<cg>/memory.{current,max}
```

**systemd:**
```
systemctl status <unit>                   # summary + last 10 journal lines
journalctl -u <unit> -e                   # full unit log, end first
journalctl -u <unit> -f --since "5 min ago"
systemctl reset-failed <unit>             # clear start-limit counter
systemd-analyze verify <unit>             # syntax check
systemd-analyze blame                     # boot time per unit
coredumpctl list                          # captured core dumps
```

**Networking:**
```
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQ    # is MASQUERADE there?
sudo iptables -L FORWARD -n -v --line-numbers
sudo iptables -L DOCKER-USER -n -v
sudo nft list ruleset                                    # nftables
sudo conntrack -L | head                                 # active connections
ss -ant | awk '{print $1}' | sort | uniq -c              # TCP state distribution
sudo tcpdump -i any -c 50 -nn 'host X.X.X.X'
dig +trace example.com
```

**Container runtime (containerd/runc):**
```
sudo crictl ps --no-trunc
sudo crictl logs <cid>
sudo runc list
sudo runc state <id>
sudo ctr -n moby tasks ls
sudo ctr -n k8s.io images ls
```

---

## §6 Methodology cheats

**USE Method** (for every resource: CPU, mem, disk, net, schedulers, locks, pools):
- **U**tilization: % time busy
- **S**aturation: queueing depth / wait time
- **E**rrors: error counts
For each resource, ask all three. The first one you find with non-zero saturation OR errors is your bottleneck.

**RED Method** (for every service):
- **R**ate (req/sec)
- **E**rrors (err/sec or % rate)
- **D**uration (latency distribution)

**Four Golden Signals** (Google SRE):
- Latency
- Traffic
- Errors
- Saturation

**Off-CPU Analysis**: when on-CPU profiling shows nothing → the work is *waiting*, not running. `offcputime-bpfcc` or `perf record -e sched:sched_switch -g`.

**Blameless postmortem (Google SRE Ch 15) — the 4 framing rules:**
1. Use **roles** not **names** ("the deploy engineer", not "Sarah")
2. Reframe "X forgot to" → "the process didn't catch"
3. List **contributing factors**, not "the cause"
4. Action items must be **system-level** (add validation, shorten canary), not "be more careful"

**5-whys not terminating at human error**: "human error" is a *symptom*. Next why: "why was a human in a position to fail?" → automation gap, training gap, safeguard gap.

**Latency vs throughput**: don't conflate. p99 latency can blow up while average throughput stays flat (lock contention, GC pause).

**Active vs passive benchmarking**: passive = run load gen, look at output. Active = instrument BOTH load gen AND SUT, verify load is what you think (USE on the SUT during the test).

---

## §7 Harness commands quick-reference

```bash
# Search the corpus
pnpm harness lookup "exit 137 OOM"               # BM25 + LIKE across docs/concepts/cmds/fms
pnpm harness lookup "DNS slow ndots"

# Render a failure-mode runbook
pnpm harness playbook docker.fm.exit-137-oomkilled
pnpm harness playbook k8s.fm.pod-pending-failedscheduling

# Look up a concept + its relationships
pnpm harness concept linux.primitives.cgroup-v2

# Walk the relationship graph (depth N, max 4)
pnpm harness related linux.primitives.oom-killer 2

# Citation lookup
pnpm harness cite kernel-docs-cgroup-v2

# Corpus stats
pnpm harness stats

# Run a curated diagnostic bundle (8 available)
pnpm harness capture --list
pnpm harness capture oom                          # bundle: oom kills + cgroup state
pnpm harness capture network-egress               # bundle: layer probe + iptables
pnpm harness capture --from-fm docker.fm.exit-137-oomkilled
pnpm harness capture <bundle> --output snap.md

# Practice mode (10 drills)
pnpm harness drill --list
pnpm harness drill 01-docker-oom
pnpm harness drill random
```

**One-line response patterns** (when user describes X, run Y):

| User says... | First command |
|---|---|
| "container exited 137" | `pnpm harness playbook docker.fm.exit-137-oomkilled` |
| "pod stuck Pending" | `pnpm harness playbook k8s.fm.pod-pending-failedscheduling` |
| "DNS slow inside pods" | `pnpm harness playbook k8s.fm.dns-pod-search-too-many` |
| "container can't reach internet" | `pnpm harness playbook docker.fm.container-no-egress-umbrella` |
| "process stuck, SIGKILL doesn't work" | `pnpm harness playbook linux.fm.process-stuck-d-state` |
| "systemd unit won't start" | `pnpm harness playbook linux.fm.systemd-unit-restart-loop` |
| "kubectl drain hangs on PDB" | `pnpm harness playbook k8s.fm.pdb-blocks-drain` |
| "admission webhook denied / timed out" | `pnpm harness playbook k8s.fm.validating-webhook-policy-rejects` |
| "Devin can't reach internal" | `pnpm harness playbook devin.fm.session-cant-reach-internal-svc` |
| "I'm slow but CPU is low" | `pnpm harness playbook methodology.fm.cpu-utilization-misleading` |
| "Postmortem became blame" | `pnpm harness playbook methodology.fm.retro-becomes-trial` |
| (vague symptom) | `pnpm harness lookup "<their words>"` then pick from the failure_modes section |

---

## §8 Corpus quick-stats (so you know what's in the harness)

| Domain | sources | concepts | commands | config_keys | failure_modes | relationships |
|---|---:|---:|---:|---:|---:|---:|
| docker | 104 | 400 | 58 | 869 | 74 | 333 |
| linux | 172 | 521 | 65 | 1125 | 91 | 315 |
| k8s | 62 | 274 | 45 | 359 | 64 | 268 |
| devin | 327 | 319 | 338 | 357 | 37 | 150 |
| methodology | 44 | 121 | 50 | 36 | 28 | 115 |
| firecracker | 37 | 172 | 130 | 119 | 71 | 236 |
| ecs | 21 | 82 | 20 | 154 | 50 | 134 |
| **Total** | **767** | **1889** | **706** | **3019** | **415** | **1551** |

10 deep multi-turn rehearsal scenarios at `domains/_shared/rehearsal/scenarios/`, drillable via `pnpm harness drill <id>`.

---

## §9 The 30-second interview opener (what to do before they finish describing)

1. **Listen for the keyword.** OOM, Pending, NXDOMAIN, "can't reach", "stuck", "slow but CPU low" — each maps to a fm.
2. **Don't fix yet.** Confirm with the cheapest diagnostic first. Examples: `docker inspect ... .State.OOMKilled`, `kubectl describe pod`, `cat /etc/resolv.conf`.
3. **Cite a doc URL** with every recommendation. This is what differentiates "fixing" from "Support Engineering."
4. **Ask one clarifying question per turn.** Never overload the user with 5 commands at once. One probe → result → one recommendation.
5. **End each turn with "and how can I check this worked?"** Validation step is what separates a complete fix from "tried something."
6. **For soft-skills questions** (postmortem, blame, on-call burnout): don't pretend you don't have an opinion. `methodology` domain has playbooks for these too.

---

_Last refreshed against corpus snapshot 2026-05-03. Regenerate counts with `pnpm harness stats`._
