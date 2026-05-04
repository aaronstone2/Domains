# 01 — Cheat sheet (single-page reference)

> Open this when you need the answer in <5 seconds. Drill into [03](03-top-failure-modes.md) for full playbooks.

## Exit code decoder

| Code | Meaning | First check |
|---:|---|---|
| `0` | success | — |
| `1` | generic failure | stdout/stderr |
| `2` | usage / argv | `--help` parse |
| `125` | docker daemon error pre-start | bad image / daemon misconfig |
| `126` | command not executable | perms, wrong arch |
| `127` | command not found | typo, missing dep |
| `137` | **128 + SIGKILL** — usually OOM | `docker inspect ... .State.OOMKilled` |
| `139` | **128 + SIGSEGV** — segfault | `coredumpctl list` |
| `143` | **128 + SIGTERM** — graceful stop | usually normal |

`128 + N` = killed by signal N.

## Signal cheatsheet

| N | Signal | Catchable? | Why |
|---:|---|---|---|
| 1 | HUP | yes | reload config |
| 2 | INT | yes | Ctrl+C |
| 9 | KILL | **NO** | OOM-killer or `kill -9` |
| 11 | SEGV | yes (rarely useful) | invalid memory access |
| 13 | PIPE | yes | wrote to closed pipe |
| 15 | TERM | yes | polite stop |

## Harness shortcuts

```bash
ha "<symptom>"      # one-shot: top fm + talk-track + diag/fix + citations
hl "<query>"        # browse: top 8 fms + commands + concepts + docs
hp <fm-id>          # render specific failure mode
hd <drill-id>       # interactive practice REPL
hcap <bundle>       # capture diagnostic snapshot
hs                  # corpus stats
cheat               # open this file in $PAGER
```

`ha` is the **default**. Use it 80% of the time. See [02](02-symptom-to-fm.md) for symptom → ha-query mapping.

## Symptom → first command

| User says... | First call |
|---|---|
| exit 137 / OOMKilled | `ha "OOMKilled in container"` |
| pod stuck Pending | `ha "pod stuck Pending"` |
| DNS slow inside pods | `ha "DNS slow ndots"` |
| can't reach internet from container | `ha "container no egress"` |
| process won't die / `kill -9` no help | `ha "kill -9 stuck process"` |
| systemd unit won't start | `ha "systemd unit restart loop"` |
| `kubectl drain` hangs on PDB | `ha "drain hangs PDB"` |
| webhook denied / timed out | `ha "admission webhook"` |
| Devin can't reach internal | `ha "devin internal service"` |
| postmortem became blame | `ha "postmortem blame"` |
| (vague) | `hl "<their words>"` then pick |

Full table: [02-symptom-to-fm.md](02-symptom-to-fm.md).

## The 30-second opener

1. **Listen for the keyword.** OOM, Pending, NXDOMAIN, "can't reach", "stuck", "slow but CPU low" — each maps to a fm.
2. **Don't fix yet.** Confirm with the cheapest diagnostic first.
3. **Cite a URL** with every recommendation.
4. **One clarifying question per turn** — never 5 commands at once.
5. **End each turn with "and how can I check this worked?"** Validation step is what separates "tried something" from "fixed it".

Talk-track verbatim scripts: [06-talk-tracks.md](06-talk-tracks.md).

## Methodology one-liners

- **USE** = Utilization, Saturation, Errors. Per resource (CPU/mem/disk/net). First non-zero saturation/error = bottleneck.
- **RED** = Rate, Errors, Duration. Per service.
- **4 Golden Signals** = Latency, Traffic, Errors, Saturation.
- **Off-CPU**: when on-CPU shows nothing, the work is *waiting*. Use `offcputime-bpfcc` or `perf record -e sched:sched_switch -g`.

Full methodology: [05-methodology.md](05-methodology.md).

## Anti-patterns (do not)

- ❌ Run a `fix_steps` action without first running matching `diagnostic_steps`
- ❌ Dump 5 commands into the shell at once
- ❌ Apologize for using a tool — external tools are explicitly allowed
- ❌ Disable security controls (`setenforce 0`, `--security-opt apparmor=unconfined`) as a "fix"
- ❌ Use `--insecure` / `-k` to bypass cert validation; that's diagnostic-only

Full list: [07-anti-patterns.md](07-anti-patterns.md).

## Corpus inventory

| Domain | sources | concepts | fms |
|---|---:|---:|---:|
| docker | 104 | 400 | 74 |
| linux | 172 | 521 | 91 |
| k8s | 62 | 274 | 64 |
| devin | 327 | 319 | 37 |
| methodology | 44 | 121 | 28 |
| firecracker | 37 | 172 | 71 |
| ecs | 21 | 82 | 50 |
| **TOTAL** | **767** | **1889** | **415** |

All 415 fms have ≥3 diagnostic steps + ≥2 fix steps with concrete commands.
