# debug-tools — interview-day fast diagnostic scripts

Two scripts. Drop-in-and-go for any container or host. Designed for the
"ask the MCP, paste the script, read the output" interview pattern.

## When to reach for which

| Symptom you (or the customer) describe | Use this |
|---|---|
| "Multiple things failing — gateway, multiple downstreams, complex" | `multi-symptom-probe.sh` (or `dprobe gateway`) |
| "Container exit 137 / OOMKilled / mem pressure" | `dprobe oom <container>` |
| "Slow but CPU% looks low" (DevBox classic) | `dprobe throttle <container>` |
| "TLS error — Node fails but curl works" | `dprobe tls <container> <host:port>` |
| "Can't reach .corp.internal hostnames / DNS errors" | `dprobe dns <container> <hostname>` |
| "Devin secret added but my env var is empty" | `dprobe secrets <container>` |
| "Container keeps restarting / restart loop" | `dprobe restart <container>` |
| "Process count looks weird / zombies / D-state" | `dprobe procs <container>` |
| "Memory growing over time / suspect leak" | `dprobe leak <container> [N samples]` |
| "Disk full / iowait / I/O slow" | `dprobe disk` |
| "I'm not sure yet, dump everything" | `multi-symptom-probe.sh` (full report) |

## The two scripts

### 1. `multi-symptom-probe.sh` — full diagnostic dump

Runs **13 sections** in one pass: env vars, /etc/hosts, resolv.conf, listening
ports, process tree, zombie count, app config files, log tails, SSL paths,
per-URL DNS+TCP+TLS triage, gateway memory leak watch, cgroup limits, fd counts.

Use when you have **N symptoms and don't know which class yet** — read the
output top-to-bottom; root causes usually jump out.

```bash
# Inside the container:
bash multi-symptom-probe.sh

# From the host without copying the file:
docker exec -i <container> bash < /path/to/multi-symptom-probe.sh

# From any host that can reach github raw:
curl -sL https://raw.githubusercontent.com/aaronstone2/Domains/main/practice/debug-tools/multi-symptom-probe.sh \
  | docker exec -i <container> bash
```

Read-only. Never modifies state. Fail-soft: every section continues even
if a tool is missing.

### 2. `dprobe` — keyword-driven dispatcher

When you've **already narrowed the problem class**, use the focused keyword
instead of the full dump:

```bash
dprobe <keyword> [container] [extra-args]
```

| Keyword | What it does | Args |
|---|---|---|
| `gateway` | Full multi-symptom dump (calls multi-symptom-probe.sh) | `<container>` |
| `oom` | OOM signals: cgroup events + dmesg + oom_score | `[container]` |
| `network` | Listening ports + interfaces + routes + conntrack | `[container]` |
| `dns` | resolv.conf + dig + getent for a hostname | `[container] [hostname]` |
| `tls` | Cert chain + dates + container CA env vars | `[container] [host:port]` |
| `procs` | Process tree + zombies + D-state + top CPU | `[container]` |
| `leak` | Memory + fd leak watch (continuous samples) | `<container> [N samples]` |
| `cgroup` | memory.events + cpu.stat (host + container) | `[container]` |
| `throttle` | CPU throttling specifically | `[container]` |
| `disk` | df + du + iostat + per-process I/O | `[container]` |
| `secrets` | Devin Bug 101 — repo-scoped secret check | `<container>` |
| `restart` | Restart count + die events + last logs | `<container>` |
| `help` | List keywords + examples | — |

Examples:

```bash
dprobe oom staff-tls
dprobe leak staff-tls 30
dprobe tls staff-tls auth.corp.internal:8443
dprobe dns staff-tls db.corp.internal
dprobe procs staff-tls
dprobe restart staff-tls
```

## Install — make `dprobe` available on PATH

One-time on any box:

```bash
sudo ln -sf $(pwd)/practice/debug-tools/dprobe.sh /usr/local/bin/dprobe
chmod +x practice/debug-tools/dprobe.sh
```

Now `dprobe oom staff-tls` works from any directory.

The bootstrap installer can do this automatically — see
`packages/bootstrap/src/modules/` (todo: add `debug-tools-symlink` module).

## Asking the harness MCP for the right tool

In claude (with harness MCP loaded):

```
ask the harness about "<symptom>"
```

Examples that should surface a script recommendation in the response:

| You ask | Harness should suggest |
|---|---|
| "container exit 137 OOMKilled" | `dprobe oom <c>` |
| "all 4 services failing in gateway" | `dprobe gateway <c>` |
| "Node TLS UNABLE_TO_GET_ISSUER_CERT" | `dprobe tls <c> <host:port>` |
| "Container restarting in a loop" | `dprobe restart <c>` |
| ".corp.internal hostnames not resolving" | `dprobe dns <c> <host>` |
| "memory keeps climbing per request" | `dprobe leak <c>` |
| "Devin secret env var empty" | `dprobe secrets <c>` |

## What each script DOES NOT do

These are READ-ONLY diagnostic tools. They **never**:
- Modify config files
- Restart processes
- Change env vars persistently
- Send anything off-box

Safe to run in production. Output is yours to interpret + propose fixes.

## Cross-references

- Full RCA walkthrough using these tools: [`cluely/RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md`](../../cluely/RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md)
- Practice scenarios these tools were designed to support: [`practice/PRIORITY-TABLE.md`](../PRIORITY-TABLE.md)
- All canonical commands grouped by domain: [`cmd_history.txt`](../../cmd_history.txt)
- Talk-track for diagnostic narration: [`cluely/06-talk-tracks.md`](../../cluely/06-talk-tracks.md)
