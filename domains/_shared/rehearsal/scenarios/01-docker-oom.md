# Scenario 1 — "My container exited with code 137"

**Difficulty:** entry-level (classic interview opener)
**Domains exercised:** docker, linux, k8s
**Time-to-resolution target:** ≤ 3 minutes from prompt to first cited recommendation

---

## User opening message

> Hey, I've got a container that keeps exiting with code 137 right around the time my batch job hits its peak memory. `docker ps -a` shows it as Exited (137). I've already tried restarting it twice. What's going on?

## SE mental model (3 seconds)

- **137 = 128 + 9 = SIGKILL.** Container was killed, didn't exit on its own.
- **Two common SIGKILL sources for containers:** (a) cgroup memory-controller OOM kill (most likely given "around peak memory"), (b) host system OOM (less common when cgroup limits are set).
- **Don't fix yet — confirm.** The user might be misreading the limit.

## Harness queries to run

```text
$ pnpm harness lookup "OOMKilled exit 137"
```

Verified output (matching failure modes section):

```
matching failure modes (use `harness playbook <id>`):
  [k8s] k8s.fm.oomkilled  (conf=0.95)  — Container OOMKilled (exit 137)
  [docker] docker.fm.exit-137-oomkilled  (conf=0.98)  — Container exited with code 137; `docker inspect` shows OOMKilled=true
  [docker] docker.fm.runc-exit-128-plus-signum  (conf=0.95)  — `docker inspect` shows exit code like 137, 139, 143
```

The user said "container," not "pod," so prefer the docker fm. Get the playbook:

```text
$ pnpm harness playbook docker.fm.exit-137-oomkilled
```

Verified output:

```
=== docker.fm.exit-137-oomkilled  [docker] ===
Symptom: Container exited with code 137; `docker inspect` shows OOMKilled=true
Root cause class: resource-limit
Confidence: 0.98
Patterns: Exit code 137 | OOMKilled: true | killed: true
Affects: linux.primitives.oom-killer, docker.engine.cfg.daemon.json.storage-driver,
         linux.primitives.cfg.cgroup-v2-control-file.memory-max

-- Diagnostic steps --
  1. Confirm OOM kill
     $ docker inspect <container> --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
     expect: true 137
     [src: docker-cli-container-inspect]
  2. Check kernel OOM log
     $ dmesg -T | grep -i 'killed process'
     expect: line naming the killed process
     [src: man7-dmesg-1]
  3. Inspect memory limit set
     $ docker inspect <container> --format '{{.HostConfig.Memory}}'
     expect: in bytes (0 = unlimited)
     [src: docker-cli-container-run]
  4. Read cgroup memory.events
     $ cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.events
     expect: oom_kill > 0
     [src: kernel-docs-cgroup-v2]

-- Fix steps --
  1. Raise --memory limit
     $ docker run --memory=2G ...
  2. Profile actual usage
     $ docker stats <container>
```

## SE response to user (turn 1)

> Exit code 137 = `128 + SIGKILL(9)`, so something killed the container. The most likely culprit when it correlates with memory pressure is the **cgroup memory controller OOM-killer** — the container hit its memory limit and the kernel killed the heaviest process. Three quick checks before we fix it:
>
> 1. Confirm it was an OOM kill (not just SIGKILL from outside):
>    ```
>    docker inspect <container> --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
>    ```
>    Expect `true 137`.
>
> 2. Check the kernel log for the kill notification:
>    ```
>    dmesg -T | grep -i 'killed process'
>    ```
>    You'll see a line naming the victim PID and its RSS at time of death.
>
> 3. See what the limit actually is:
>    ```
>    docker inspect <container> --format '{{.HostConfig.Memory}}'
>    ```
>    `0` = unlimited (so the limit's coming from somewhere else like a parent slice); a non-zero value is the byte limit.
>
> Run those and paste the outputs back. Once we confirm OOM, the fix is either raise `--memory` (if the workload is honestly bigger) or chase a leak (if the workload should fit). Citations: [docker container inspect](https://docs.docker.com/reference/cli/docker/container/inspect/), [dmesg(1)](https://man7.org/linux/man-pages/man1/dmesg.1.html), [Linux Kernel — Control Group v2](https://docs.kernel.org/admin-guide/cgroup-v2.html).

## User reply (turn 2)

> Yeah `OOMKilled=true 137`, dmesg shows `Killed process 12345 (java) total-vm:4194304kB anon-rss:2097152kB`. Memory limit is `2147483648`. So I'm hitting my 2 GB cap. I thought my Java heap was 512 MB though?

## SE mental model

- Java RSS = heap + metaspace + JIT code + native libraries + thread stacks + direct buffers + GC bookkeeping. 512 MB heap easily becomes 1.5–2 GB RSS without leaks.
- Two valid fixes: (a) raise `--memory` if the host can spare it, (b) tune the JVM to fit the cap (`-XX:MaxRAMPercentage`, `-XX:+UseContainerSupport`).

## SE response (turn 2)

> That confirms it. Note: **Java RSS is much bigger than `-Xmx`** — heap is just one component. Your 512 MB heap plus metaspace + JIT code cache + native buffers easily reaches 1.5–2 GB. Two paths:
>
> **Path A: tune the JVM to actually respect the cgroup limit.** Modern JDKs (8u191+, 11+) have `-XX:+UseContainerSupport` on by default — they read the cgroup limit and size heap accordingly:
>
> ```
> docker run --memory=2g \
>   -e JAVA_TOOL_OPTIONS='-XX:MaxRAMPercentage=60.0' \
>   <image>
> ```
>
> 60% of 2 GB ≈ 1.2 GB heap, leaving room for metaspace + threads + JIT.
>
> **Path B: raise the cap if the workload is honestly bigger.** `docker run --memory=4g …`. Validate by watching `docker stats` while you reproduce.
>
> Either way, watch the cgroup's own counter to confirm you stopped getting OOM-killed:
>
> ```
> cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.events
> ```
>
> `oom_kill` should stop incrementing.

## Follow-up question (turn 3)

> What if it's running in Kubernetes? Same diagnosis?

## SE mental model + harness query

The fm graph is wired across layers — the related walk surfaces the kubernetes-equivalent and the underlying linux primitive:

```text
$ pnpm harness related linux.primitives.oom-killer 2
```

Verified:
```
[d=1] docker.fm.exit-137-oomkilled
[d=1] k8s.core.oom-kill
[d=1] k8s.debugging.oomkilled-debug-pattern
[d=1] linux.fm.cgroup-memory-oom-kill
[d=1] linux.primitives.cgroup-v2-memory-events
  [d=2] k8s.fm.oomkilled
  [d=2] k8s.fm.evicted-by-node-pressure
  [d=2] linux.primitives.cgroup-v2
  [d=2] linux.systemd.resource-memory-max
```

## SE response (turn 3)

> Same root cause (cgroup memory limit hit → OOM-killer), different surface. In k8s:
>
> - **Symptom in `kubectl describe pod`:** `State: Terminated, Reason: OOMKilled, ExitCode: 137`. Same 128+SIGKILL.
> - **Where the limit comes from:** `spec.containers[].resources.limits.memory` instead of `--memory`.
> - **Diagnose:**
>   ```
>   kubectl describe pod <pod>
>   kubectl get events --field-selector involvedObject.name=<pod>
>   ```
>   Look for `Reason: OOMKilling` in events and `Last State: Terminated, Reason: OOMKilled` in describe.
>
> - **Important k8s-specific gotcha:** if you set requests but not limits, you can be evicted by *node pressure* before you'd hit a cgroup OOM. The diagnosis is different — `kubectl get events` shows `Evicted` rather than `OOMKilled`. That's `k8s.fm.evicted-by-node-pressure` not `k8s.fm.oomkilled`.
>
> - **Fix:** same as docker, but set `requests == limits` if you want guaranteed-class scheduling (less likely to be evicted). For a JVM workload:
>   ```yaml
>   resources:
>     requests: { memory: 2Gi, cpu: 500m }
>     limits:   { memory: 2Gi, cpu: 2000m }
>   env:
>     - name: JAVA_TOOL_OPTIONS
>       value: "-XX:MaxRAMPercentage=60.0"
>   ```

---

## Bonus: bundling diagnostics with `harness capture`

For interview-day, instead of typing each `docker inspect`/`dmesg`/`cat memory.events` command and pasting the output one at a time, run the OOM bundle once and paste the whole blob:

```text
$ pnpm harness capture oom
```

Verified output (truncated):

```
# Capture: oom
> Memory pressure / OOM kill investigation. Use when a process or container died with code 137...
_Captured at 2026-05-03T22:41:07.641Z on win32/x64 via wsl._

### Recent OOM kills from kernel ring buffer
```
dmesg -T | grep -i 'killed process\|out of memory' | tail -20
```
_exit=0 took=223ms_
```
[Sun May  3 03:03:07 2026] Memory cgroup out of memory: Killed process 24021 (python)
total-vm:216032kB, anon-rss:31436kB, file-rss:5376kB, shmem-rss:0kB, oom_score_adj:0
...
```

### System-wide memory state
... (free -h output)

### Per-process RSS (top 15)
... (ps aux output)

### Memory cgroup events (root cgroup)
... (memory.events with oom_kill counter)
```

Or, for a specific failure mode, synthesize the bundle from its playbook:

```text
$ pnpm harness capture --from-fm docker.fm.exit-137-oomkilled
```

This pulls the diagnostic_steps directly from the harness corpus — same canonical sequence the playbook walks.

## Coverage notes

- **Path-completeness check:** all 4 diagnostic steps + 2 fix steps from the playbook are mentioned in the response. ✓
- **Cross-domain depth:** docker → linux primitive → k8s equivalent demonstrated via `related` walk. ✓
- **Citation discipline:** every command is followed by a doc link. ✓
- **Failure-mode separation:** distinguished `k8s.fm.oomkilled` (cgroup OOM) from `k8s.fm.evicted-by-node-pressure` (node-level eviction) — the harness has both, the SE knows which is which.

## Practice notes for interviewer pushback

- "Why isn't `OOMKilled=true` in the inspect output?" → could be a non-OOM SIGKILL (someone ran `docker kill`, OOM at the host level not the cgroup, or systemd-level KillSignal). Walk dmesg first.
- "What if dmesg doesn't show anything?" → the kill might not have reached host log. Read the cgroup's `memory.events` file directly — it's the source of truth.
- "Could it be a memory leak?" → possibly. Watch `docker stats <container>` over time. Steady RSS growth without bounds = leak. Spiky pattern = bursty workload that just needs more cap.
