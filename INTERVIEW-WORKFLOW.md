# Interview workflow — tabs, devices, and local repros

## Tab layout by device performance

You have four environments. Use them in the right order — don't fight
slow hardware, route work to where it's fast.

### Decision matrix

| Environment | Best for | Avoid for | Latency | Has Docker? |
|---|---|---|---|---|
| **DevBox cmdline** | Running containers, debug/fix scripts, `docker exec`, system inspection | Editing code, long MCP queries | Lowest | YES |
| **DevBox Claude** | MCP queries (`ask`, `lookup`, `playbook`), corpus search, talk-track lookup | Heavy file editing | Low | YES |
| **Linux Claude** | Local practice reps, git operations, file editing, bootstrap dev | Docker scenarios (if Docker unavailable locally) | Medium | Maybe |
| **VSCode Claude** | Reading/editing code, multi-file navigation, reviewing diffs | Running scripts, Docker, system diagnostics | Medium | No |

### Interview day tab layout (recommended)

```
Tab 1: DevBox cmdline     — PRIMARY. All docker/system commands here
Tab 2: DevBox cmdline     — ~/notes.md open in nano (RCA scratch)
Tab 3: DevBox Claude      — MCP queries only (ask, lookup, playbook)
Tab 4: (optional) VSCode  — code reading if needed
```

### Performance routing rules

1. **Container work → always DevBox cmdline.** Docker runs there. Zero latency.
   ```bash
   docker ps
   bash bash/debug/oom.sh $C
   bash bash/fix/env.sh $C KEY VAL --apply
   ```

2. **MCP corpus queries → DevBox Claude.** It has access to the repo and MCP server.
   ```
   ask "container exits 137"
   lookup "OOM"
   playbook "fm-docker-oom-001"
   ```

3. **Notes → DevBox cmdline Tab 2.** Separate tab, nano open, paste findings.
   ```bash
   nano ~/notes.md
   # or one-liner appends from Tab 1:
   echo "| 3 | cert dates | openssl x509 -dates | zero-day cert |" >> ~/notes.md
   ```

4. **Git / code reading → Linux Claude or VSCode.** Don't waste DevBox time on git.

5. **Never do MCP queries in DevBox cmdline.** Use Claude for that — it formats
   the structured output. Raw `pnpm harness ask ...` works but is harder to read.

### If DevBox is slow

- Drop to 2 tabs: cmdline (docker + notes) and Claude (MCP only)
- Don't run `gateway.sh` full dump — it calls 8 sub-scripts. Run targeted
  scripts instead: `oom.sh`, `dns.sh`, `tls.sh` individually
- Avoid `leak.sh` with default 30 samples (30s) — use `leak.sh $C 10` for quick check

### If local machine is slow

- Don't run practice scenarios locally — use DevBox for all Docker work
- Use VSCode only for reading code (not running anything)
- Keep Claude queries to DevBox Claude, not local Claude

## Local repro guide

### Before the interview (setup)

```bash
# 1. Clone and install (30 seconds)
git clone https://github.com/aaronstone2/Domains.git ~/repos/Domains
cd ~/repos/Domains
./bootstrap.sh --anthropic-key='sk-ant-YOUR-KEY' --launch

# 2. Verify everything works
docker ps                           # Docker is running
pnpm harness stats                  # Corpus is loaded (767 sources)
bash bash/debug/oom.sh --help       # Scripts are executable
cat ~/notes.md                      # Notes template was auto-created
```

### Quick repro: run a practice scenario

```bash
# Pick a scenario (priority order from PRIORITY-TABLE.md)
bash practice/28-env-var-empty.sh start     # Start scenario
docker ps                                    # Find container name
C=<container-name>                           # Set for all subsequent commands

# Debug (hands first)
bash bash/debug/secrets.sh $C               # Run matching debug script
bash bash/debug/oom.sh $C                   # ... or whichever matches

# Fix
bash bash/fix/env.sh $C KEY VALUE           # Dry-run first (default)
bash bash/fix/env.sh $C KEY VALUE --apply   # Then apply

# Verify + reveal
bash practice/28-env-var-empty.sh verify
bash practice/28-env-var-empty.sh reveal

# Cleanup
bash practice/28-env-var-empty.sh restore
```

### Quick repro: standalone debug (no scenario)

```bash
# Spin up any container
docker run -d --name test-app -p 8080:8080 node:22 node -e "
  const http = require('http');
  http.createServer((req, res) => res.end('ok')).listen(8080);
"

# Run debug scripts against it
C=test-app
bash bash/debug/procs.sh $C
bash bash/debug/network.sh $C
bash bash/debug/ulimits.sh $C node
bash bash/debug/cgroup.sh $C

# Cleanup
docker rm -f test-app
```

### Quick repro: test a fix script (safe)

All fix scripts are dry-run by default. Safe to test without `--apply`:

```bash
# See what it WOULD do (no state change)
bash bash/fix/dns.sh $C 10.0.0.53
bash bash/fix/env.sh $C NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem
bash bash/fix/cabundle.sh $C /tmp/root.pem /tmp/inter.pem

# Actually apply (only when ready)
bash bash/fix/dns.sh $C 10.0.0.53 --apply
```

### Interview day workflow (minute-by-minute)

```
0:00  ./bootstrap.sh finishes. Open 3 tabs.
0:01  Interviewer gives you the ticket. Paste key details into ~/notes.md
0:02  Run first 3 diagnostic commands from cheatsheet/muscle memory
0:04  If stuck: bash bash/debug/gateway.sh $C > notes/logs/dump.log
0:05  If still stuck: MCP ask "<exact error message>"
0:06  Follow MCP runbook, run commands, log results in notes
0:08  Formulate hypothesis. Run targeted fix script (dry-run first)
0:09  Apply fix. Verify.
0:10  Present RCA from ~/notes.md: root cause → fix → permanent fix
```

### Scenario → debug/fix script mapping (quick reference)

| Scenario | Debug script(s) | Fix script(s) |
|---|---|---|
| #28 env-var-empty | `secrets.sh` | `env.sh` |
| #06 docker-oom | `oom.sh`, `cgroup.sh` | `restart-container.sh` |
| #15 cpu-throttled | `throttle.sh`, `cgroup.sh` | — (raise quota) |
| #13 zombie-processes | `procs.sh` | `recreate-init.sh` |
| #19 corporate-ca | `tls.sh` | `cabundle.sh`, `env.sh` |
| #08 bad-resolv | `dns.sh` | `dns.sh`, `hosts.sh` |
| #24 fd-exhaustion | `ulimits.sh`, `leak.sh` | — (raise ulimit) |
| #07 docker-no-egress | `network.sh`, `dns.sh` | — (iptables/network fix) |
| #18 tls-cert | `tls.sh` | `cert-renew.sh` |
| #11 noisy-neighbor | `disk.sh` | `prune.sh` |
| #32 push-rejected | — | — (git perms) |
| #09 fleet-oom | `oom.sh`, `gateway.sh` | `restart-container.sh` |
| Multi-symptom | `gateway.sh` (runs all) | Per-class fixes |
