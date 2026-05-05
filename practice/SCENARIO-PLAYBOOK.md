# Scenario playbook — symptom → diagnostic → fix → talk-track

> One row per scenario. When a customer reports symptom X, this tells you
> exactly which `dprobe` to run, which `dfix` to apply, which `harness ask`
> to query, and the talk-track structure to narrate.
>
> Pair this with `PRIORITY-TABLE.md` (drill order) and `cluely/06-talk-tracks.md`
> (verbatim phrasing).

## How to read a row

Every scenario follows the same four-step flow:

1. **Probe** — `dprobe <keyword> <container>` → dumps the diagnostic data
2. **Ask** — `harness ask "<symptom>"` → corpus returns failure mode + talk track + citations
3. **Fix** — `dfix <keyword> <container> [args] --apply` → applies remediation
4. **Verify** — re-probe; confirm green

The talk-track column is the 30-second narration template — adapt to the actual interview phrasing.

---

## Tier 1 — Devin top-tickets fast-path

### 19 — `19-corporate-ca-bundle.sh` (Customer App 101)

| Field | Value |
|---|---|
| **Customer says** | "npm install fails UNABLE_TO_VERIFY_LEAF_SIGNATURE" / "pip can't reach PyPI" / "curl works but my tools don't" |
| **dprobe** | `dprobe tls <c> registry.npmjs.org:443` |
| **harness ask** | `"Node corporate CA NODE_EXTRA_CA_CERTS curl works but node fails"` |
| **dfix** | `dfix cabundle <c> /path/root.pem /path/intermediate.pem --apply` then `dfix env <c> NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply` |
| **Permanent** | environment.yaml maintenance: `set -a; . /etc/ssl/corp.env; set +a`; ship CA via Dockerfile COPY |
| **Talk-track** | "OS trust store has the corp CA but each language runtime has its own. Node uses NODE_EXTRA_CA_CERTS, Python uses REQUESTS_CA_BUNDLE, Java uses cacerts via keytool, Docker has /etc/docker/certs.d/. Each must be configured." |

### 28 — `28-env-var-empty.sh` (Bug 101)

| Field | Value |
|---|---|
| **Customer says** | "I added MY_API_KEY to my Devin secrets but my app says it's empty" |
| **dprobe** | `dprobe secrets <c>` |
| **harness ask** | `"devin secret added but env var empty"` |
| **dfix** | `dfix env <c> MY_API_KEY "$(cat /run/repo_secrets/.../.env.secrets | grep MY_API_KEY | cut -d= -f2)" --apply` (one-shot) |
| **Permanent** | environment.yaml maintenance: `set -a; . /run/repo_secrets/$REPO_OWNER/$REPO_NAME/.env.secrets; set +a` |
| **Talk-track** | "Devin's repo-scoped secrets live at /run/repo_secrets/.../.env.secrets — they're NOT auto-injected as env vars (org and user-scoped ARE). The customer needs to source them, ideally in the maintenance section so it happens every session." |

### 06 — `06-docker-oom.sh`

| Field | Value |
|---|---|
| **Customer says** | "container exit 137" / "container keeps restarting" / "OOMKilled" |
| **dprobe** | `dprobe oom <c>` then `dprobe restart <c>` |
| **harness ask** | `"container OOMKilled exit 137"` |
| **dfix** | Set higher memory limit (require container recreate); for in-container memory leak, identify offender via probe → restart |
| **Permanent** | docker-compose `mem_limit:` higher OR fix the leak; alert on cgroup memory.events oom_kill counter |
| **Talk-track** | "OOMKilled = cgroup OOM (different from host OOM). Confirm via docker inspect .State.OOMKilled, then memory.events. Fix: raise --memory if working set legitimately needs it, OR find the leaker via per-process VmRSS, OR add request limits if upstream traffic surge." |

### 15 — `15-cpu-throttled.sh` (DevBox classic)

| Field | Value |
|---|---|
| **Customer says** | "container is slow but top shows low CPU" / "DevBox feels sluggish" |
| **dprobe** | `dprobe throttle <c>` |
| **harness ask** | `"container slow but CPU low cgroup throttle"` |
| **dfix** | Raise --cpus / --cpu-quota (require container recreate) — `dfix recreate-init` is recipe-only; manual docker run with --cpus="2" |
| **Permanent** | docker-compose `cpus: 2.0`; investigate why workload spiked |
| **Talk-track** | "When cgroup CPU quota is hit, the kernel throttles the process. From INSIDE the container, top shows %CPU as a fraction of the cgroup quota — appears low. The smoking gun is cpu.stat nr_throttled / throttled_usec — climbing while %CPU appears flat." |

### 32 — `32-push-rejected.sh` (Bug #6)

| Field | Value |
|---|---|
| **Customer says** | "Devin tried to push to my repo and got permission denied" |
| **dprobe** | (no canonical dprobe; check `gh api repos/.../branches/main/protection`) |
| **harness ask** | `"devin git push permission denied branch protection"` |
| **dfix** | Use PR-based workflow: `git checkout -b devin/fix-NN; git push -u origin devin/fix-NN; gh pr create --base main` |
| **Permanent** | Educate team; set up CODEOWNERS for Devin's bot; pre-configure required CI checks |
| **Talk-track** | "Two distinct causes of 'permission denied' on git push: (1) GitHub App lacks contents:write permission, OR (2) branch protection requires PRs/reviews/checks. The error message hints which: 'Resource not accessible' = perms; 'Required pull request reviews missing' / 'GH013' = branch protection. Devin's bot is correctly scoped for PR-based workflow, just needs to be used that way." |

### 29 — `29-tools-old-version.sh` (Bug #3)

| Field | Value |
|---|---|
| **Customer says** | "I added X to my environment.yaml and pushed, but my session still has the old version" |
| **dprobe** | (no canonical; read snapshot build log at `/var/log/devin/snapshot-build.log` if available) |
| **harness ask** | `"devin tools wrong version after pushing yaml"` |
| **dfix** | Install the missing/outdated tool manually for THIS session; fix environment.yaml for next snapshot build |
| **Permanent** | Fix the failing initialize step; watch snapshot build logs after every yaml change; alert on snapshot build status |
| **Talk-track** | "Devin's snapshot system is fail-safe — if a build fails, sessions continue using the previous successful snapshot. Look for snapshot.build.failed AND snapshot.fallback.activate in the build log; that confirms fallback. Then walk initialize.step events to find which step actually failed." |

### 31 — `31-agent-stuck-repeating.sh` (Bug #5)

| Field | Value |
|---|---|
| **Customer says** | "Devin keeps doing the same thing over and over, won't progress" |
| **dprobe** | (no canonical; analyze agent log: `grep -oE 'cmd="[^"]+"' agent.log \| sort \| uniq -c \| sort -rn`) |
| **harness ask** | `"devin agent stuck looping no progress"` |
| **dfix** | Tell user to: end session → write Knowledge note with prior context → start new session |
| **Permanent** | Build proactive Knowledge notes; avoid >3-4 hour heavy debug sessions; chunk work |
| **Talk-track** | "LLM context window is finite. Long sessions drop early content as new turns arrive — agent literally forgets what it tried earlier. Look for repeated cmd patterns separated by hours of session time. Fix: Knowledge notes are persistent memory; new session pulls them as context." |

---

## Tier 1 — Other high-priority

### 09 — `09-fleet-oom.sh`

| Field | Value |
|---|---|
| **Customer says** | "1 of my 10 containers OOMs randomly, can't tell which" |
| **dprobe** | `dprobe oom` (host) then aggregate: `docker inspect $(docker ps -aq) --format '{{.Name}} {{.State.OOMKilled}}' \| awk '$2=="true"'` |
| **harness ask** | `"find OOM container in fleet docker inspect aggregation"` |
| **dfix** | Per-container fix once identified — see scenario 06 |
| **Talk-track** | "When you have N containers, you can't `docker logs` each. Aggregate: `docker inspect $(docker ps -aq) --format '{{.Name}} {{.State.OOMKilled}}' \| awk '$2==true'` finds the OOM'd one in O(1) commands." |

### 08 — `08-bad-resolv.sh`

| Field | Value |
|---|---|
| **Customer says** | "Container can't resolve hostnames / DNS broken inside container" |
| **dprobe** | `dprobe dns <c> <hostname>` |
| **harness ask** | `"DNS broken inside container resolv.conf"` |
| **dfix** | `dfix dns <c> <upstream-dns-ip> --apply` OR `dfix hosts <c> <ip> <hostname> --apply` |
| **Permanent** | docker-compose `dns:` field, or fix host's systemd-resolved |
| **Talk-track** | "DNS layer-by-layer: resolv.conf (which resolver?), dig at THAT resolver (does it answer?), then up the chain. Inside a container the path is: app → glibc → /etc/resolv.conf → 127.0.0.11 (Docker embedded) → host's /etc/resolv.conf → upstream." |

### 24 — `24-fd-exhaustion.sh`

| Field | Value |
|---|---|
| **Customer says** | "EMFILE: too many open files" / "too many open files" |
| **dprobe** | `dprobe procs <c>` then per-process `ls /proc/<pid>/fd \| wc -l` |
| **harness ask** | `"too many open files EMFILE fd leak"` |
| **dfix** | Identify leaking process via `dprobe leak`, restart it: `dfix restart-process <c> <pattern> --apply` |
| **Permanent** | Fix the code (close handles, use connection pool, raise ulimit if legitimate) |
| **Talk-track** | "EMFILE = process hit RLIMIT_NOFILE. Two questions: (1) is the limit too low for legitimate use? (2) is the process leaking? Check `cat /proc/<pid>/limits` for the limit, `ls /proc/<pid>/fd \| wc -l` for actual count. CLOSE_WAIT sockets are the smoking gun for socket-leak." |

---

## Tier 2

### 16 — `16-host-oom-killer.sh`
- **Customer says**: "kernel killed my process / random crash"
- **dprobe**: `dprobe oom` (host)
- **dfix**: per-process OOM scoring; lower other procs' oom_score_adj
- **Talk-track**: "Distinguish host OOM (`dmesg \| grep killed`) from cgroup OOM (`memory.events`). Different signals, different fixes."

### 11 — `11-noisy-neighbor.sh`
- **Customer says**: "1 container is filling the disk somehow"
- **dprobe**: `dprobe disk` then per-container LogPath aggregation
- **dfix**: `dfix prune --apply` then per-container `--log-opt max-size`
- **Talk-track**: "Per-container `LogPath` size aggregation finds the noisy one. Permanent: `--log-opt max-size=10m --log-opt max-file=3` per container."

### 18 — `18-tls-cert.sh`
- **Customer says**: "TLS error" (vague)
- **dprobe**: `dprobe tls <c> <host:port>`
- **dfix**: depends — chain → `dfix cabundle`; expiry → `dfix cert-renew` or fix clock; hostname mismatch → fix SAN
- **Talk-track**: "Distinguish unknown-CA / expired / hostname-mismatch / mTLS via openssl s_client output. Each has a different fix."

### 20 — `20-private-registry-cert.sh`
- **Customer says**: "docker pull from internal registry fails x509"
- **dprobe**: `dprobe tls <c> registry.example.com:443`
- **dfix**: `sudo mkdir -p /etc/docker/certs.d/registry.example.com && sudo cp ca.crt /etc/docker/certs.d/registry.example.com/`
- **Talk-track**: "dockerd has its OWN trust store at `/etc/docker/certs.d/<host>/ca.crt`, separate from the system CA store. curl works because it uses /etc/ssl, dockerd doesn't."

### 07 — `07-docker-no-egress.sh`
- **Customer says**: "Container can't reach internet"
- **dprobe**: `dprobe network <c>`
- **dfix**: per-container — check `--internal` flag, MASQUERADE rules, NetworkPolicy
- **Talk-track**: "Network layer-by-layer from inside the container: link → IP → DNS → app. Each layer is one cheap probe."

### 21 — `21-systemd-cascade.sh`
- **Customer says**: "Multiple services failed at boot"
- **dprobe**: `systemctl list-units --failed`; `systemctl list-dependencies <unit>`
- **dfix**: fix the ROOT failure; `dfix reload <c> systemd` if applicable; `systemctl reset-failed`
- **Talk-track**: "When N units fail, find the ROOT — walk dep graph backward. 'Failed: dependency' messages are cascades, not roots."

### 01 — `01-disk-pressure.sh`
- **Customer says**: "no space left on device"
- **dprobe**: `dprobe disk`
- **dfix**: `dfix prune --apply` then `du -sh` to find biggest dir; `journalctl --vacuum-size=100M`
- **Talk-track**: "df → du → sort. df shows the partition; du finds the heaviest dir; sort by size finds the offender. Most common: docker images, build cache, log files."

### 25 — `25-slow-disk-io.sh`
- **Customer says**: "App slow, disk seems busy"
- **dprobe**: `dprobe disk`; `iostat -xz 1 5`
- **dfix**: identify offender; `dfix restart-process <c> <pattern>` if a runaway writer; rate-limit
- **Talk-track**: "iowait high + low %us = I/O-bound. iostat finds the disk; iotop / pidstat -d / /proc/<pid>/io find the per-process attribution."

### 10 — `10-agents-flapping.sh`
- **Customer says**: "1 of my 8 agents keeps crashing"
- **dprobe**: `dprobe restart <c>`; `docker events --filter event=die`
- **dfix**: per-container fix; `dfix restart-container --apply`
- **Talk-track**: "Restart-rate aggregation distinguishes deterministic crash (high count) from transient noise (low). `docker events --since 30m --filter event=die \| sort \| uniq -c` ranks by frequency."

### 03 — `03-memory-pressure.sh`
- **Customer says**: "system memory full / RAM at 100%"
- **dprobe**: `dprobe oom`; `free -h`; `ps --sort=-rss`
- **dfix**: `dfix restart-process <c> <heaviest>`; raise mem; lower other workloads
- **Talk-track**: "Find the heaviest by RSS, decide if legitimate. `ps --sort=-rss -eo pid,rss,comm \| head` is one line."

---

## Tier 3

### 05 — `05-port-collision.sh`
- **Customer says**: "EADDRINUSE / address already in use"
- **dprobe**: `dprobe network <c>`; `ss -tlnp 'sport = :<port>'`; `lsof -i :<port>`
- **dfix**: kill or move the conflicting process
- **Talk-track**: "ss tells you who's listening; lsof confirms. Kill or change port."

### 22 — `22-clock-skew.sh`
- **Customer says**: "JWT/cert expired but it's brand new"
- **dprobe**: `date -u` vs `curl -sI google.com \| grep ^date`
- **dfix**: `sudo systemctl restart chrony`; `sudo timedatectl set-ntp true`
- **Talk-track**: "Brand-new credential rejected as expired = clock skew. Compare local UTC to a trusted external."

### 26 — `26-swap-thrashing.sh`
- **Customer says**: "Everything slow, no specific process at 100%"
- **dprobe**: `vmstat 2 5` (look for sustained si/so > 0)
- **dfix**: identify swap consumer (per-process VmSwap), kill or rebalance
- **Talk-track**: "Sustained si AND so > 0 = thrashing. Working set > RAM, kernel pages constantly. Real fix is more RAM or smaller WS."

### 17 — `17-pid-limit.sh`
- **Customer says**: "fork: Resource temporarily unavailable"
- **dprobe**: `dprobe procs <c>`; `ps -eo ppid \| sort \| uniq -c \| sort -rn`
- **dfix**: kill heavy spawner; raise RLIMIT_NPROC if legitimate
- **Talk-track**: "EAGAIN on fork = pid limit. Find the heavy spawner via ppid aggregation."

### 02 — `02-hung-process.sh`
- **Customer says**: "process hung, can't kill it"
- **dprobe**: `dprobe procs <c>`; check D-state via `ps -eo state`
- **dfix**: `cat /proc/<pid>/wchan` to see why; can't kill D-state until syscall returns
- **Talk-track**: "S vs D matters. D = uninterruptible (kernel I/O wait). Z = zombie. Look at wchan to see what kernel function it's waiting in."

### 27 — `27-dind-permissions.sh`
- **Customer says**: "permission denied on docker socket from inside container"
- **dprobe**: `docker exec <c> ls -la /var/run/docker.sock`
- **dfix**: `--group-add $(getent group docker | cut -d: -f3)` at run time, or `--user root` (less secure)
- **Talk-track**: "Container's user uid/gid doesn't match host's docker group. Either run as root, or add to matching group via --group-add."

---

## Tier 4

### 23 — `23-apparmor-denial.sh`
- **Customer says**: "permission denied even with chmod 777"
- **dprobe**: `sudo dmesg \| grep DENIED`; `sudo ausearch -m AVC`
- **dfix**: `sudo aa-complain` to test, then write proper allow rule
- **Talk-track**: "POSIX perms fine + permission denied = LSM (AppArmor/SELinux) denied at syscall layer. Decode via dmesg DENIED or audit log."

---

## How to use this playbook in the interview

1. Customer reports symptom
2. Match the "Customer says" column → find the row
3. Run the **dprobe** command → confirm root cause
4. Run **harness ask** with the suggested phrasing → get full talk-track + corpus citations
5. Run **dfix** preview, then **dfix --apply** → fix the immediate issue
6. **Talk-track** → narrate as you go (curiosity → diagnose → trade-off → fix)
7. Mention the **permanent fix** at deployment level

When a scenario doesn't match any row exactly:
- The closest row's `dprobe` keyword is usually still useful
- `dprobe gateway <c>` (full dump) is the catch-all when uncertain
- `harness ask` with the customer's exact words → the corpus surfaces the closest failure mode

---

## Corpus integration

The playbook content is also stored in the corpus DuckDB so `harness ask`
returns it during the interview. New failure mode IDs:

| ID | Surface symptom |
|---|---|
| `docker.fm.multi-symptom-service-gateway` | gateway 503 + N downstream classes failing |
| `devin.fm.repo-scoped-secret-not-auto-injected` | Devin Bug 101 — secret env var empty |
| `devin.fm.snapshot-fallback-after-build-failure` | session boots from old snapshot after blueprint changes |
| `devin.fm.nat-gateway-idle-timeout-disconnects` | long-running session loses connections after idle |
| `devin.fm.long-session-context-overflow-loop` | Devin loops re-reading files; ACU burn climbs |
| `devin.fm.git-push-blocked-by-branch-protection` | Devin completes work but git push rejected |

Existing failure modes were also enriched with `dprobe`/`dfix` references in
their fix_steps: `docker.fm.exit-137-oomkilled`, `docker.fm.dns-not-resolving-from-container`,
`docker.fm.cgroup-driver-mismatch`, `docker.fm.zombie-processes-leaking`,
plus several Linux + Devin networking/cert ones.

To re-apply (e.g., after a fresh DB clone):

```bash
pnpm corpus              # apply all migrations + rebuild FTS if any new
pnpm corpus --dry-run    # preview what would run
pnpm corpus --rebuild-fts  # force FTS rebuild even if no new migrations
```

Migrations are idempotent — re-running on an already-migrated DB does nothing.

The bootstrap installer (`./bootstrap.sh install`) runs `pnpm corpus` automatically
via the `corpus-migrate` module, so a fresh DevBox install ends up with the
enriched corpus state without manual steps.
