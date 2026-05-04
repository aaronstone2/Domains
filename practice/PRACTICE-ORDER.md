# Practice order — by interview likelihood + topical clusters

> 27 scenarios, ranked. Use this to pick what to drill if you have limited time.

## TL;DR — if you only have 1 hour

Do these 6 in order (highest interview likelihood):

1. **[06](06-docker-oom.sh)** docker-oom — the most-asked container scenario
2. **[15](15-cpu-throttled.sh)** cpu-throttled — Devin DevBox classic
3. **[19](19-corporate-ca-bundle.sh)** corporate-ca-bundle — Devin onboarding
4. **[09](09-fleet-oom.sh)** fleet-oom — multi-container aggregation
5. **[08](08-bad-resolv.sh)** bad-resolv — DNS layer-by-layer
6. **[24](24-fd-exhaustion.sh)** fd-exhaustion — "too many open files"

## Tier 1 — must-do (very likely to come up; 6 hours total)

These cover ~80% of probable interview territory. Drill each twice (cold + warm).

| # | Scenario | Why it's tier 1 | Cluster |
|---:|---|---|---|
| 06 | docker-oom | Container OOMKilled is the canonical container-debug Q | Memory |
| 09 | fleet-oom | "Find the bad container in a fleet" is the realistic SE-at-scale Q | Memory + Fleet |
| 15 | cpu-throttled | Devin DevBox = cgroup-throttled workloads. "Slow but CPU low" is the Devin signature | CPU |
| 19 | corporate-ca-bundle | THE Devin onboarding Q (org CA must be in every tool's trust store) | Certs |
| 08 | bad-resolv | DNS is the most common networking failure; layer-by-layer probe is THE skill | Network/DNS |
| 24 | fd-exhaustion | "Too many open files" — extremely common; everyone gets bitten by it | Process |
| 12 | version-skew | Partial deploys = "1-in-N intermittent failures" pattern | Fleet |
| 04 | bad-systemd-unit | Most Linux services are systemd; demos systemd flow | systemd |
| 13 | zombie-processes | Container PID 1 + reaping = niche but distinctive | Process + Container |
| 14 | cpu-thread-runaway | "100% CPU find which thread" — multi-threaded debug skill | CPU |

## Tier 2 — high value (likely; 4 hours total)

These probably won't ALL come up but knowing them broadens coverage.

| # | Scenario | Why | Cluster |
|---:|---|---|---|
| 16 | host-oom-killer | Distinguish host OOM from cgroup OOM (different signal interpretation) | Memory |
| 11 | noisy-neighbor | 1 of N filling disk via logs — common DevBox issue | Fleet + Disk |
| 18 | tls-cert | Generic cert errors; subtype-distinguishing skill | Certs |
| 20 | private-registry-cert | dockerd's own trust store; common gotcha | Certs |
| 07 | docker-no-egress | Container networking layer-by-layer | Network |
| 21 | systemd-cascade | Distinguish ROOT failure from cascade — graph walk | systemd |
| 01 | disk-pressure | Classic "disk full investigation" | Disk |
| 25 | slow-disk-io | iowait debugging; per-process I/O attribution | Disk + Process |
| 10 | agents-flapping | Restart-rate aggregation — distinguish persistent crash from noise | Fleet |
| 03 | memory-pressure | Find process holding RAM (related to 06/09/16 but at host scope) | Memory |

## Tier 3 — good practice (less likely but possible; 3 hours total)

| # | Scenario | Why | Cluster |
|---:|---|---|---|
| 05 | port-collision | EADDRINUSE — easy but warming up; demonstrates ss/lsof | Network |
| 22 | clock-skew | Distinctive "expired credential with valid creds" pattern | Certs + Clock |
| 26 | swap-thrashing | Distinguishing thrashing from OOM-bound vs iowait-bound | Memory |
| 17 | pid-limit | fork() EAGAIN / RLIMIT_NPROC | Process |
| 02 | hung-process | S-state vs D-state, /proc/wchan | Process |
| 27 | dind-permissions | Container talking to host docker socket — Devin-specific | Container + Security |

## Tier 4 — niche (possible but unlikely; ~1 hour)

| # | Scenario | Why | Cluster |
|---:|---|---|---|
| 23 | apparmor-denial | LSM denial — distinctive but rare | Security |

---

## Topical clusters (drill related ones in one session)

When you practice, group related scenarios so the patterns reinforce. Drill cluster-at-a-time, not scenario-at-a-time.

### Memory (~30 min)
[03](03-memory-pressure.sh) → [06](06-docker-oom.sh) → [16](16-host-oom-killer.sh) → [09](09-fleet-oom.sh) → [26](26-swap-thrashing.sh)

The progression: per-process leak → cgroup OOM → host OOM → fleet aggregation → thrashing. Each builds on the previous. Pattern shared: `RSS / oom_score / cgroup memory.events / vmstat si-so`.

### CPU (~20 min)
[14](14-cpu-thread-runaway.sh) → [15](15-cpu-throttled.sh)

Per-thread investigation, then cgroup-throttle investigation. The skill is "process-level metrics hide things — drill into per-thread or per-cgroup level". Pattern shared: `top -H / pidstat / /proc/<pid>/task/ / cpu.stat`.

### Disk + I/O (~25 min)
[01](01-disk-pressure.sh) → [11](11-noisy-neighbor.sh) → [25](25-slow-disk-io.sh)

Disk-full → fleet-noisy-neighbor → iowait saturation. The skill is "df is the start, du / per-container LogPath / iotop are the drill-downs". Pattern shared: `df / du / iostat / iotop / lsof`.

### Network + DNS (~30 min)
[05](05-port-collision.sh) → [07](07-docker-no-egress.sh) → [08](08-bad-resolv.sh)

Port-bind → container-egress → DNS specifically. Skill: layer-by-layer (link → IP → DNS → app). Pattern shared: `ss -tlnp / ping / nslookup / iptables / docker network inspect`.

### Certs + TLS (~40 min)
[18](18-tls-cert.sh) → [19](19-corporate-ca-bundle.sh) → [20](20-private-registry-cert.sh) → [22](22-clock-skew.sh)

Generic cert errors → corp CA → docker-specific trust store → clock-skew-as-cert-error. Skill: "openssl s_client + openssl x509 + per-tool trust path". Pattern shared: `openssl s_client / openssl x509 / update-ca-certificates / curl --cacert`.

### Process internals (~30 min)
[02](02-hung-process.sh) → [13](13-zombie-processes.sh) → [17](17-pid-limit.sh) → [24](24-fd-exhaustion.sh)

Hung process → zombie process → fork EAGAIN → too-many-open-files. All process-table investigation. Pattern shared: `ps / /proc/<pid>/{status,fd,task,limits} / lsof`.

### systemd (~15 min)
[04](04-bad-systemd-unit.sh) → [21](21-systemd-cascade.sh)

Single unit fails → graph of cascading failures. Skill: walk the dep tree, distinguish ROOT from cascade. Pattern shared: `systemctl status / journalctl -u / list-dependencies / systemd-analyze verify`.

### Multi-container fleet (~50 min)
[09](09-fleet-oom.sh) → [10](10-agents-flapping.sh) → [11](11-noisy-neighbor.sh) → [12](12-version-skew.sh)

OOM in fleet → restart-rate aggregation → log-volume aggregation → image-tag drift. Skill: `docker inspect $(docker ps -aq) --format ... | sort | uniq -c | head`. ALL fleet scenarios use this same aggregation pattern with different fields.

### Security + container isolation (~25 min)
[23](23-apparmor-denial.sh) → [27](27-dind-permissions.sh)

LSM denial → docker-socket bind-mount. Both are "permission denied that POSIX perms don't explain". Pattern: kernel-level access controls, audit log, capability sets.

---

## Two-pass strategy (recommended ~5 hours total)

### Pass 1 — cold: cluster-at-a-time, learn the harness flow (~3 hours)

Do clusters in this order. Within each cluster, do the scenarios sequentially:

1. **Memory cluster** (30 min) — start here; OOM is the most likely interview Q
2. **CPU cluster** (20 min) — Devin-specific
3. **Certs cluster** (40 min) — Devin onboarding-likely
4. **Network/DNS cluster** (30 min) — broadly applicable
5. **Multi-container fleet cluster** (50 min) — Devin DevBox = fleet
6. **Disk + I/O cluster** (25 min)
7. **systemd cluster** (15 min)
8. **Process internals cluster** (30 min)
9. **Security cluster** (25 min)

**Skip on first pass** if time-constrained: 02, 17, 22, 23, 26, 27 (tier 3-4).

### Pass 2 — warm: timed, scenarios-at-random (~2 hours)

```bash
# pick 10 scenarios at random
ls practice/[0-9][0-9]-*.sh | shuf -n 10
```

Time yourself per scenario. Goal: average <8 min per scenario by pass 2. The cold pass should have built enough pattern recognition that you're not exploring on the warm pass.

---

## Time-pressed alternatives

### "I have 30 min" (just one cluster)
**Memory cluster** — covers OOM debugging which is most likely.

### "I have 1 hour" (top 6)
[06](06-docker-oom.sh) → [15](15-cpu-throttled.sh) → [19](19-corporate-ca-bundle.sh) → [09](09-fleet-oom.sh) → [08](08-bad-resolv.sh) → [24](24-fd-exhaustion.sh)

### "I have 2 hours" (tier 1, single cold pass)
All 10 tier-1 scenarios in cluster order. ~12 min each.

### "I have 3 hours" (tier 1 + tier 2 cold pass)
20 scenarios. Cluster order. Skip tier 3-4.

### "I have all day"
All 27 in cluster order pass 1 (~5 hr), shuffled pass 2 (~2 hr). Then read [cluely/06-talk-tracks.md](../cluely/06-talk-tracks.md) and [cluely/07-anti-patterns.md](../cluely/07-anti-patterns.md) and rehearse out loud.

---

## What "warm pass" means

After you've done a scenario once, the second time should be:
- **Faster**: you know what the harness will say
- **Narrated**: practice talking aloud as you work
- **Time-pressured**: aim for half the cold-pass time
- **Without reading reveal first**: commit to your answer before peeking

The interview will not be your first time seeing OOMKilled. Make it not be your second time either.

---

## Cross-references

- Scenario index: [README.md](README.md)
- Cluely uploads (use during interview): [../cluely/README.md](../cluely/README.md)
- Live talk-track scripts: [../cluely/06-talk-tracks.md](../cluely/06-talk-tracks.md)
- Anti-patterns: [../cluely/07-anti-patterns.md](../cluely/07-anti-patterns.md)
- Day-of script: [../domains/_shared/rehearsal/INTERVIEW-DAY.md](../domains/_shared/rehearsal/INTERVIEW-DAY.md)
