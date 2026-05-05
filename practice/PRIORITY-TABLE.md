# Priority table — all 32 scenarios ranked

> Re-ranked 2026-05-05 with Devin top-tickets intel: scenarios 28-32 added
> as Devin-platform-specific patterns. Customer App 101 = scenario 19;
> Bug 101 = scenario 28; both jumped to top of priority list.

> One table. Sortable mentally by any column. If you're picking what to drill, sort by **Priority** column. If you're grouping a session, sort by **Cluster** column. If you're filtering by what you can actually run, sort by **Needs**.

## Devin top-tickets fast-path (do these 7 first)

These map to the actual most-common Devin support tickets. If you have 90 minutes, do exactly these in order:

| Order | # | Scenario file | What it actually is | Time |
|---:|---:|---|---|---:|
| 1 | 19 | `19-corporate-ca-bundle.sh` | **Customer App 101** — corp proxy TLS, npm/pip fails through Zscaler/Netskope | 15m |
| 2 | 28 | `28-env-var-empty.sh` | **Bug 101** — repo-scoped secrets not auto-injected as env vars | 12m |
| 3 | 06 | `06-docker-oom.sh` | container exit 137 / OOMKilled — most-asked container Q | 12m |
| 4 | 15 | `15-cpu-throttled.sh` | DevBox cgroup throttling — "slow but CPU low" signature | 12m |
| 5 | 32 | `32-push-rejected.sh` | git push blocked — distinguish perms vs branch protection | 10m |
| 6 | 29 | `29-tools-old-version.sh` | snapshot fell back silently after build failure | 12m |
| 7 | 31 | `31-agent-stuck-repeating.sh` | long-session context overflow — Knowledge note fix | 15m |

Total: ~88 min cold. After this, you've covered every documented top-7 Devin support ticket.

## Master ranking (priority 1 → 32)

| Pri | # | Scenario | Tier | Difficulty | Cold | Warm | Cluster | Needs | Devin-relev | Core skill / pattern |
|---:|---:|---|---:|---|---:|---:|---|---|---|---|
| **1** | 19 | corporate-ca-bundle | 1 | adv | 15m | 8m | Certs | openssl,py3 | **HIGH** | install corp CA into 7+ trust stores (sys/npm/pip/docker/git/java). **CUSTOMER APP 101** |
| **2** | 28 | env-var-empty | 1 | mid | 12m | 6m | Devin+Secrets | bash | **HIGH** | repo-scoped secrets at /run/repo_secrets/.env.secrets need explicit source. **BUG 101** |
| **3** | 06 | docker-oom | 1 | mid | 12m | 6m | Memory | docker | **HIGH** | `docker inspect .State.OOMKilled` + cgroup memory.events |
| **4** | 15 | cpu-throttled | 1 | adv | 12m | 6m | CPU | docker | **HIGH** | `cpu.stat` `nr_throttled` / `throttled_usec` (slow but %CPU low) |
| **5** | 32 | push-rejected | 1 | mid | 10m | 5m | Devin+Git | git | **HIGH** | distinguish GitHub App perms vs branch protection; PR-based workflow |
| **6** | 29 | tools-old-version | 1 | mid | 12m | 6m | Devin+Snapshots | none | **HIGH** | snapshot.build.failed + snapshot.fallback.activate signals; environment.yaml init step |
| **7** | 31 | agent-stuck-repeating | 1 | mid-adv | 15m | 8m | Devin+Agent | none | **HIGH** | repeated cmd patterns across hours; long-session context overflow; Knowledge note fix |
| **8** | 30 | session-drops-periodically | 2 | mid-adv | 12m | 6m | Devin+Network | none | **HIGH** | exact ~351s pattern → AWS NAT Gateway idle timeout; PrivateLink fix |
| **9** | 09 | fleet-oom | 1 | mid | 12m | 6m | Fleet+Mem | docker | **HIGH** | `docker inspect $(docker ps -aq) --format ... | sort | uniq -c` |
| **5** | 08 | bad-resolv | 1 | mid | 12m | 6m | Network | docker | MED | DNS layer-by-layer (link → IP → DNS → app); `/etc/resolv.conf` |
| **6** | 24 | fd-exhaustion | 1 | mid | 10m | 5m | Process | py3 | MED | `/proc/<pid>/fd/` count vs `RLIMIT_NOFILE`; CLOSE_WAIT smoking gun |
| **7** | 12 | version-skew | 1 | mid | 12m | 6m | Fleet | docker | **HIGH** | `docker inspect | sort | uniq -c` to find the drifted replica |
| **8** | 04 | bad-systemd-unit | 1 | mid | 10m | 5m | systemd | systemctl | MED | `systemctl status` → `journalctl -u` → `systemd-analyze verify` |
| **9** | 14 | cpu-thread-runaway | 1 | adv | 12m | 6m | CPU | py3 | MED | `top -H` / `pidstat -t` / `/proc/<pid>/task/<tid>/stack` |
| **10** | 13 | zombie-processes | 1 | mid | 10m | 5m | Process+Container | docker | **HIGH** | PID 1 must reap; `--init` flag; `ps -eo state` Z column |
| **11** | 16 | host-oom-killer | 2 | mid | 12m | 6m | Memory | py3 | MED | `dmesg \| grep killed`; `oom_score` / `oom_score_adj`; vs cgroup OOM |
| **12** | 11 | noisy-neighbor | 2 | mid | 12m | 6m | Fleet+Disk | docker | **HIGH** | per-container `LogPath` size aggregation; log-rate; `--log-opt max-size` |
| **13** | 18 | tls-cert | 2 | mid | 12m | 6m | Certs | openssl,py3 | MED | distinguish unknown-CA / expired / hostname / mTLS via `openssl s_client` |
| **14** | 20 | private-registry-cert | 2 | mid | 12m | 6m | Certs+Container | docker,openssl | **HIGH** | dockerd's per-registry trust path `/etc/docker/certs.d/<host>/ca.crt` |
| **15** | 07 | docker-no-egress | 2 | adv | 15m | 8m | Network+Container | docker | **HIGH** | network layer-by-layer; `--internal` flag catches; iptables MASQUERADE |
| **16** | 21 | systemd-cascade | 2 | mid-adv | 12m | 6m | systemd | systemctl | MED | distinguish ROOT failure from "Failed: dependency" cascades; dep-graph walk |
| **17** | 01 | disk-pressure | 2 | entry | 8m | 4m | Disk | none | MED | `df` → `du -sh /tmp/*  | sort -h | tail`; safe rm |
| **18** | 25 | slow-disk-io | 2 | mid-adv | 12m | 6m | Disk+Process | none | MED | `iostat -xz` USE method; `iotop -b -o` per-process; `/proc/<pid>/io` |
| **19** | 10 | agents-flapping | 2 | mid-adv | 15m | 8m | Fleet | docker | **HIGH** | `docker events --filter event=die`; restart-rate aggregation |
| **20** | 03 | memory-pressure | 2 | entry-mid | 8m | 4m | Memory | py3 | MED | `free -h` + `ps --sort=-rss`; per-process `VmRSS` from `/proc/<pid>/status` |
| **21** | 05 | port-collision | 3 | entry | 5m | 2m | Network | py3 or nc | LOW-MED | `ss -tlnp 'sport = :PORT'`; `lsof -i :PORT` |
| **22** | 22 | clock-skew | 3 | mid | 10m | 5m | Certs+Clock | openssl | MED-HIGH | `date -u` vs external; `chronyc tracking`; cert/JWT `notBefore`/`exp` decode |
| **23** | 26 | swap-thrashing | 3 | adv | 10m | 5m | Memory | py3 | LOW-MED | `vmstat` `si`/`so` sustained; `/proc/pressure/memory`; per-pid `VmSwap` |
| **24** | 17 | pid-limit | 3 | mid | 10m | 5m | Process | py3 | MED | `RLIMIT_NPROC`; `ps -eo ppid | sort | uniq -c` finds heavy spawner |
| **25** | 02 | hung-process | 3 | mid | 10m | 5m | Process | none | LOW | `ps -eo state` (S/D/Z); `/proc/<pid>/wchan`; S vs D matters |
| **26** | 27 | dind-permissions | 3 | mid | 12m | 6m | Container+Security | docker | **HIGH** | `/var/run/docker.sock` uid/gid mismatch; `--group-add` vs `--user root` vs rootless |
| **27** | 23 | apparmor-denial | 4 | adv | 12m | 6m | Security | none | MED | LSM denial decoding via `dmesg \| grep DENIED` or `ausearch -m AVC`; profile editing |

**Total time:** ~5h cold pass · ~2.5h warm pass · ~7.5h both passes

## Filtered views

### Top 10 by Devin-relevance (do these if you only have 2 hours)

| Pri | # | Scenario | Why Devin-specific |
|---:|---:|---|---|
| 1 | 06 | docker-oom | Devin runs containers; OOMKill is the canonical signal |
| 2 | 15 | cpu-throttled | DevBox = cgroups; "slow but CPU low" IS the DevBox signature |
| 3 | 19 | corporate-ca-bundle | Devin org-deployed = corp proxy MITM; first thing you'll hit |
| 4 | 09 | fleet-oom | Multiple Devin sessions per DevBox = fleet aggregation |
| 7 | 12 | version-skew | Partial deploy in fleet; agent-image drift |
| 10 | 13 | zombie-processes | Devin agent containers without `--init` |
| 12 | 11 | noisy-neighbor | DevBox shared disk; one session can dominate |
| 14 | 20 | private-registry-cert | Pulling internal images into Devin builds |
| 15 | 07 | docker-no-egress | Devin can't reach internal/external; common config issue |
| 19 | 10 | agents-flapping | Distinguish "one agent broke" from "fleet noise" |
| 26 | 27 | dind-permissions | Devin sessions that build/run containers themselves |

### Filtered by what you can run (no docker / no sudo)

If your local box doesn't have docker working:

| Pri | # | Scenario | Cluster |
|---:|---:|---|---|
| 6 | 24 | fd-exhaustion | Process |
| 8 | 04 | bad-systemd-unit | systemd |
| 9 | 14 | cpu-thread-runaway | CPU |
| 11 | 16 | host-oom-killer | Memory |
| 16 | 21 | systemd-cascade | systemd |
| 17 | 01 | disk-pressure | Disk |
| 18 | 25 | slow-disk-io | Disk |
| 20 | 03 | memory-pressure | Memory |
| 21 | 05 | port-collision | Network |
| 22 | 22 | clock-skew | Certs+Clock |
| 23 | 26 | swap-thrashing | Memory |
| 24 | 17 | pid-limit | Process |
| 25 | 02 | hung-process | Process |
| 27 | 23 | apparmor-denial | Security |

That's still 14 scenarios runnable without docker. The clusters that suffer most from no-docker: Fleet (all 4), Container security (13, 27).

### Sort by cluster (drill related ones together)

| Cluster | Scenarios (in priority order) | Total cold time |
|---|---|---:|
| **Memory** | 06 → 09 → 16 → 03 → 26 | 54m |
| **CPU** | 15 → 14 | 24m |
| **Network/DNS** | 08 → 07 → 05 | 32m |
| **Certs** | 19 → 18 → 20 → 22 | 49m |
| **Process** | 24 → 13 → 17 → 02 | 42m |
| **Disk** | 11 → 01 → 25 | 32m |
| **Fleet** | 09 → 12 → 11 → 10 | 51m |
| **systemd** | 04 → 21 | 22m |
| **Container security** | 27 → 23 | 24m |

(Some scenarios appear in 2+ clusters — they share patterns. The "Fleet" cluster overlaps with "Memory" via 09 and "Disk" via 11.)

### Sort by difficulty (entry → advanced)

| Difficulty | Count | Scenarios |
|---|---:|---|
| Entry | 3 | 01, 03 (entry-mid), 05 |
| Mid | 14 | 02, 04, 06, 08, 09, 11, 12, 13, 16, 17, 18, 20, 22, 24, 27 |
| Mid-Advanced | 4 | 10, 21, 25 |
| Advanced | 6 | 07, 14, 15, 19, 23, 26 |

If you're warming up, do an entry first (05 port-collision in 5 min). If you're stretching, do an advanced (15 cpu-throttled or 19 corp-CA).

## How to use this table

**Picking what to do next:** sort by Pri column; do row 1 next.

**Planning a session:** pick a Cluster value; do all scenarios in that cluster.

**Time-boxed:** sum the Cold column for the rows you'll do. Add 25% buffer.

**Cross-references:**
- Full session-planning narrative: [PRACTICE-ORDER.md](PRACTICE-ORDER.md)
- Each scenario's reveal text + diagnostic flow: see the script's `reveal` arg
- Live talk-track for any scenario type: [../cluely/06-talk-tracks.md](../cluely/06-talk-tracks.md)
