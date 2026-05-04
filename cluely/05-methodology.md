# 05 — Methodology condensed

> When you don't know which fm to query, fall back to a framework. These are the ones the SRE/perf community uses.

## USE Method (Brendan Gregg) — for resources

For each resource (CPU, memory, disk I/O, network, schedulers, locks, pools), check three things in order:

| | What to measure | What you're looking for |
|---|---|---|
| **U**tilization | % time the resource is busy | high → potential bottleneck |
| **S**aturation | queue depth / wait time | non-zero → bottleneck NOW |
| **E**rrors | error count | non-zero → look here first |

**The rule:** the FIRST resource you check with non-zero saturation OR errors is your bottleneck.

Per-resource USE recipes:

| Resource | U | S | E |
|---|---|---|---|
| CPU | `vmstat 1` (us+sy+st) | `vmstat 1` (r column) | `dmesg` |
| Memory | `free -h` (used) | `vmstat 1` (si+so swap) | `dmesg` (OOM) |
| Disk I/O | `iostat -xz 1` (%util) | `iostat -xz 1` (avgqu-sz) | `iostat -xz 1` (errors) |
| Network | `ifconfig` / `ip -s link` | `nstat` (TcpRetransSegs) | `ip -s link` (errors) |

## RED Method (Tom Wilkie) — for services

For each service: **R**ate (req/s), **E**rrors (err/s or %), **D**uration (latency distribution).

If you don't have these as metrics already, you don't know if your service is healthy. **Always ask** for these as part of your clarifying questions.

## 4 Golden Signals (Google SRE Book, Ch. 6)

Latency · Traffic · Errors · Saturation. Same idea as RED + saturation. Use whichever framework the team already knows.

## Off-CPU analysis

When on-CPU profiling shows nothing, the work is *waiting*, not *running*. Tools:
- `perf record -e sched:sched_switch -g -- sleep 5` (kernel)
- `offcputime-bpfcc -p <pid> 5` (BPF)
- `strace -c -p <pid>` (syscall summary)

If 95% of time is in `futex_wait` → lock contention. In `read` on a socket → upstream is slow. In `read` on disk → I/O saturated.

## Latency vs throughput (don't conflate)

p99 latency can blow up while average throughput stays flat. This is the signature of:
- lock contention (single hot path serializes traffic)
- GC pause (Java/Go stop-the-world)
- TCP head-of-line blocking
- one slow upstream in a fan-out

Always show p50/p95/p99, not just average.

## Active vs passive benchmarking

- **Passive**: run load gen, look at output. Tells you "what does it do?"
- **Active**: instrument BOTH load gen AND SUT, verify load is what you think (USE on the SUT during the test). Catches "the load gen isn't actually generating load" bugs.

## Postmortem framing (Google SRE Ch. 15) — the 4 rules for blameless

Soft-skills questions often probe this. Memorize:

1. Use **roles** not **names** ("the deploy engineer", not "Sarah").
2. Reframe "X forgot to" → "the process didn't catch".
3. List **contributing factors**, not "the cause".
4. Action items must be **system-level** (validation, canary, automation), not "be more careful".

## 5-whys, with the human-error guard

"Human error" is a *symptom*, not a root cause. Next why: "**why was a human in a position to fail?**" → automation gap, training gap, safeguard gap. THAT'S the actionable answer.

## When to escalate

The job description specifies escalation paths to "deployed engineering, field IT, or enterprise engineering." Escalate when:

- Customer issue is reproducible but root cause is in product code (not config / usage)
- A diagnostic requires platform access you don't have
- Fix would require a code change
- Same issue from multiple customers in a window (fleet-level)

Escalation isn't failure — escalating early with good notes is the right SE behavior. Always include: reproduction steps, what you tried, what you ruled out, current hypothesis, customer impact level.

## Cross-references

- Talk-track scripts that use these frames: [06-talk-tracks.md](06-talk-tracks.md)
- Anti-patterns to avoid when applying these: [07-anti-patterns.md](07-anti-patterns.md)
- Soft-skills failure modes (postmortem-becomes-trial, etc.): [03](03-top-failure-modes.md) — search for "methodology."
