# PRINT-READY REFERENCE — Interview Day

> Print this entire file. ~20 pages. Covers everything you need at zero-latency lookup.

---

# PART 1: REPO STRUCTURE

```
Domains/
├── bootstrap.sh                    ← 30-second installer entry point
├── CLAUDE.md                       ← AI session instructions
├── INTERVIEW-WORKFLOW.md           ← Tab layout + device routing
├── interview-notes.template.md     ← RCA scratch (auto-copied to ~/notes.md)
├── cmd_history.txt                 ← 1000+ commands seeded into atuin Ctrl+R
│
├── bash/                           ← PRODUCTION DEBUG/FIX SCRIPTS
│   ├── debug/                      ← 13 read-only diagnostic scripts
│   │   ├── oom.sh                  ← OOMKilled + cgroup memory + VmSwap
│   │   ├── dns.sh                  ← resolv.conf + dig + getent + resolvectl
│   │   ├── tls.sh                  ← openssl s_client + cert chain + CA env
│   │   ├── network.sh              ← ss + ip + conntrack + iptables
│   │   ├── procs.sh                ← process tree + zombies + D-state
│   │   ├── leak.sh                 ← RSS + fd sampling over time
│   │   ├── cgroup.sh               ← memory.events + cpu.stat + pids.max
│   │   ├── throttle.sh             ← CPU throttle (slow but %CPU low)
│   │   ├── disk.sh                 ← df + du + iostat + inode usage
│   │   ├── secrets.sh              ← env vars + /run/repo_secrets check
│   │   ├── ulimits.sh              ← fd usage vs limit + EMFILE detection
│   │   ├── restart.sh              ← restart count + die events + exit codes
│   │   └── gateway.sh              ← RUNS ALL ABOVE (multi-symptom dump)
│   └── fix/                        ← 13 remediation scripts (dry-run default)
│       ├── env.sh                  ← set env var inside container
│       ├── hosts.sh / hosts-rm.sh  ← add/remove /etc/hosts entries
│       ├── dns.sh                  ← prepend DNS to resolv.conf
│       ├── cabundle.sh             ← concat root + intermediate CA
│       ├── cert-renew.sh           ← self-signed cert (TEST ONLY)
│       ├── reload.sh               ← SIGHUP processes (graceful)
│       ├── restart-process.sh      ← kill procs (PID 1 respawns)
│       ├── restart-container.sh    ← docker restart
│       ├── recreate-init.sh        ← recipe for --init (zombie fix)
│       ├── install-tools.sh        ← apt/apk install dig+openssl+curl+jq
│       └── prune.sh                ← docker system prune -af
│
├── cluely/                         ← TALK TRACKS + METHODOLOGY
│   ├── 01-cheatsheet.md            ← Single-page reference (exit codes, signals)
│   ├── 02-symptom-to-fm.md         ← Symptom → failure-mode-id mapping (351 fms)
│   ├── 03-top-failure-modes.md     ← Top 50 fms with full diag/fix inline
│   ├── 04-diagnostic-commands.md   ← 706 commands by category
│   ├── 05-methodology.md           ← USE/RED/Golden Signals/Off-CPU
│   ├── 06-talk-tracks.md           ← Literal scripts to read aloud
│   ├── 07-anti-patterns.md         ← What NOT to do or say
│   ├── 08-recovery.md              ← When things go sideways
│   └── RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md
│
├── practice/                       ← 32 SCENARIOS (start/verify/reveal/restore)
│   ├── PRIORITY-TABLE.md           ← All 32 ranked by Devin-relevance
│   ├── SCENARIO-PLAYBOOK.md        ← Symptom→dprobe→ask→dfix→talk-track
│   └── 01..32-*.sh                 ← Individual scenario scripts
│
├── packages/                       ← TS PACKAGES
│   ├── bootstrap/                  ← Modular installer (18 modules, ACID)
│   ├── harness/                    ← DuckDB corpus query engine
│   ├── harness-mcp/                ← MCP server (8 tools for Claude Code)
│   └── cli/                        ← pnpm domain/leaf/package commands
│
├── _db/
│   └── knowledge.duckdb            ← 767 sources, 1889 concepts, 415 fms
│
└── notes/                          ← LOCAL SCRATCH (gitignored)
    ├── logs/                       ← Paste raw command output here
    └── reports/                    ← RCA writeups
```

---

# PART 2: TAB LAYOUT (interview day)

```
Tab 1: DevBox cmdline     ← PRIMARY. All docker/system commands
Tab 2: DevBox cmdline     ← ~/notes.md open in nano
Tab 3: DevBox Claude      ← MCP queries only (ask, lookup, playbook)
```

| Task | Where | Why |
|------|-------|-----|
| docker exec, system inspection | Tab 1 (DevBox cmdline) | Docker runs here, zero latency |
| bash/debug/*.sh, bash/fix/*.sh | Tab 1 (DevBox cmdline) | Scripts need Docker access |
| RCA notes | Tab 2 (DevBox cmdline) | Separate tab, always visible |
| MCP ask/lookup/playbook | Tab 3 (DevBox Claude) | Structured output, formatted |
| Code reading | VSCode (optional) | Multi-file navigation |

**If DevBox is slow:** Drop to 2 tabs. Run targeted scripts (oom.sh, dns.sh) not gateway.sh.

---

# PART 3: INTERVIEW TIMELINE (minute by minute)

```
0:00  bootstrap.sh finishes → open 3 tabs
0:01  Paste ticket details into ~/notes.md
0:02  Run 2-3 first-response commands (from cheatsheet / muscle memory)
0:04  Still stuck? → bash bash/debug/gateway.sh $C > notes/logs/dump.log
0:05  Still stuck? → MCP: ask "<exact error message>"
0:06  Follow runbook, run commands, log results
0:08  Hypothesis formed → dry-run fix script → apply
0:09  Verify fix
0:10  Present RCA from ~/notes.md
```

---

# PART 4: EXIT CODE DECODER

| Code | Meaning | First check |
|-----:|---------|-------------|
| 0 | success | — |
| 1 | generic failure | stdout/stderr |
| 2 | usage / argv | --help parse |
| 125 | docker daemon error pre-start | bad image / daemon misconfig |
| 126 | command not executable | perms, wrong arch |
| 127 | command not found | typo, missing dep |
| **137** | **128 + SIGKILL — usually OOM** | `docker inspect .State.OOMKilled` |
| 139 | 128 + SIGSEGV — segfault | `coredumpctl list` |
| 143 | 128 + SIGTERM — graceful stop | usually normal |

Signal table: `128 + N` = killed by signal N

| N | Signal | Catchable? | Common cause |
|--:|--------|------------|--------------|
| 1 | HUP | yes | reload config |
| 2 | INT | yes | Ctrl+C |
| 9 | KILL | **NO** | OOM-killer or `kill -9` |
| 15 | TERM | yes | polite stop |

---

# PART 5: SYMPTOM → FIRST COMMAND

| Symptom | Run first | Then |
|---------|-----------|------|
| Container won't start | `docker logs $C \| tail -20` | `docker inspect $C \| jq '.[0].State'` |
| Exit 137 / OOMKilled | `docker inspect $C --format '{{.State.OOMKilled}}'` | `bash bash/debug/oom.sh $C` |
| DNS failure / ENOTFOUND | `cat /etc/resolv.conf` | `bash bash/debug/dns.sh $C host` |
| TLS / cert error | `echo \| openssl s_client -connect host:port` | `bash bash/debug/tls.sh $C host:port` |
| High CPU | `top -H -p $(pgrep -f app)` | `bash bash/debug/throttle.sh $C` |
| Disk full / ENOSPC | `df -h` | `bash bash/debug/disk.sh $C` |
| OOMKilled (host) | `dmesg -T \| grep -i oom` | `bash bash/debug/oom.sh` |
| Port conflict | `ss -tlnp \| grep PORT` | `lsof -i :PORT` |
| Permission denied | `ls -la /path` | `namei -l /path` |
| Zombies | `ps aux \| awk '$8=="Z"'` | `bash bash/debug/procs.sh $C` |
| Slow/hanging | `strace -cp PID` | `bash bash/debug/throttle.sh $C` |
| FD exhaustion / EMFILE | `ls /proc/PID/fd \| wc -l` | `bash bash/debug/ulimits.sh $C pattern` |
| Env var empty | `docker exec $C env \| grep KEY` | `bash bash/debug/secrets.sh $C` |
| Container restart loop | `docker inspect $C --format '{{.RestartCount}}'` | `bash bash/debug/restart.sh $C` |
| Slow but CPU low | `cat cgroup/cpu.stat \| grep throttled` | `bash bash/debug/throttle.sh $C` |
| Memory leak | `docker stats $C` (watch RSS) | `bash bash/debug/leak.sh $C 30 pattern` |
| Multi-symptom / unknown | `docker ps` + `docker logs $C` | `bash bash/debug/gateway.sh $C` |

---

# PART 6: SCENARIO → SCRIPT MAPPING

| # | Scenario | Debug script(s) | Fix script(s) | Time |
|---|----------|----------------|---------------|------|
| 28 | env-var-empty (Bug 101) | `secrets.sh` | `env.sh` | 12m |
| 06 | docker-oom | `oom.sh`, `cgroup.sh` | `restart-container.sh` | 12m |
| 15 | cpu-throttled | `throttle.sh`, `cgroup.sh` | — (raise quota) | 12m |
| 32 | push-rejected | — | — (git perms) | 10m |
| 19 | corporate-ca (App 101) | `tls.sh` | `cabundle.sh`, `env.sh` | 15m |
| 13 | zombie-processes | `procs.sh` | `recreate-init.sh` | 10m |
| 08 | bad-resolv (DNS) | `dns.sh` | `dns.sh`, `hosts.sh` | 12m |
| 24 | fd-exhaustion | `ulimits.sh`, `leak.sh` | — (raise ulimit) | 10m |
| 07 | docker-no-egress | `network.sh`, `dns.sh` | — (iptables fix) | 15m |
| 18 | tls-cert | `tls.sh` | `cert-renew.sh` | 12m |
| 11 | noisy-neighbor | `disk.sh` | `prune.sh` | 12m |
| 09 | fleet-oom | `oom.sh`, `gateway.sh` | `restart-container.sh` | 12m |
| 12 | version-skew | `gateway.sh` | — (redeploy) | 12m |

---

# PART 7: DEBUG SCRIPTS — USAGE

All read-only. Safe in prod. Pipe to `notes/logs/`.

```bash
C=<container>   # set once after docker ps

# Individual
bash bash/debug/oom.sh $C
bash bash/debug/dns.sh $C hostname
bash bash/debug/tls.sh $C host:port
bash bash/debug/network.sh $C
bash bash/debug/procs.sh $C
bash bash/debug/leak.sh $C 30 'node\|server'
bash bash/debug/cgroup.sh $C
bash bash/debug/throttle.sh $C
bash bash/debug/disk.sh $C
bash bash/debug/secrets.sh $C
bash bash/debug/ulimits.sh $C 'node\|server'
bash bash/debug/restart.sh $C

# Full dump (calls all above)
bash bash/debug/gateway.sh $C > notes/logs/$(date +%F-%H%M)-gateway.log
```

---

# PART 8: FIX SCRIPTS — USAGE

All dry-run by default. Add `--apply` to execute.

```bash
# Preview what it would do (safe)
bash bash/fix/env.sh $C NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem
bash bash/fix/dns.sh $C 10.0.0.53
bash bash/fix/cabundle.sh $C /path/root.pem /path/inter.pem

# Actually apply
bash bash/fix/env.sh $C NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply
bash bash/fix/dns.sh $C 10.0.0.53 --apply
bash bash/fix/cabundle.sh $C root.pem inter.pem --apply
bash bash/fix/cert-renew.sh $C hostname 365 --apply
bash bash/fix/hosts.sh $C 10.0.0.5 db.corp.internal --apply
bash bash/fix/hosts-rm.sh $C bad.host --apply
bash bash/fix/reload.sh $C nginx --apply
bash bash/fix/restart-process.sh $C 'node\|server' --apply
bash bash/fix/restart-container.sh $C --apply
bash bash/fix/install-tools.sh $C --apply
bash bash/fix/prune.sh --apply

# Manual recipe (never auto-applies)
bash bash/fix/recreate-init.sh $C
```

---

# PART 9: MCP HARNESS TOOLS

| Tool | When | Example |
|------|------|---------|
| `ask` | **Default.** Symptom → top fm + talk-track + diag/fix | `ask "exit 137"` |
| `lookup` | Browse when ask's top match is wrong | `lookup "OOM"` |
| `playbook` | Re-render specific fm by id | `playbook "docker.fm.exit-137-oomkilled"` |
| `concept` | Definition + edges for a primitive | `concept "cgroups"` |
| `related` | Walk relationship graph | `related "oom-killer"` |
| `cite` | Get canonical doc URL | `cite "docker memory limit"` |
| `stats` | Corpus inventory | `stats` |

**Shell fallback** (if MCP is down):
```bash
pnpm harness ask "<symptom>"
pnpm harness lookup "<query>"
```

**Direct DuckDB** (if harness is down):
```sql
duckdb _db/knowledge.duckdb
SELECT id, symptom FROM meta.all_failure_modes
WHERE symptom ILIKE '%keyword%' ORDER BY confidence DESC LIMIT 10;
```

---

# PART 10: TALK TRACKS (read these aloud)

## T-0: Opening (when interviewer describes the scenario)

> "Before I touch anything I want to make sure I understand the problem.
> Could you tell me **what you're seeing** — the literal symptom —
> **when it started**, and whether it's **user-impacting now** or just
> an alert? While you describe it I'll have my support harness open —
> it's a corpus I built of every Docker / Linux / k8s / Devin failure
> mode I've documented, and it gives me a structured runbook for almost
> any common symptom. I'll narrate as I go so you can see my reasoning."

## T+30: After picking the failure mode

> "OK, I'm hearing **[paraphrase the keyword]**. That maps to a known
> failure-mode class. Let me confirm with the cheapest diagnostic before
> I commit to a hypothesis."

## T+60: Before running a diagnostic

> "I'd start by **[paraphrase action]**. The expected outcome is
> **[paraphrase expect:]**. Want me to run that?"

After running:
> "That [confirms / contradicts] the [class] hypothesis."

## T+120: Proposing a fix

> "Based on the diagnostics, this looks like **[fm-id, in plain words]**.
> The fix has two paths:
>
> **(A)** the immediate one — [fix step 1]. Validation: [validate].
>     Rollback: [rollback].
>
> **(B)** the systemic one — [architectural fix].
>
> I'd start with (A) because [lower blast radius / reversible].
> Want me to apply it?"

## T+180: When stuck

> "What I'm seeing isn't matching the standard pattern. Let me apply
> USE method:
> - **Utilization** of [resource]: [number]
> - **Saturation**: [queue/wait metric]
> - **Errors**: [error count]
>
> First non-zero saturation or error = where I focus next."

## Closing

> "To recap: symptom was **[X]**. Root cause was **[Y]** — confirmed by
> **[diagnostic]**. Fix was **[Z]**, validated by **[step]**. Going
> forward, the systemic guard would be **[architectural fix]**."

---

# PART 11: METHODOLOGY QUICK REFERENCE

**USE Method** (per resource: CPU, mem, disk, net):

| | Metric | Tool |
|---|--------|------|
| **U**tilization | % busy | `vmstat 1` (us+sy), `iostat -xz 1` (%util) |
| **S**aturation | queue depth | `vmstat 1` (r col), `iostat` (avgqu-sz) |
| **E**rrors | error count | `dmesg`, `ip -s link` (errors) |

Rule: first resource with non-zero saturation or errors = bottleneck.

**RED Method** (per service): Rate, Errors, Duration.

**4 Golden Signals**: Latency, Traffic, Errors, Saturation.

**Off-CPU**: When on-CPU shows nothing → work is waiting.
- `strace -c -p PID` → syscall summary
- `perf record -e sched:sched_switch -g -- sleep 5`
- 95% in `futex_wait` → lock contention
- 95% in `read` on socket → upstream slow
- 95% in `read` on disk → I/O saturated

---

# PART 12: ANTI-PATTERNS (don't do these)

**Diagnostic:**
- ❌ Fix before diagnosing ("let me just bump memory")
- ❌ Dump 5 commands at once (interviewer can't follow)
- ❌ Fix without stating validation + rollback first
- ❌ Disable security controls as a "fix" (setenforce 0, chmod 777, --insecure)
- ❌ `rm -rf` to free space without identifying the offender
- ❌ Restart before reading logs

**Communication:**
- ❌ Apologize for using tools ("sorry, let me check my notes")
- ❌ Silent debugging (long pauses without narrating)
- ❌ "I'm not sure" / "It depends" (take a position, name the trade-off)
- ❌ Read harness output verbatim when it doesn't match
- ❌ Skip the clarifying question
- ❌ Forget to cite the source URL

**Pacing:**
- ❌ 15 min on wrong hypothesis (back up after 2-3 failed diagnostics)
- ❌ Optimizing the wrong layer (confirm layer before drilling)

---

# PART 13: RECOVERY (when things go sideways)

**If harness fails:** `pnpm harness ask "<symptom>"` → if that fails → `duckdb _db/knowledge.duckdb` with SQL query

**If you blank:** 1) Cheatsheet exit code table → 2) USE method fallback → 3) Ask a clarifying question (buys 30s)

**If wrong hypothesis for 15+ min:** "Diagnostics aren't lining up. Let me back up entirely. Re-categorizing the symptoms..."

**If running out of time:** Finish diagnostic > propose fix without root cause. "My hypothesis is X, fix would be Y, I'd validate with Z."

**If you don't know:** "I don't have direct experience with X, but I'd approach it with USE method on [resource]. The docs I'd reach for are [specific doc]."

---

# PART 14: EVAL CRITERIA SIGNALS (phrases to embed)

| Signal | Phrase |
|--------|--------|
| Curiosity | "Before I do X, I want to know..." |
| Hypothesis-driven | "My hypothesis is X; the cheapest test is Y" |
| Trade-off thinking | "Two paths: A has [property], B has [property]. I'd pick A because..." |
| Validation | "How will we know this worked? Specifically: [command]" |
| Rollback awareness | "Before I apply — rollback would be [Z]" |
| Citing | "Source for this is [URL from harness]" |

---

# PART 15: POSTMORTEM FRAMING (soft-skills questions)

4 rules for blameless:
1. Use **roles** not **names** ("the deploy engineer", not "Sarah")
2. Reframe "X forgot to" → "the process didn't catch"
3. List **contributing factors**, not "the cause"
4. Action items must be **system-level** (automation, canary), not "be more careful"

"Human error" is a symptom, not a root cause. Next why: "why was a human in a position to fail?" → automation gap.

---

# PART 16: CORPUS INVENTORY

| Domain | Sources | Concepts | Failure modes |
|--------|--------:|----------:|--------------:|
| docker | 104 | 400 | 74 |
| linux | 172 | 521 | 91 |
| k8s | 62 | 274 | 64 |
| devin | 327 | 319 | 37 |
| methodology | 44 | 121 | 28 |
| firecracker | 37 | 172 | 71 |
| ecs | 21 | 82 | 50 |
| **TOTAL** | **767** | **1889** | **415** |

All 415 failure modes have ≥3 diagnostic steps + ≥2 fix steps with concrete commands.

---

# PART 17: TOP 7 DEVIN TICKETS (most likely interview questions)

| # | Scenario | What it is | Key diagnostic |
|---|----------|-----------|----------------|
| 19 | corporate-ca-bundle | **Customer App 101** — corp proxy TLS | `openssl s_client`, `NODE_EXTRA_CA_CERTS` |
| 28 | env-var-empty | **Bug 101** — secrets not auto-injected | `/run/repo_secrets/.env.secrets` not sourced |
| 06 | docker-oom | Exit 137 / OOMKilled | `docker inspect .State.OOMKilled` + `memory.events` |
| 15 | cpu-throttled | "Slow but CPU low" DevBox | `cpu.stat nr_throttled` / `throttled_usec` |
| 32 | push-rejected | Git push blocked | Perms vs branch protection |
| 29 | tools-old-version | Snapshot fell back silently | `snapshot.build.failed` + `snapshot.fallback.activate` |
| 31 | agent-stuck-repeating | Context overflow | Repeated cmd patterns; Knowledge note fix |

---

# PART 18: PRACTICE SCENARIO COMMANDS

```bash
# Template for any scenario:
bash practice/NN-name.sh start      # Break the system
docker ps                            # Find container name
C=<container>                        # Set for all commands
bash bash/debug/<script>.sh $C      # Diagnose
bash bash/fix/<script>.sh $C --apply # Fix
bash practice/NN-name.sh verify     # Did it work?
bash practice/NN-name.sh reveal     # Show answer
bash practice/NN-name.sh restore    # Clean up
```

---

# PART 19: TRIAGE — PLATFORM BUG VS CUSTOMER ISSUE

## Decision tree

```
Can I reproduce on clean DevBox with default config?
  YES → PLATFORM BUG → escalate
  NO  → Reproduces ONLY with their config/code?
    YES → CUSTOMER ISSUE → fix it for them
    UNCLEAR → strip config to minimal repro, isolate the variable
```

## Three-point proof (before telling customer "it's on your side")

1. **REPRODUCE** with their config → confirms symptom is real
2. **FIX** one variable → shows what caused it
3. **VERIFY** fix holds → proves causation

## Common customer-side fix categories

| Category | Common problem | Fix pattern |
|----------|---------------|-------------|
| **environment.yaml** | Wrong section (initialize vs setup vs maintenance) | Move command to correct section |
| **environment.yaml** | Secrets not sourced | Add `source /run/repo_secrets/org/repo/.env.secrets` |
| **Dockerfile** | ENV not passed through | `docker run -e KEY=VAL` or compose `environment:` |
| **Dockerfile** | Zombies (no init) | Add `init: true` to compose or `--init` to run |
| **Script** | Windows line endings | `sed -i 's/\r$//' script.sh` |
| **Script** | Hardcoded paths | `sed -i 's\|/Users/foo\|/home/user/repos\|g'` |
| **Agent** | Stuck repeating | Add knowledge note with correct approach |
| **Agent** | Wrong tool version | Pin version in `initialize:` section |
| **TLS/Auth** | Corp CA not trusted | Add CA to system trust + set `NODE_EXTRA_CA_CERTS` |
| **TLS/Auth** | SSH key missing | Add as secret + `chmod 600` in setup |

## Communication templates

**It's their config:**
> "The issue is in your [config/script]. Specifically, [line] is [wrong].
> Fix: [change]. Want me to apply it?"

**It's our bug:**
> "This is on our side. Filed with engineering. Workaround to unblock you
> now: [workaround]. I'll follow up when the fix ships."

**Feature gap:**
> "Devin doesn't support [X] natively yet. Recommended approach: [pattern].
> I can help set it up. Flagging as a feature request."

## Escalation paths

| Root cause | Escalate to |
|-----------|-------------|
| Agent code (prompt, planning, tool use) | Deployed Engineering |
| DevBox infra (provisioning, networking) | Field IT / Platform Eng |
| Enterprise (SSO, RBAC, blueprints) | Enterprise Engineering |
| Customer's code/config | **Don't escalate — fix it yourself** |

## Escalation template

```
Customer impact: [critical/high/medium/low] — [N users, since when]
Repro steps: [exact steps + session ID]
Tried: [what you checked]
Ruled out: [what it's NOT]
Hypothesis: [best guess]
Workaround: [yes/no + what]
```

---

*End of print-ready reference. Good luck.*
