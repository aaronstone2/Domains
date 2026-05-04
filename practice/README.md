# Practice scenarios — real broken-system simulators

Each script in this directory creates an actual broken state on the local Linux box (or in a container) so you can practice debugging with `claude` + the harness against real symptoms instead of narrative prompts.

## Usage pattern

```bash
./practice/01-disk-pressure.sh start    # break something
# ... debug it with `ha "<symptom>"`, claude, etc. Time yourself.
./practice/01-disk-pressure.sh restore  # undo
```

## Workflow

1. Open two terminals: one running `claude` in the repo root, one for free-form shell.
2. Pick a scenario — don't read its hints/answers section first.
3. Run `./practice/<NN>-<name>.sh start`. Read the printed scenario description.
4. **Time yourself.** Use the harness to find the failure mode. Use `claude` to walk through diagnostic + fix steps.
5. When you think you're done, run the script's `verify` arg to confirm you actually fixed it.
6. Run `restore` to clean up. Move to the next scenario.
7. Compare your time + approach against the script's `--reveal` notes.

## Scenarios

### Single-process debugging (01–08)

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 01 | `01-disk-pressure.sh` | Filesystem / disk-full debugging | nothing |
| 02 | `02-hung-process.sh` | Process stuck on I/O (D-state-like) | nothing |
| 03 | `03-memory-pressure.sh` | OOM-killer / memory-pressure investigation | nothing |
| 04 | `04-bad-systemd-unit.sh` | systemd unit failed to start | systemctl --user OR sudo |
| 05 | `05-port-collision.sh` | Service can't bind: port already in use | nothing |
| 06 | `06-docker-oom.sh` | Container exit 137 / OOMKilled | docker |
| 07 | `07-docker-no-egress.sh` | Container can't reach internet | docker |
| 08 | `08-bad-resolv.sh` | DNS lookups failing inside container | docker |

### Fleet-scale debugging (09–12) — find the outlier across N containers

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 09 | `09-fleet-oom.sh` | 1 of 10 containers OOMing — find via `docker inspect` aggregation, not 1-by-1 | docker |
| 10 | `10-agents-flapping.sh` | 1 of 8 agents in deterministic crash loop, others have transient restarts — RestartCount + events aggregation | docker |
| 11 | `11-noisy-neighbor.sh` | 1 of 6 containers filling disk via runaway logs — per-container LogPath size aggregation | docker |
| 12 | `12-version-skew.sh` | Partial deploy: 1 of 6 backends on wrong image tag, intermittent failures — `inspect.Config.Image` group-by | docker |

### Process-table debugging (13)

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 13 | `13-zombie-processes.sh` | Container's PID 1 forks but doesn't reap → `<defunct>` zombies pile up. The "no init in container" classic. | docker |

### CPU + kernel-level (14–17)

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 14 | `14-cpu-thread-runaway.sh` | Process at 100% CPU; need per-thread (`top -H` / `/proc/<pid>/task/`) to find which thread + function | python3 |
| 15 | `15-cpu-throttled.sh` | Container "slow" but `top` shows low CPU — cgroup CPU quota is throttling. Read `cpu.stat` `nr_throttled`. Devin DevBox classic. | docker |
| 16 | `16-host-oom-killer.sh` | `dmesg`-style log shows kernel OOM-killer fired. Investigate why this victim was chosen via `oom_score` / `oom_score_adj`. | python3 |
| 17 | `17-pid-limit.sh` | `fork: Resource temporarily unavailable`. RAM + disk are fine — `RLIMIT_NPROC` / `pid_max` exhausted. Find the spawner. | python3 |

### TLS / cert issues (18–20)

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 18 | `18-tls-cert.sh` | Generic TLS cert errors — distinguish unknown-CA / expired / hostname-mismatch / mTLS-missing | openssl, python3 |
| 19 | `19-corporate-ca-bundle.sh` | Corporate proxy MITMs all HTTPS with org's CA. Install in EVERY tool's trust store (system, npm, pip, docker, git, java). **The most common Devin onboarding cert issue.** | openssl, python3 |
| 20 | `20-private-registry-cert.sh` | `docker pull` from private registry fails x509 even when curl works — dockerd has its own per-registry trust path under `/etc/docker/certs.d/<host>/ca.crt` | docker, openssl |

Scripts that need docker check for it and exit cleanly if absent. Scripts that need sudo prompt explicitly.

The fleet scenarios (09–12) test a fundamentally different skill from 01–08: when you have 10s/100s of containers, you can't `docker logs` each one. You need **aggregation** — `docker inspect $(docker ps -aq)` with `--format` templating, then `sort | uniq -c` or `awk` to find the outlier. This is the daily reality on any DevBox running multiple Devin sessions, or any prod cluster.

## Safety contract

- Every script is **idempotent**: running `start` twice is fine; `restore` always cleans up to the original state.
- No script touches `/`, `/etc`, or any system files outside what's explicitly noted in its header.
- All scratch state lives under `/tmp/domains-practice/` so a `rm -rf /tmp/domains-practice` recovers from anything.
- Container scenarios use prefix `domains-practice-` so `docker rm -f $(docker ps -aq -f name=domains-practice-)` cleans up.

## Suggested order for first pass

**Single-process pass (~60 min)** — learn the harness + talk-track flow:

1. **05-port-collision** (~5 min) — lowest stakes, builds harness familiarity
2. **01-disk-pressure** (~10 min) — classic SE scenario
3. **04-bad-systemd-unit** (~10 min) — systemd flow
4. **06-docker-oom** (~15 min) — most-likely-asked interview scenario
5. **07-docker-no-egress** (~15 min) — networking layer-by-layer
6. **08-bad-resolv** (~15 min) — DNS specifically

Skip 02-hung-process and 03-memory-pressure on first pass; circle back if you want more reps.

**Fleet-scale pass (~60 min)** — once 01–08 feels natural, do these to build the aggregation muscle:

7. **09-fleet-oom** (~12 min) — `docker inspect $(docker ps -aq)` with template formatting
8. **10-agents-flapping** (~15 min) — distinguish deterministic crash from transient restart noise
9. **11-noisy-neighbor** (~12 min) — per-container LogPath size, log-rate aggregation
10. **12-version-skew** (~12 min) — group-by image to find drift
11. **13-zombie-processes** (~10 min) — `<defunct>` accumulation; teaches the "PID 1 must reap" rule + `--init` fix

The fleet scenarios are likely most relevant for the Cognition interview — Devin runs **multiple sessions per DevBox**, so "1 agent is misbehaving in a fleet of N" is the daily SE reality there. Practice these until the `docker inspect $(docker ps -aq) --format ... | sort | uniq -c` pattern is automatic.

**CPU + kernel pass (~50 min)** — process/kernel-level investigation skills:

12. **14-cpu-thread-runaway** (~12 min) — `top -H`, `/proc/<pid>/task/<tid>/stack`, `perf top`
13. **15-cpu-throttled** (~12 min) — cgroup `cpu.stat`, `throttled_usec` (Devin DevBox classic)
14. **16-host-oom-killer** (~12 min) — dmesg pattern, `oom_score` / `oom_score_adj`
15. **17-pid-limit** (~10 min) — `RLIMIT_NPROC` / `pid_max`, finding the runaway forker

**Cert pass (~40 min)** — TLS / CA debugging across the tool zoo:

16. **18-tls-cert** (~12 min) — distinguish unknown-CA / expired / hostname-mismatch / mTLS
17. **19-corporate-ca-bundle** (~15 min) — install corp CA into system + npm + pip + docker + git + java (the Devin onboarding question)
18. **20-private-registry-cert** (~12 min) — dockerd's per-registry trust path (`/etc/docker/certs.d/`)

**Total practice (all 20 scenarios, single careful pass)**: ~3.5 hours.
**With a second warm pass**: ~5 hours.

If you only do ONE scenario, do **15-cpu-throttled** (Devin DevBox-specific) or **19-corporate-ca-bundle** (Devin onboarding-specific). Those two are the highest interview-likelihood items in the whole list.

## Extending

To add a scenario, copy `_template.sh` and fill in the four functions:
`start`, `restore`, `verify`, `reveal`. Add a row to the table above.
