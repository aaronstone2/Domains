# Scenario 5 — "App is slow under load but CPU shows low"

**Difficulty:** advanced (counterintuitive metric, requires understanding "CPU% != work")
**Domains exercised:** linux, methodology
**Time-to-resolution target:** ≤ 8 minutes (this one earns extra time)

---

## User opening message

> Our service is slow under load. p99 latency went from 80 ms to 600 ms. But `top` shows the process at 35% CPU and the host has plenty of headroom. RED dashboard shows error rate is fine — just latency. Where do I look?

## SE mental model (10 seconds)

This is the **classic "CPU% lies"** scenario. Brendan Gregg has a whole essay on it (`brendangregg-cpu-utilization-wrong` — surfaces in our corpus). The signature is:

- High latency
- Low CPU%
- No errors

Three families of cause, in priority order to check:

1. **CPU is "busy" stalled, not doing work** (low IPC). Cycles tick by, instructions don't retire. Cause: memory bottleneck, cache thrashing, NUMA-remote access. `top` shows the cycles, doesn't know they're wasted.
2. **Off-CPU time** — the thread is blocked on something (lock, disk, network). `top` shows nothing because the thread isn't running.
3. **CFS bandwidth throttling** in a cgroup-limited workload (containers, k8s pods with `limits.cpu`). The kernel artificially halts the workload, latency spikes, CPU% looks low because it's, well, halted.

Diagnose in that order — fastest signal first.

## Harness queries

```text
$ pnpm harness lookup "cpu-utilization-misleading"
```

Top hit: `methodology.fm.cpu-utilization-misleading`. Brendan Gregg's `brendangregg-cpu-utilization-wrong` source also surfaces.

```text
$ pnpm harness playbook methodology.fm.cpu-utilization-misleading
```

Verified:

```
=== methodology.fm.cpu-utilization-misleading  [methodology] ===
Symptom: CPU utilization is high but app slow — but RED metrics show OK
(symptom phrasing is mirrored; same diagnostic applies to "CPU low + slow")

-- Diagnostic steps --
  1. Check actual instructions retired (vs cycles)
     perf stat -e cycles,instructions sleep 10
     expect: low IPC = stalled CPU not actually busy
  2. Check off-CPU time
     # off-CPU flame graph

-- Fix steps --
  1. Diagnose stalls
     perf-stat with stalled-cycles-{frontend,backend}
```

Related fms surface via `harness related methodology.use-method 2`:
- `linux.fm.cpu-throttled` — cgroup CFS throttling
- `linux.fm.iowait-high` — disk-bound, shows as low CPU
- `linux.fm.iostat-await-explained` — disk latency
- `methodology.off-cpu-flame-graph` — the blocked-time investigation method

## SE response (turn 1)

> "Slow but low CPU + no errors" is the canonical signature of three things; let's rule them out in order — fastest signal first.
>
> **Step 1 — is the CPU stalled or doing work?**
>
> ```
> sudo perf stat -p $(pgrep -f myapp) -- sleep 10
> ```
>
> Look at the `instructions` per `cycle` ratio (IPC). Healthy = >1.0; trouble = <0.5; very stalled = <0.2. If IPC is low, the CPU is "running" but waiting on memory/cache — fixing the workload, not adding cores, is the answer.
>
> **Step 2 — if IPC looks normal, check off-CPU time** (thread is blocked, not on CPU at all). The fastest way is BCC's `offcputime` or perf:
>
> ```
> sudo offcputime-bpfcc -p $(pgrep -f myapp) 30 > offcpu.txt
> # Or: sudo perf record -F 99 -e sched:sched_switch -p <pid> -- sleep 30
> ```
>
> Top stacks show what the threads are *waiting on*. Common offenders: lock contention (`futex_wait`), I/O (`io_schedule`, `nfs_*`), socket reads (`tcp_recvmsg`).
>
> **Step 3 — if neither: are you in a container with cgroup CPU limits?**
>
> ```
> cat /sys/fs/cgroup/cpu.stat
> # Look at: nr_throttled, throttled_usec
> ```
>
> Non-zero `nr_throttled` = the kernel is artificially halting your workload. Even at 35% utilization across the window, you can be at 100% during 100ms bursts and get throttled.
>
> Run those, paste the numbers back. Citations: [perf-stat(1)](https://man7.org/linux/man-pages/man1/perf-stat.1.html), [Brendan Gregg — CPU Utilization is Wrong](https://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-really-wrong.html).

## User reply (turn 2)

> ```
> $ sudo perf stat -p 12345 -- sleep 10
>            cycles                 12,234,000,000
>            instructions            1,891,000,000     # 0.155 insn per cycle
> $ cat /sys/fs/cgroup/cpu.stat
> nr_throttled 0
> $ # offcputime shows 80% of off-CPU time in futex_wait stacks
> ```

## SE mental model (turn 2)

Two confirmations:

- **IPC = 0.15** — extremely stalled. The CPU is mostly waiting (memory stalls, branch mispredicts, instruction cache misses).
- **80% off-CPU in futex_wait** — heavy lock contention. Threads are sleeping waiting for a mutex.

Both are the same root cause from different angles: contended lock → threads spin briefly waiting (looks like CPU) → then block in futex (looks like off-CPU). Latency spikes because every request waits in line.

## SE response (turn 2)

> Two strong signals, same root cause: **lock contention**.
>
> - IPC of 0.15 is way below what the workload should achieve. The CPU is "running" but mostly stalled — it's spinning briefly on the mutex's userspace fast path before falling into the kernel `futex` wait.
> - 80% off-CPU time in `futex_wait` confirms — your threads are queueing on a lock.
>
> **Find the lock**: get the actual stack trace, not just the kernel side:
>
> ```
> # Generate an off-CPU flame graph with userspace stacks
> sudo perf record -F 99 -e sched:sched_switch -g --call-graph dwarf -p $(pgrep -f myapp) -- sleep 30
> sudo perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl --color=io > offcpu.svg
> ```
>
> Open offcpu.svg. The widest column with `pthread_mutex_lock`/`futex_wait` at the bottom and your code on top tells you the exact lock. Then it's an application-code fix:
>
> 1. **Shrink the critical section** — the easiest 80% of these is "we hold the lock too long." Move expensive work outside.
> 2. **Switch to RWMutex** if many readers / few writers.
> 3. **Lock striping / sharding** — partition the data so different threads contend on different locks.
> 4. **Lock-free data structures** — last resort; high engineering cost.
>
> Validation: re-run `perf stat`, IPC should rise toward 1+; off-CPU time in futex should drop below 30%; p99 latency should fall.
>
> Citation: [Brendan Gregg — Off-CPU Analysis](https://www.brendangregg.com/offcpuanalysis.html), [Linux Performance Tools](https://www.brendangregg.com/linuxperf.html).

## Follow-up question (turn 3)

> What if perf stat had shown IPC of 1.5 (healthy) and offcputime had shown nothing big — just normal scheduler activity? Where else could the latency be?

## SE mental model (turn 3)

If we ruled out CPU-stall, off-CPU-blocking, and CFS-throttling, the slowness must be:
- **Downstream service slow** — your app is fine, the API it calls is slow. Latency-attribution requires distributed tracing (OpenTelemetry).
- **Network buffer-bloat / TCP retransmits** — network-level latency. Check `ss -ti`.
- **GC pauses** (Java/Go) — STW pauses don't show on CPU; show in app GC logs.
- **Connection-pool exhaustion** — every request waits for a free connection. Looks like off-CPU but very brief, hard to catch.

## SE response (turn 3)

> Once you've ruled out the three big ones, the remaining list is mostly **"latency is somewhere else"**. Order to check:
>
> 1. **Downstream calls** — instrument with OpenTelemetry / DataDog APM. The trace will show which span is fat. If your service makes 5 downstream calls and one is suddenly slow, that's the culprit.
> 2. **GC pauses** (managed runtimes) — check the app's GC log. Long pauses (>50 ms) show as latency spikes uncorrelated with CPU.
>    - Java: `-Xlog:gc*` or G1 logs
>    - Go: `GODEBUG=gctrace=1`
> 3. **TCP retransmits / SACK / buffer queueing**:
>    ```
>    ss -ti  # shows per-socket retransmits, RTT, cwnd
>    nstat -az | grep -i retrans
>    ```
>    Retransmits going up = network or remote-side issue.
> 4. **Connection-pool starvation** — measure pool waits. Most ORMs/HTTP-clients expose a "wait time" metric. If pool is at limit and grows queue, you're CPU-idle waiting for a connection.
> 5. **DNS** — sometimes the call out is slow because the DNS lookup is slow. We covered that in scenario 4.
>
> The methodology pattern here is **USE Method**: for each resource (CPU, mem, network, disk, locks, pools), check Utilization, Saturation, Errors. The fact that all three are low for the obvious resources means we look at *less obvious* resources (pool, network, GC).

---

## Coverage notes

- **CPU% as a misleading metric** is the single most-cited "trap" in performance analysis. The harness has a dedicated source (`brendangregg-cpu-utilization-wrong`) and fm.
- **3-step ladder** (IPC → off-CPU → throttle) is the canonical sequence. Each test is fast (~10s) and high-signal.
- **Lock contention manifests two ways simultaneously** — low IPC AND high futex off-CPU. SE recognized the pair.
- **Tools cited specifically**: `perf stat`, `offcputime-bpfcc`, `perf record --call-graph dwarf`, FlameGraph. All in the corpus.

## Practice notes for interviewer pushback

- "What's a 'good' IPC number to compare against?" → workload-dependent. >1.0 is healthy for most server apps; >2.0 is excellent (parallel, cache-friendly); <0.5 is suspicious; <0.2 is severely stalled. The number alone doesn't say what's wrong; combine with stalled-cycles breakdown: `perf stat -e cycles,instructions,stalled-cycles-frontend,stalled-cycles-backend`.
- "What if `nr_throttled > 0`?" → walk `pnpm harness playbook linux.fm.cpu-throttled`. Fix: raise the cgroup quota OR widen the period (longer window accommodates bursts).
- "BCC tools aren't installed on prod" → falls back to `perf record -e sched:sched_switch -g`. Slower to assemble, same data. Bcc-tools install is `apt install bpfcc-tools linux-headers-$(uname -r)`.
- "We can't run perf in prod" → install perf to a sidecar container with `SYS_ADMIN` capability + `/proc` and `/sys` mounts; profile a single replica during off-peak. Or use continuous-profiling vendors (Pyroscope, Polar Signals) that do this automatically.
- "Memory bandwidth is saturating — how do I confirm?" → `perf stat -e LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses` shows last-level cache miss rate. >10% is suspicious. NUMA-remote access bumps this. `numastat -p <pid>`.
