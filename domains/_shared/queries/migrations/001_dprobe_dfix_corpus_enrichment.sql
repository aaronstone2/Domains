-- Migration 001 — dprobe/dfix corpus enrichment + Devin scenarios 28-32 + multi-symptom gateway
-- Idempotent: every statement uses INSERT OR REPLACE / UPDATE WHERE.
-- Re-runnable: applying twice produces same final state.
--
-- Run via: pnpm corpus migrate (or: duckdb _db/knowledge.duckdb < this-file.sql)
-- Then rebuild FTS via _shared/queries/fts_index.sql (the migrate script does this automatically).

-- ============================================================
-- SECTION 1 — Register dprobe/dfix/multi-symptom-probe/playbook sources
-- in docker, devin, linux schemas.
-- ============================================================

INSERT OR REPLACE INTO docker.sources (id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes) VALUES
  ('domains-debug-dprobe', 'https://github.com/aaronstone2/Domains/blob/main/practice/debug-tools/dprobe.sh', 'dprobe — keyword diagnostic dispatcher', 'debug-tools', 'T1', 'internal', CURRENT_TIMESTAMP, NULL, 'manual', 'Maps symptom keyword → focused diagnostic. Read-only, safe in prod.'),
  ('domains-debug-dfix',   'https://github.com/aaronstone2/Domains/blob/main/practice/debug-tools/dfix.sh',   'dfix — keyword remediation dispatcher', 'debug-tools', 'T1', 'internal', CURRENT_TIMESTAMP, NULL, 'manual', 'Dry-run by default. --apply to mutate. Prints TEMP+PERMANENT+VERIFY.'),
  ('domains-debug-multi-symptom-probe', 'https://github.com/aaronstone2/Domains/blob/main/practice/debug-tools/multi-symptom-probe.sh', '13-section multi-symptom diagnostic dump', 'debug-tools', 'T1', 'internal', CURRENT_TIMESTAMP, NULL, 'manual', 'Use when N symptoms unknown class. Read-only. Pipe via docker exec -i.'),
  ('domains-practice-playbook', 'https://github.com/aaronstone2/Domains/blob/main/practice/SCENARIO-PLAYBOOK.md', 'Scenario playbook — symptom→dprobe→ask→dfix→talk-track', 'practice', 'T1', 'internal', CURRENT_TIMESTAMP, NULL, 'manual', 'All 32 scenarios mapped to MCP tool calls + diagnostic + fix + interview talk-track.');

INSERT OR REPLACE INTO devin.sources (id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes)
SELECT id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes
FROM docker.sources
WHERE id LIKE 'domains-%';

INSERT OR REPLACE INTO linux.sources (id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes)
SELECT id, url, title, subdomain, tier, license_note, fetched_at, content_hash, parser, notes
FROM docker.sources
WHERE id LIKE 'domains-%';

-- ============================================================
-- SECTION 2 — Documents (content_md) for the four sources
-- Inserted into docker.documents first; mirrored to devin.documents + linux.documents.
-- ============================================================

INSERT OR REPLACE INTO docker.documents (source_id, section_path, content_md) VALUES
('domains-debug-dprobe', 'overview', '# dprobe — keyword diagnostic dispatcher

Read-only, fail-soft. Drop-in script that runs the right diagnostic for a symptom keyword.

## Keywords

| Keyword | What it does | Args |
|---|---|---|
| `gateway` | Full multi-symptom dump (calls multi-symptom-probe.sh) | `<container>` |
| `oom` | OOM signals: cgroup memory.events + dmesg + oom_score | `[container]` |
| `network` | Listening ports + interfaces + routes + conntrack | `[container]` |
| `dns` | resolv.conf + dig + getent for a hostname | `[container] [hostname]` |
| `tls` | Cert chain + dates + container CA env vars (NODE_EXTRA_CA_CERTS, REQUESTS_CA_BUNDLE, SSL_CERT_FILE) | `[container] [host:port]` |
| `procs` | Process tree + zombies + D-state + top CPU | `[container]` |
| `leak` | Memory + fd leak watch (continuous samples) | `<container> [N samples]` |
| `cgroup` | memory.events + cpu.stat (host + container) | `[container]` |
| `throttle` | CPU throttling specifically (cpu.stat throttled_usec) | `[container]` |
| `disk` | df + du + iostat + per-process I/O | `[container]` |
| `secrets` | Devin Bug 101 — repo-scoped secret check (env + /run/secrets) | `<container>` |
| `restart` | Restart count + die events + last logs | `<container>` |

## Examples

```bash
dprobe oom staff-tls               # OOMKilled triage
dprobe leak staff-tls 30           # 30 samples of memory + fd
dprobe tls staff-tls auth.corp.internal:8443
dprobe dns staff-tls db.corp.internal
dprobe procs staff-tls             # zombies, D-state
dprobe restart staff-tls           # restart loop diagnosis
dprobe secrets <container>         # Devin Bug 101 — env var empty
dprobe gateway staff-tls           # full dump when N symptoms unclear
```

## Install

```bash
sudo ln -sf $(pwd)/practice/debug-tools/dprobe.sh /usr/local/bin/dprobe
chmod +x practice/debug-tools/dprobe.sh
```

## Safety

- Read-only — never modifies state, restarts processes, or sends data off-box.
- Safe to run in production.
- Output is yours to interpret + propose fixes.
- Pairs with `dfix` for remediation (which IS dry-run by default; needs --apply).
'),
('domains-debug-dfix', 'overview', '# dfix — keyword remediation dispatcher

Dry-run by default. Every keyword PRINTS what it would do; add `--apply` (or `-y`) to actually mutate.
Each fix prints THREE things: TEMP fix command, PERMANENT FIX recipe (docker-compose / k8s / Dockerfile), VERIFY commands.

## Keywords

| Keyword | What it does | Args |
|---|---|---|
| `env` | Set env var inside container (process restart needed) | `<c> <KEY> <VALUE>` |
| `hosts` | Append /etc/hosts entry | `<c> <ip> <host>` |
| `hosts-rm` | Remove /etc/hosts entry | `<c> <host>` |
| `dns` | Prepend custom DNS to resolv.conf | `<c> <dns_ip>` |
| `cabundle` | Concat root+intermediate → full-chain.pem | `<c> <root> <inter>` |
| `cert-renew` | New self-signed cert (test-only) | `<c> <name> [days]` |
| `reload` | SIGHUP processes (graceful reload) | `<c> [pattern]` |
| `restart-process` | Kill processes (PID 1 respawns) | `<c> [pattern]` |
| `restart-container` | docker restart `<c>` | `<c>` |
| `recreate-init` | Recreate with --init (zombie fix recipe) — NEVER auto-applies | `<c>` |
| `install-tools` | apt/apk install dig+openssl+curl+jq | `<c>` |
| `prune` | docker system prune -af (free disk) | — |

## Modes

- **Default (preview)** — print commands; nothing runs.
- **`--copy`** — paste-friendly raw commands for Windows→Linux workflow.
- **`--apply` / `-y`** — actually execute on Linux.

## Multi-symptom gateway scenario — all 4 fixes via dfix

```bash
# 1. Fix auth env var (point at root CA, not intermediate)
dfix env staff-tls NODE_EXTRA_CA_CERTS /etc/ssl/custom/root-ca.crt --apply

# 2. Add db + cache hosts entries
dfix hosts staff-tls 10.0.0.5 db.corp.internal    --apply
dfix hosts staff-tls 10.0.0.6 cache.corp.internal --apply

# OR set DNS upstream once instead of N hosts entries:
dfix dns staff-tls 10.0.0.53 --apply

# 3. Build proper full-chain bundle from root+intermediate:
dfix cabundle staff-tls /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply

# 4. Renew metrics cert (test-only — real fix is in cert pipeline):
dfix cert-renew staff-tls metrics.corp.internal 365 --apply

# Verify gateway is healthy:
curl -s http://localhost:5000 | jq ''.status''
```

## Safety guardrails

- Dry-run by default — see commands before they run
- All apply actions logged in bash history — Ctrl-R searchable via atuin
- `recreate-init` intentionally NEVER auto-applies (losing run-flags is worse than zombies)
- `prune` warns about removing all stopped containers + unused images

## Install

```bash
sudo ln -sf $(pwd)/practice/debug-tools/dfix.sh /usr/local/bin/dfix
chmod +x practice/debug-tools/dfix.sh
```
'),
('domains-debug-multi-symptom-probe', 'overview', '# multi-symptom-probe.sh — full diagnostic dump

13 sections in one pass. Use when you have N symptoms and don''t yet know which class.

## Sections

1. **env vars** — process environment (auth, secrets, CA paths)
2. **/etc/hosts** — manual host overrides
3. **resolv.conf** — DNS resolver config (nameserver, search domain)
4. **listening ports** — ss -tlnp / netstat
5. **process tree** — ps -eo pid,ppid,stat,cmd; pstree
6. **zombie count** — Z-state procs
7. **app config files** — common config paths inspected
8. **log tails** — last 50 lines of named app logs
9. **SSL paths** — NODE_EXTRA_CA_CERTS, REQUESTS_CA_BUNDLE, SSL_CERT_FILE, file existence + cert dates
10. **per-URL DNS+TCP+TLS triage** — getent + nc + openssl s_client per upstream
11. **gateway memory leak watch** — RSS sample loop (10s × 6)
12. **cgroup limits** — memory.max, memory.events, cpu.stat throttled_usec
13. **fd counts** — open files per pid

## Usage

```bash
# Inside the container:
bash multi-symptom-probe.sh

# From the host without copying the file:
docker exec -i <container> bash < /path/to/multi-symptom-probe.sh

# From any host that can reach github raw:
curl -sL https://raw.githubusercontent.com/aaronstone2/Domains/main/practice/debug-tools/multi-symptom-probe.sh \
  | docker exec -i <container> bash
```

## When to use vs dprobe keyword

Use **multi-symptom-probe.sh** (or `dprobe gateway`) when:
- Customer says "multiple things failing — gateway, downstreams, complex"
- You have N symptoms and don''t know which class yet
- You want one continuous output to read top-to-bottom

Use **dprobe <keyword>** when:
- Already narrowed to one symptom class
- Want focused output with less noise

## Safety

Read-only. Never modifies state. Fail-soft: every section continues if a tool is missing.
Safe in production.
'),
('domains-practice-playbook', 'overview', '# Practice scenario playbook — symptom→dprobe→ask→dfix→talk-track

Maps every practice scenario to the exact MCP tool call + diagnostic + fix command + interview talk-track.

## Tier 1 — common interview scenarios (drill these)

### Scenario 06: Container exit 137 / OOMKilled
- **Symptom**: container exited with code 137; logs end abruptly; `docker ps -a` shows Exited (137)
- **dprobe**: `dprobe oom <c>`
- **ask**: `mcp ask "container exit 137 OOMKilled"` → docker.fm.exit-137-oomkilled
- **dfix**: bump --memory limit (no dfix keyword — needs run flag)
- **talk-track**: "137 = SIGKILL by kernel OOM-killer when cgroup memory.max is exceeded. Diagnostic is `docker inspect <c> --format ''{{.State.OOMKilled}}''` + `cat /sys/fs/cgroup/.../memory.events`. Permanent fix: raise --memory in docker-compose or add memory request/limit in k8s pod spec."

### Scenario 09: Container DNS not resolving
- **Symptom**: `getent hosts X` fails inside container, works on host
- **dprobe**: `dprobe dns <c> <hostname>`
- **ask**: `mcp ask "container can''t resolve DNS"` → docker.fm.dns-not-resolving-from-container
- **dfix**: `dfix dns <c> 10.0.0.53 --apply` (prepend custom DNS)
- **talk-track**: "Docker uses embedded DNS at 127.0.0.11 which forwards to host''s resolv.conf. If host''s systemd-resolved is at 127.0.0.53, the chain is container→127.0.0.11→127.0.0.53→upstream. Permanent fix: add `dns: [10.0.0.53]` to docker-compose or set in /etc/docker/daemon.json."

### Scenario 15: Multi-symptom service gateway 503
- **Symptom**: gateway returns 503; DB unreachable; cache unreachable; auth failures; metrics intermittent
- **dprobe**: `dprobe gateway <c>` (full 13-section dump)
- **ask**: `mcp ask "gateway 503 multiple downstreams failing"` → docker.fm.multi-symptom-service-gateway
- **dfix**: 4 fixes — env CA path, hosts/dns, cabundle, cert-renew
- **talk-track**: "Multi-symptom — decompose by error code, not service. Group services by their error class. Auth-class failures share a CA-trust root cause; DB+cache class share a DNS root cause; metrics class shares a cert-rotation root cause. Three fixes for many symptoms."

### Scenario 19: Container TLS UNABLE_TO_GET_ISSUER_CERT
- **Symptom**: Node app fails TLS to internal service; curl works
- **dprobe**: `dprobe tls <c> <host:port>`
- **ask**: `mcp ask "Node TLS UNABLE_TO_GET_ISSUER_CERT"` → docker.fm.node-tls-issuer-untrusted
- **dfix**: `dfix env <c> NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply` + `dfix cabundle <c> root.crt intermediate.crt --apply`
- **talk-track**: "Node uses NODE_EXTRA_CA_CERTS env var, not the OpenSSL default. Multi-tier corp PKI needs root + intermediate concatenated in the bundle. Permanent fix: bake full-chain.pem into the image and set NODE_EXTRA_CA_CERTS in Dockerfile."

### Scenario 28: Devin Bug 101 — repo-scoped secret env var empty
- **Symptom**: Added secret in Devin Settings → Secrets but `echo $MY_SECRET` is empty inside DevBox
- **dprobe**: `dprobe secrets <c>`
- **ask**: `mcp ask "Devin secret env var empty"` → devin.fm.repo-scoped-secret-not-auto-injected
- **dfix**: nothing inside container — need Devin Settings change (set repo scope on the secret)
- **talk-track**: "Devin''s Org Secrets are global; Repo Secrets are scoped to a single repo. If you added the secret as Org-level but the repo doesn''t inherit, the env var won''t be in the DevBox. Fix: open Devin Settings → Secrets → click the secret → confirm ''available to'' includes this repo."

## Tier 2 — runtime debugging (compressed)

| # | Scenario | dprobe | ask | dfix |
|---|---|---|---|---|
| 02 | container restart loop | `dprobe restart <c>` | `mcp ask "container restart loop"` | `dfix restart-container <c> --apply` |
| 04 | CPU throttled despite low %util | `dprobe throttle <c>` | `mcp ask "CPU throttled cgroup low %util"` | (raise --cpus or remove cpu quota) |
| 08 | container can''t reach internet | `dprobe network <c>` + `dprobe dns <c>` | `mcp ask "container no egress"` | `dfix dns <c> ...` or sysctl ip_forward |
| 11 | zombie processes accumulating | `dprobe procs <c>` | `mcp ask "zombie processes container"` | `dfix recreate-init <c>` (manual apply) |
| 13 | memory leak — RSS climbing | `dprobe leak <c> 30` | `mcp ask "container memory leak"` | code fix; bump --memory as bandaid |
| 17 | disk full inside container | `dprobe disk <c>` | `mcp ask "disk full container"` | `dfix prune` |
| 24 | cgroup driver mismatch (k8s) | `dprobe cgroup <c>` | `mcp ask "cgroup driver mismatch kubelet"` | edit /etc/docker/daemon.json + restart |

## Cross-references

- Full RCA walkthrough using these tools: `cluely/RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md`
- All canonical commands grouped by domain: `cmd_history.txt`
- Talk-track for diagnostic narration: `cluely/06-talk-tracks.md`
- dprobe source: `practice/debug-tools/dprobe.sh`
- dfix source: `practice/debug-tools/dfix.sh`
');

-- Mirror docs into devin + linux schemas
INSERT OR REPLACE INTO devin.documents (source_id, section_path, content_md)
SELECT source_id, section_path, content_md
FROM docker.documents WHERE source_id LIKE 'domains-%';

INSERT OR REPLACE INTO linux.documents (source_id, section_path, content_md)
SELECT source_id, section_path, content_md
FROM docker.documents WHERE source_id LIKE 'domains-%';

-- ============================================================
-- SECTION 3 — New Devin failure_modes for scenarios 28-32
-- ============================================================

INSERT OR REPLACE INTO devin.failure_modes (id, symptom, error_patterns, root_cause_class, affected_concepts, diagnostic_steps, fix_steps, confidence, last_verified, source_ids) VALUES
(
  'devin.fm.repo-scoped-secret-not-auto-injected',
  'Devin Bug 101 — secret added in Settings but env var is empty inside DevBox',
  ['echo $MY_SECRET shows empty', 'process.env.MY_SECRET undefined', 'authentication fails with 401 from internal service', 'curl ... -H "Authorization: Bearer $TOKEN" returns 401'],
  'devin-secrets-scope-mismatch',
  ['devin.secrets', 'devin.devbox-env', 'devin.org-vs-repo-scope'],
  [
    {step: 1, action: 'Confirm env var is empty inside DevBox', command: 'echo "MY_SECRET=${MY_SECRET:-EMPTY}"', expected: 'EMPTY confirms missing — proceed', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Run dprobe secrets to dump full env + /run/secrets', command: 'dprobe secrets <container>', expected: 'Lists all secret-shaped env vars + /run/secrets contents — find the gap', source_id: 'domains-debug-dprobe'},
    {step: 3, action: 'Verify secret exists in Devin Org Secrets vs Repo Secrets', command: '# Open Devin web UI → Settings → Secrets → click MY_SECRET', expected: '"Available to" lists THIS repo (or "All repos")', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'Confirm blueprint references the secret if needed', command: 'cat .devin/blueprint.yaml | grep -i secret', expected: 'No env-var-rename indirection that drops the secret', source_id: 'domains-practice-playbook'}
  ],
  [
    {step: 1, action: 'Add the repo to the secret scope in Devin Settings', command: '# Devin web UI → Settings → Secrets → MY_SECRET → "Available to" → add this repo', validation: 'Restart session; echo $MY_SECRET shows the value', rollback: 'Remove the repo from scope', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'For one-off testing inside current container, set the env var manually', command: 'dfix env <container> MY_SECRET <value> --apply', validation: 'echo $MY_SECRET inside container shows value (only persists for this container life)', rollback: 'restart container — env var clears', source_id: 'domains-debug-dfix'},
    {step: 3, action: 'Permanent — bake secret reference into blueprint with explicit scope', command: '# .devin/blueprint.yaml: secrets:\n  - name: MY_SECRET\n    scope: repo', validation: 'New session has env var without manual setup', rollback: 'remove secrets: block', source_id: 'domains-practice-playbook'}
  ],
  0.95,
  DATE '2026-05-04',
  ['domains-practice-playbook', 'domains-debug-dprobe', 'domains-debug-dfix']
),
(
  'devin.fm.snapshot-fallback-after-build-failure',
  'Devin session boots from old snapshot after blueprint changes — new dependencies missing',
  ['npm: command not found / package not installed despite blueprint adding it', 'pnpm install runs at session start instead of being preinstalled', 'session start takes 60-120s instead of <10s', 'changes to blueprint.yaml not reflected in DevBox'],
  'devin-snapshot-build-failed-silent-fallback',
  ['devin.snapshot', 'devin.blueprint', 'devin.devbox-boot', 'devin.cold-start'],
  [
    {step: 1, action: 'Check Devin Settings → Snapshots tab for the latest build status', command: '# Devin web UI → Settings → Snapshots → look at "Last build" timestamp + status', expected: '"Failed" or "Skipped" — fallback to previous snapshot in effect', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Inspect the build log for the failed step', command: '# Devin web UI → Snapshots → click failed build → expand stage logs', expected: 'A specific RUN/install line that errored — usually network or missing system package', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'Inside DevBox, confirm what snapshot you actually got', command: 'ls -la /tmp/.devin-snapshot-id 2>/dev/null; cat /etc/os-release; which node && node --version', expected: 'Mismatch with what blueprint says → confirms fallback', source_id: 'domains-practice-playbook'}
  ],
  [
    {step: 1, action: 'Fix the failing build step (usually missing apt package, network timeout, or wrong path)', command: '# Edit .devin/blueprint.yaml: add missing apt-get dep, increase timeout, fix path', validation: 'Trigger rebuild; new build status = Succeeded', rollback: 'git revert blueprint changes', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Use --snapshot-build flag in bootstrap to force strict mode (no soft-fail)', command: './bootstrap.sh install --snapshot-build', validation: 'Build aborts on any module failure rather than continuing', rollback: 'omit --snapshot-build flag', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'For a working session right now without rebuild — install missing tools manually', command: 'dfix install-tools <container> --apply', validation: 'dig + openssl + curl + jq present in this container', rollback: 'apt-get remove the installed tools', source_id: 'domains-debug-dfix'}
  ],
  0.85,
  DATE '2026-05-04',
  ['domains-practice-playbook', 'domains-debug-dfix']
),
(
  'devin.fm.nat-gateway-idle-timeout-disconnects',
  'Long-running session loses internal-service connections after N minutes idle — NAT gateway timeout',
  ['curl works initially then hangs after idle period', 'connection: read ECONNRESET / EPIPE after long idle', 'long-poll WebSocket drops at predictable intervals (~350s, ~5min, ~15min)', 'database connection pool errors after period of low traffic'],
  'devin-cloud-nat-idle-timeout',
  ['devin.networking', 'devin.devbox-egress', 'devin.nat-gateway', 'devin.long-running-session', 'tcp.keepalive'],
  [
    {step: 1, action: 'Reproduce: open long-lived connection, leave idle, watch for disconnect', command: '# in DevBox: nc -v internal-svc.corp.internal 8080  (then leave idle 6+ min)', expected: 'Connection drops cleanly with no FIN — silent NAT timeout signature', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Check current TCP keepalive settings', command: 'sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes', expected: 'Default tcp_keepalive_time=7200 (2h) — way past NAT timeout (~350s for AWS NAT GW)', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'Confirm direction — outbound from DevBox is the gateway path', command: 'ip route get 1.1.1.1', expected: 'Route shows the public egress interface', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'For HTTP clients, capture timing to confirm idle-then-fail pattern', command: 'curl -v --max-time 600 https://internal-svc.corp.internal/long-poll', expected: 'Stalls then times out around the NAT idle window', source_id: 'domains-practice-playbook'}
  ],
  [
    {step: 1, action: 'Lower TCP keepalive at OS level so kernel sends probes before NAT timeout', command: 'echo "net.ipv4.tcp_keepalive_time=120" | sudo tee /etc/sysctl.d/99-devin-keepalive.conf; echo "net.ipv4.tcp_keepalive_intvl=30" | sudo tee -a /etc/sysctl.d/99-devin-keepalive.conf; echo "net.ipv4.tcp_keepalive_probes=3" | sudo tee -a /etc/sysctl.d/99-devin-keepalive.conf; sudo sysctl --system', validation: 'sysctl -a | grep keepalive_time → 120; long-idle connections survive', rollback: 'rm /etc/sysctl.d/99-devin-keepalive.conf; sudo sysctl --system', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'In application code, enable TCP keepalive on long-lived sockets', command: '# Node: socket.setKeepAlive(true, 60000)\n# Python: sock.setsockopt(SOL_SOCKET, SO_KEEPALIVE, 1)\n# pg/redis: configure pool with keepalive_idle option', validation: 'long-idle queries / WS messages survive', rollback: 'remove setKeepAlive call', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'For HTTP libraries, enable connection pooling with health-check on reuse', command: '# Node fetch: agent: new https.Agent({keepAlive: true, keepAliveMsecs: 30000})', validation: 'requests after idle period succeed without new TCP handshake', rollback: 'use default agent', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'Bake the sysctl into the blueprint so every session inherits it', command: '# .devin/blueprint.yaml initialize step: copy sysctl.d file or use boot-script', validation: 'New DevBox boots with low keepalive', rollback: 'remove from blueprint', source_id: 'domains-practice-playbook'}
  ],
  0.85,
  DATE '2026-05-04',
  ['domains-practice-playbook']
),
(
  'devin.fm.long-session-context-overflow-loop',
  'Devin spirals re-reading the same files; loops without progress; ACU burn climbs',
  ['session timeline shows same file read 5+ times', 'ACU usage climbs but no PR / commit advances', 'Devin says "let me re-check the X file" repeatedly', 'context window saturated — old reasoning evicted then re-derived'],
  'devin-context-saturation-thrash',
  ['devin.session-runtime', 'devin.acu-budget', 'devin.context-management', 'devin.task-scoping'],
  [
    {step: 1, action: 'Open session timeline and look for repetition pattern', command: '# Devin web UI → Session → Timeline → look for same tool call repeated with no new info', expected: '"read file X" 5+ times in a row, or "ran test, ran same test, ran same test"', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Check current ACU burn rate', command: '# Devin web UI → Session → Cost — compare ACUs/min vs progress (commits, PRs)', expected: '>5 ACU/min with zero forward progress = thrash', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'Inspect the Plan if visible — is it stable or churning?', command: '# Devin web UI → Plan tab', expected: 'Plan rewritten every iteration = unstable; consistent plan = converging', source_id: 'domains-practice-playbook'}
  ],
  [
    {step: 1, action: 'Stop Devin and reset with a smaller, more concrete task', command: '# Devin web UI → Stop session → New session with narrowed scope (one file or one test)', validation: 'New session completes the narrowed task in <30 ACUs', rollback: 'reopen original session — but ACU budget already burned', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Add a Knowledge entry that documents the file structure / code map', command: '# Devin web UI → Settings → Knowledge → add "file map: X handles Y, Z handles W"', validation: 'Devin uses the map and stops re-reading source to re-derive the structure', rollback: 'delete the Knowledge entry', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'For very long tasks, break into sub-sessions with explicit handoffs', command: '# Each session = one PR; explicitly tell Devin "this session ends when PR is opened"', validation: 'Sessions stay <50 ACUs each, total cost predictable', rollback: 'go back to one mega-session', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'If ACU runaway is institutional, set per-session cap in Settings', command: '# Devin web UI → Settings → Limits → set max ACUs per session', validation: 'Sessions auto-pause at cap, asking for approval to continue', rollback: 'remove the cap', source_id: 'domains-practice-playbook'}
  ],
  0.80,
  DATE '2026-05-04',
  ['domains-practice-playbook']
),
(
  'devin.fm.git-push-blocked-by-branch-protection',
  'Devin completes work but git push is rejected — branch protection / required reviews / required status check',
  ['remote: error: GH006: Protected branch update failed', 'remote: required status check "ci/lint" not satisfied', 'remote: At least 1 approving review is required', 'Pull request creation failed: required reviewers not set', '! [remote rejected] feature -> feature (protected branch hook declined)'],
  'devin-github-protection-rule-blocked',
  ['devin.github-app', 'github.branch-protection', 'github.required-reviews', 'devin.pr-flow'],
  [
    {step: 1, action: 'Inspect the exact rejection reason from session log', command: '# Devin web UI → Session log → search "remote: " or "rejected"', expected: 'Specific GH00X code or rule name (e.g. "Require status checks", "Require pull request reviews")', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'Confirm Devin GitHub App has write access to repo + bypass-protection if needed', command: '# GitHub repo → Settings → Integrations → Devin app → permissions', expected: 'Read+Write on Code, Pull Requests, Statuses; bypass list may need updating', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'List active branch protection rules', command: 'gh api repos/<owner>/<repo>/branches/main/protection 2>/dev/null | jq', expected: 'Shows required_status_checks, required_pull_request_reviews, restrictions', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'For required-status-check failure, check which checks failed', command: 'gh pr checks <pr-number>', expected: 'Lists each check + status; failing ones marked X', source_id: 'domains-practice-playbook'}
  ],
  [
    {step: 1, action: 'For required-reviews — switch Devin to PR flow (not direct push to protected branch)', command: '# Devin Knowledge: "Always open PRs against main; never push directly. Branch naming: devin/<task-slug>"', validation: 'Next session opens PR instead of pushing; PR triggers required reviews', rollback: 'remove the Knowledge entry', source_id: 'domains-practice-playbook'},
    {step: 2, action: 'For required-status-check failure — wait for CI then re-push or trigger CI fix', command: 'gh pr checks <pr> --watch  # then if failure: investigate + push fix commit', validation: 'All required checks green; PR mergeable', rollback: 'close PR if check is unfixable', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'For required-reviewers — add Devin app or a maintainer to the bypass list, OR have Devin request review explicitly', command: 'gh pr edit <pr> --add-reviewer <human-reviewer>  # or for bypass: GitHub repo → Settings → Branches → Edit rule → "Allow specified actors to bypass"', validation: 'Reviewer added; PR can merge after approval', rollback: 'gh pr edit --remove-reviewer; remove from bypass list', source_id: 'domains-practice-playbook'},
    {step: 4, action: 'For permanent — document the contribution flow in repo CONTRIBUTING.md so Devin reads it', command: '# CONTRIBUTING.md: "All changes via PR. CI must pass: ci/lint, ci/test. 1 human review required."', validation: 'New Devin sessions follow the convention without retry', rollback: 'remove CONTRIBUTING.md guidance', source_id: 'domains-practice-playbook'}
  ],
  0.90,
  DATE '2026-05-04',
  ['domains-practice-playbook']
);

-- ============================================================
-- SECTION 4 — New docker.failure_mode for multi-symptom service gateway
-- ============================================================

INSERT OR REPLACE INTO docker.failure_modes (id, symptom, error_patterns, root_cause_class, affected_concepts, diagnostic_steps, fix_steps, confidence, last_verified, source_ids) VALUES
(
  'docker.fm.multi-symptom-service-gateway',
  'Service gateway returns 503; multiple downstream classes failing simultaneously (auth + db + cache + metrics)',
  ['{"status":"degraded","downstreams":["auth:failed","db:unreachable","cache:unreachable"]}', 'curl http://localhost:5000 → 503 Service Unavailable', 'Node TLS UNABLE_TO_GET_ISSUER_CERT_LOCALLY on auth.corp.internal', 'getent hosts db.corp.internal → no result', 'cert verify failed on metrics.corp.internal'],
  'multi-class-symptoms-decompose-by-error',
  ['docker.networking.dns', 'docker.tls.issuer-cert', 'docker.cgroup.memory', 'docker.config.env', 'corp-pki.full-chain', 'multi-symptom-debugging-methodology'],
  [
    {step: 1, action: 'Run dprobe gateway for full 13-section dump', command: 'dprobe gateway <container>', expected: 'Output groups env vars, hosts, resolv.conf, ports, processes, log tails, SSL paths, per-URL probe, cgroup, fd', source_id: 'domains-debug-dprobe'},
    {step: 2, action: 'Group failures by ERROR CODE not by service', command: '# read the dump; tag each downstream failure with its error class (CA-trust, DNS, cert-rotation)', expected: 'Three classes: auth=CA-trust; db+cache=DNS; metrics=cert-rotation', source_id: 'domains-practice-playbook'},
    {step: 3, action: 'For auth class — inspect NODE_EXTRA_CA_CERTS', command: 'docker exec <c> sh -c "echo $NODE_EXTRA_CA_CERTS; openssl x509 -in $NODE_EXTRA_CA_CERTS -noout -subject -issuer"', expected: 'Path is intermediate-only, not root+intermediate (or path doesn''t exist)', source_id: 'domains-debug-multi-symptom-probe'},
    {step: 4, action: 'For DNS class — confirm hostnames don''t resolve', command: 'docker exec <c> sh -c "getent hosts db.corp.internal; getent hosts cache.corp.internal"', expected: 'No output for both → DNS does not have these records', source_id: 'docker-cli-container-run'},
    {step: 5, action: 'For metrics class — check cert validity', command: 'docker exec <c> openssl s_client -connect metrics.corp.internal:8443 -servername metrics.corp.internal -showcerts </dev/null 2>&1 | openssl x509 -noout -dates', expected: 'notAfter date in the past — cert expired', source_id: 'domains-debug-multi-symptom-probe'},
    {step: 6, action: 'Watch RSS climb for memory leak symptom', command: 'dprobe leak <container> 30', expected: 'RSS climbs ~10MB/sample = leak; flat = not a leak', source_id: 'domains-debug-dprobe'}
  ],
  [
    {step: 1, action: 'Fix CA bundle — concat root + intermediate', command: 'dfix cabundle <container> /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply', validation: 'curl --cacert /etc/ssl/custom/full-chain.pem https://auth.corp.internal:8443/health → 200', rollback: 'restore previous bundle from backup', source_id: 'domains-debug-dfix'},
    {step: 2, action: 'Point Node at the full-chain bundle', command: 'dfix env <container> NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply', validation: 'restart node process; auth class downstream goes from "failed" → "ok"', rollback: 'restore previous env', source_id: 'domains-debug-dfix'},
    {step: 3, action: 'Add hosts entries for missing internal DNS records (or set DNS upstream)', command: 'dfix hosts <container> 10.0.0.5 db.corp.internal --apply; dfix hosts <container> 10.0.0.6 cache.corp.internal --apply', validation: 'getent hosts succeeds; curl from container succeeds', rollback: 'dfix hosts-rm <container> db.corp.internal --apply', source_id: 'domains-debug-dfix'},
    {step: 4, action: 'OR set custom DNS once instead of N hosts entries', command: 'dfix dns <container> 10.0.0.53 --apply', validation: 'all .corp.internal hostnames resolve', rollback: 'restore /etc/resolv.conf from backup', source_id: 'domains-debug-dfix'},
    {step: 5, action: 'Renew expired metrics cert (dev only — real fix is in cert pipeline)', command: 'dfix cert-renew <container> metrics.corp.internal 365 --apply', validation: 'openssl s_client → notAfter in future', rollback: 'restore old cert', source_id: 'domains-debug-dfix'},
    {step: 6, action: 'Verify gateway healthy', command: 'curl -s http://localhost:5000 | jq .status', validation: 'returns "healthy" with all downstream classes "ok"', rollback: NULL, source_id: 'domains-practice-playbook'},
    {step: 7, action: 'Permanent — bake fixes into docker-compose.yml + image', command: '# docker-compose.yml: env block sets NODE_EXTRA_CA_CERTS to baked-in /etc/ssl/full-chain.pem; dns: [10.0.0.53]; volumes mount renewed certs from cert-pipeline volume', validation: 'docker compose down && up --build → gateway boots healthy without manual fixes', rollback: 'git revert', source_id: 'domains-practice-playbook'}
  ],
  0.92,
  DATE '2026-05-04',
  ['domains-practice-playbook', 'domains-debug-dprobe', 'domains-debug-dfix', 'domains-debug-multi-symptom-probe']
);

-- ============================================================
-- SECTION 5 — Enrich existing failure_modes with dprobe/dfix steps
-- Idempotent: only appends if dprobe/dfix not already present.
-- ============================================================

-- docker.fm.exit-137-oomkilled
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe oom for fast triage (cgroup memory.events + dmesg + oom_score)', command: 'dprobe oom <container>', validation: 'Output shows oom_kill counter from memory.events + recent dmesg OOM lines', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'For continuous monitoring use dprobe leak (sample RSS over time)', command: 'dprobe leak <container> 30', validation: 'Confirms whether RSS climbs (leak) or hits ceiling fast (just under-sized)', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.exit-137-oomkilled'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- docker.fm.dns-not-resolving-from-container
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe dns for fast triage (resolv.conf + dig + getent for a hostname)', command: 'dprobe dns <container> <hostname>', validation: 'Shows nameserver chain + whether dig succeeds at each hop', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix dns to prepend custom DNS upstream', command: 'dfix dns <container> 10.0.0.53 --apply', validation: 'getent hosts <hostname> succeeds inside container', rollback: 'restore /etc/resolv.conf from backup', source_id: 'domains-debug-dfix'},
    {step: 101, action: 'OR add specific hosts entry if only one host fails', command: 'dfix hosts <container> <ip> <hostname> --apply', validation: 'curl from container to hostname succeeds', rollback: 'dfix hosts-rm <container> <hostname> --apply', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.dns-not-resolving-from-container'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- docker.fm.container-no-egress-umbrella
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe network for fast triage (listening ports + interfaces + routes + conntrack)', command: 'dprobe network <container>', validation: 'Routes show default via gateway; interfaces UP; conntrack populated', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.container-no-egress-umbrella'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- docker.fm.cgroup-driver-mismatch
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe cgroup for fast triage (memory.events + cpu.stat from host + container)', command: 'dprobe cgroup <container>', validation: 'Output shows cgroup hierarchy + which driver is active', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.cgroup-driver-mismatch'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- docker.fm.zombie-processes-leaking
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe procs for fast triage (process tree + zombies + D-state + top CPU)', command: 'dprobe procs <container>', validation: 'Lists Z-state and D-state procs; PID 1 cmd shown', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix recreate-init recipe (manual --apply only — never auto)', command: 'dfix recreate-init <container>  # prints recipe; user runs the docker run --init manually', validation: 'New container has tini at PID 1; zombies reaped', rollback: 'recreate without --init', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.zombie-processes-leaking'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- docker.fm.dockerd-tls-cert-expired
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe tls for fast triage (cert chain + dates + container CA env vars)', command: 'dprobe tls <container> <host:port>', validation: 'Shows cert dates + which CA env vars are set inside container', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix cabundle to assemble proper full-chain bundle from root + intermediate', command: 'dfix cabundle <container> /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply', validation: 'curl --cacert <bundle> https://<host:port> works', rollback: 'restore previous bundle', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'docker.fm.dockerd-tls-cert-expired'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- disk fms
UPDATE docker.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe disk for fast triage (df + du + iostat + per-process I/O)', command: 'dprobe disk <container>', validation: 'Shows where the bytes went; iostat reveals iowait', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix prune to free disk (warns about removing all stopped containers + unused images)', command: 'dfix prune --apply', validation: 'docker system df reports significantly less', rollback: 'cannot rollback prune; warn before applying', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id IN ('docker.fm.disk-full-but-df-shows-free', 'docker.fm.disk-full-overlay2-leaked', 'docker.fm.containerd-content-store-disk-fill')
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- linux.fm.cgroup-memory-oom-kill
UPDATE linux.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe oom for fast triage (cgroup memory.events + dmesg + oom_score)', command: 'dprobe oom <container>', validation: 'Output shows cgroup oom_kill counter + dmesg OOM lines + per-pid oom_score', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'linux.fm.cgroup-memory-oom-kill'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- linux.fm.systemd-resolved-stub-loops
UPDATE linux.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe dns for fast triage (resolv.conf + dig + getent for a hostname)', command: 'dprobe dns <container> <hostname>', validation: 'Shows resolver chain - if 127.0.0.53 in resolv.conf, suspect systemd-resolved', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix dns to point at upstream DNS instead of stub', command: 'dfix dns <container> 8.8.8.8 --apply', validation: 'getent hosts works without going through 127.0.0.53', rollback: 'restore /etc/resolv.conf from backup', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'linux.fm.systemd-resolved-stub-loops'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- linux.fm.systemd-unit-restart-loop
UPDATE linux.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe restart for fast triage (restart count + die events + last logs)', command: 'dprobe restart <container>  # for systemd unit: equivalent is systemctl status + journalctl -u', validation: 'Shows last N restart timestamps + last error', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'linux.fm.systemd-unit-restart-loop'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- devin.fm.internal-svc-cert-untrusted + devin.fm.session-cant-reach-internal-svc
UPDATE devin.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe tls for fast triage (cert chain + dates + container CA env vars)', command: 'dprobe tls <container> <host:port>', validation: 'Shows whether NODE_EXTRA_CA_CERTS / REQUESTS_CA_BUNDLE / SSL_CERT_FILE are set + cert dates', rollback: NULL, source_id: 'domains-debug-dprobe'},
    {step: 100, action: 'Apply dfix cabundle to assemble corp PKI full-chain (root + intermediate)', command: 'dfix cabundle <container> /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply', validation: 'curl --cacert <bundle> https://<host:port> works', rollback: 'restore previous bundle', source_id: 'domains-debug-dfix'},
    {step: 101, action: 'Apply dfix env to point Node at the bundle', command: 'dfix env <container> NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply', validation: 'restart node process; auth-related calls succeed', rollback: 'restore previous env', source_id: 'domains-debug-dfix'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe', 'domains-debug-dfix', 'domains-practice-playbook'])),
  last_verified = DATE '2026-05-04'
WHERE id IN ('devin.fm.internal-svc-cert-untrusted', 'devin.fm.session-cant-reach-internal-svc')
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- devin.fm.bash-stale-prompt-state
UPDATE devin.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe procs to verify shell PID + parent (no stuck zombie ancestor)', command: 'dprobe procs <container>', validation: 'Lists shell PID + parent + Z/D state procs; if many Z procs accumulating, suggests PID 1 reaping issue', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe'])),
  last_verified = DATE '2026-05-04'
WHERE id = 'devin.fm.bash-stale-prompt-state'
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- devin.fm.corporate-proxy-not-set + vpn-not-engaging
UPDATE devin.failure_modes
SET
  fix_steps = list_concat(fix_steps, [
    {step: 99, action: 'Run dprobe network + dprobe dns to triage egress + DNS', command: 'dprobe network <container>; dprobe dns <container> <internal-host>', validation: 'Routes show egress interface; resolv.conf points at expected upstream', rollback: NULL, source_id: 'domains-debug-dprobe'}
  ]),
  source_ids = list_distinct(list_concat(source_ids, ['domains-debug-dprobe'])),
  last_verified = DATE '2026-05-04'
WHERE id IN ('devin.fm.corporate-proxy-not-set', 'devin.fm.vpn-not-engaging')
  AND NOT list_contains(source_ids, 'domains-debug-dprobe');

-- ============================================================
-- DONE. Run fts_index.sql next to rebuild BM25 indexes.
-- ============================================================
