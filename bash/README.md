# bash/ — production diagnostic + remediation toolkit

Self-contained bash scripts for live debugging and fixing. One script per
failure case — drop-in-and-go. No PATH magic, no source dependencies.

## Layout

```
bash/
├── debug/      # search/diagnostic scripts — read-only, safe in prod
└── fix/        # remediation scripts — dry-run by default, --apply to execute
```

## Conventions

Every script:

- Self-contained — `bash bash/debug/oom.sh <c>` works from anywhere
- `--help` flag prints usage from the file's top doc comment
- `debug/*.sh` are **read-only** — never modify state, never restart processes, never send data off-box
- `fix/*.sh` are **dry-run by default** — print commands; pass `--apply` (or `-y`) to execute
- `fix/*.sh` print THREE blocks: TEMP fix, PERMANENT FIX (deployment config), VERIFY commands
- Most scripts take `<container>` as first arg; pass `''` (empty string) to run host-wide where supported

## debug/ — one script per failure class

| Script | What it diagnoses |
|---|---|
| `oom.sh <c>` | OOM kill — docker inspect + dmesg + cgroup memory.events + top RSS |
| `dns.sh <c> [host]` | DNS resolution — resolv.conf + /etc/hosts + dig + getent + resolvectl |
| `tls.sh <c> [host:port]` | TLS handshake + cert chain + container CA env vars + clock skew |
| `network.sh <c>` | Listening ports + interfaces + routes + conntrack + iptables FORWARD |
| `procs.sh <c>` | Process tree + zombies + D-state + top CPU/RSS + PID 1 check |
| `leak.sh <c> [n] [pat]` | RSS + fd count sampling over time (memory/fd leak detection) |
| `cgroup.sh <c>` | Cgroup memory.events + cpu.stat throttling + pids.max |
| `throttle.sh <c>` | CPU throttling specifically (DevBox classic — slow but %CPU low) |
| `disk.sh <c>` | df + du + iostat + per-process /proc/<pid>/io + inode usage |
| `secrets.sh <c>` | Devin Bug 101 — env vars + /run/repo_secrets check |
| `restart.sh <c>` | Restart count + die events + last logs + exit-code interpretation |
| `gateway.sh <c>` | Multi-symptom service gateway full dump (calls all the above) |

## fix/ — one script per remediation type

| Script | What it fixes |
|---|---|
| `env.sh <c> KEY VAL` | Set env var inside container (HUP to reload) |
| `hosts.sh <c> ip host` | Append /etc/hosts entry |
| `hosts-rm.sh <c> host` | Remove /etc/hosts entry |
| `dns.sh <c> dns_ip` | Prepend custom DNS to resolv.conf |
| `cabundle.sh <c> root inter` | Concat root + intermediate → /etc/ssl/custom/full-chain.pem |
| `cert-renew.sh <c> name [days]` | New self-signed cert (TEST USE ONLY) |
| `reload.sh <c> [pat]` | SIGHUP processes (graceful reload) |
| `restart-process.sh <c> [pat]` | Kill processes; PID 1 respawns |
| `restart-container.sh <c>` | docker restart <c> |
| `recreate-init.sh <c>` | Recipe to recreate with --init (zombie fix; manual) |
| `install-tools.sh <c>` | apt/apk install dig+openssl+curl+jq inside container |
| `prune.sh` | docker system prune -af (frees disk) |

## Workflow

### Single symptom

```bash
# 1. Diagnose (read-only, save output to notes/)
bash bash/debug/oom.sh staff-tls > notes/logs/$(date +%F-%H%M)-oom.log

# 2. Read it; figure out the fix
cat notes/logs/$(date +%F-%H%M)-oom.log

# 3. Apply fix (preview first — default is dry-run)
bash bash/fix/restart-container.sh staff-tls
bash bash/fix/restart-container.sh staff-tls --apply

# 4. Re-diagnose to verify
bash bash/debug/oom.sh staff-tls
```

### Multi-symptom (gateway 503 + DB + cache + auth all failing)

```bash
# Full diagnostic dump — read top to bottom, group failures by error CLASS
bash bash/debug/gateway.sh staff-tls > notes/logs/$(date +%F-%H%M)-gateway.log

# Three classes typically emerge: CA-trust, DNS, cert-rotation
# Apply per-class fixes:
bash bash/fix/cabundle.sh staff-tls /path/root.pem /path/inter.pem --apply
bash bash/fix/env.sh staff-tls NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply
bash bash/fix/dns.sh staff-tls 10.0.0.53 --apply
bash bash/fix/cert-renew.sh staff-tls metrics.corp.internal 365 --apply
```

## Output convention for piping to notes/

All scripts print sectioned output (`=== section name ===`). Pipe to
`notes/logs/YYYY-MM-DD-HHMM-<topic>.log` for archival. The `gateway.sh`
runner uses banner sections (`########`) so you can grep across multiple
sub-script outputs.

## Install on PATH (optional)

```bash
sudo ln -sf $(pwd)/bash/debug/oom.sh /usr/local/bin/dbg-oom
sudo ln -sf $(pwd)/bash/fix/env.sh   /usr/local/bin/fix-env
# etc — or use direnv to add bash/{debug,fix} to PATH per-repo
```

## Cross-references

- Keyword dispatchers (alternate UI): `practice/debug-tools/dprobe.sh`, `dfix.sh`
- Practice scenarios that produce these symptoms: `practice/<NN>-<name>.sh`
- Talk-track for narrating during interview: `cluely/06-talk-tracks.md`
- Failure-mode corpus (call from MCP): `mcp__domains-harness__ask "<symptom>"`
