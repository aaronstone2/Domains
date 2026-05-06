# 10 — MCP Full-Scope Usage Guide

> Complete reference for the AI assistant on how to use every tool, MCP server, CLI command, and query interface in this repo. Read this before the interview.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  .mcp.json — 4 MCP servers registered for Claude Code          │
├─────────────────────────────────────────────────────────────────┤
│  1. domains-harness  — 8 tools (ask/lookup/playbook/concept/   │
│                        related/cite/stats/capture)              │
│  2. motherduck       — raw SQL against DuckDB corpus           │
│  3. filesystem       — read/write/search project files         │
│  4. memory           — entity-relation knowledge graph         │
├─────────────────────────────────────────────────────────────────┤
│  CLI fallback: pnpm harness <subcommand> [args]                │
│  Bash fallback: bash bash/query.sh <mode> <query>              │
│  DB: _db/knowledge.duckdb (85 MB, 7 domains, 767+ sources)    │
└─────────────────────────────────────────────────────────────────┘
```

**Three access layers** (use whichever is available):

| Layer | How | Speed | When to use |
|-------|-----|-------|-------------|
| MCP tools | Claude Code calls tools natively | ~50ms | Default — always prefer this |
| CLI | `pnpm harness ask "symptom"` | ~1.5s | MCP server unavailable or testing |
| Bash query | `bash bash/query.sh all "keyword"` | ~0.5s | Quick local search, no Node required |

---

## MCP Server 1: `domains-harness` (Primary)

Eight native tools. This is the main interface for interview debugging.

### Tool 1: `ask` — PRIMARY ENTRY POINT

**When:** User describes a symptom, error message, or "help me debug X". Call this FIRST, every time.

**Input:** `{ "symptom": "<natural language description>" }`

**Returns:** Top failure mode + TALK TRACK (pre-scripted narration for eval criteria) + DIAGNOSE steps (commands, expected output, source citations) + FIX steps (commands, validation, rollback) + CITATIONS.

**How it works internally:**
- Tokenizes input, strips stopwords
- Keyword-matches against `failure_modes.symptom`, `.id`, `.error_patterns`, `.root_cause_class` across all 7 domains
- Curated shortcut table boosts canonical fm-ids for common phrases (e.g. "OOM" → `docker.fm.exit-137-oomkilled`)
- Also shows "also plausible" alternate matches above 50% match strength
- Falls back to BM25 document search if no failure modes match

**Example inputs:**
```
"container exits 137"
"OOMKilled in dmesg"
"pod stuck Pending"
"Devin can't reach internal service"
"docker compose service won't start"
"npm install fails behind corporate proxy"
"TLS certificate expired"
"push rejected non-fast-forward"
"env var empty in container"
```

**What to do with the output:**
1. Read the TALK TRACK section aloud — it's Aaron's teleprompter, scripted to hit eval criteria (curiosity → diagnose → trade-off → fix)
2. Walk DIAGNOSE step-by-step, suggesting exact commands
3. After diagnosis confirmed, walk FIX step-by-step
4. Cite source URLs when making non-obvious recommendations

---

### Tool 2: `lookup` — Browse-Mode Search

**When:** `ask` didn't find the right top match, or you want to see the full candidate set.

**Input:** `{ "query": "<free text>" }`

**Returns:** Up to 8 failure modes (ranked by keyword × confidence) + matching commands + matching concepts + BM25 document snippets.

**Key difference from `ask`:** `ask` returns ONE top match with full runbook. `lookup` returns a ranked LIST across all result types so you can browse and pick.

**Workflow:**
```
ask "symptom" → wrong top match?
  → lookup "different terms"
  → find correct fm-id
  → playbook <fm-id>
```

---

### Tool 3: `playbook` — Full Failure Mode Runbook

**When:** You already know the fm-id (from a prior `ask` or `lookup`).

**Input:** `{ "fm_id": "docker.fm.exit-137-oomkilled" }`

**Returns:** Full META (symptom, confidence, root cause class, error patterns, affected concepts) + TALK TRACK + DIAGNOSE steps (with `expected` outcomes) + FIX steps (with `validate` + `rollback` annotations) + CITATIONS.

**ID format:** `<domain>.fm.<descriptive-name>`

**Example fm-ids:**
```
docker.fm.exit-137-oomkilled
docker.fm.dns-resolv-broken-in-container
k8s.fm.dns-pod-search-too-many
devin.fm.session-cant-reach-internal-svc
devin.fm.build-failed-blueprint-error
devin.fm.repo-scoped-secret-not-auto-injected
linux.fm.cgroup-memory-oom-kill
ecs.task-defs.fm.task-oom-killed
```

---

### Tool 4: `concept` — Definition + Relationships

**When:** Need to understand a primitive before recommending fixes. Also useful for explaining WHY something works (eval criterion: "explain why, not just what").

**Input:** `{ "concept_id": "linux.primitives.cgroup-v2" }`

**Returns:** Concept name, kind, description, source IDs, aliases + all relationship edges (uses, diagnoses, mitigates, etc.)

**Example concept-ids:**
```
linux.primitives.cgroup-v2
linux.primitives.oom-killer
linux.primitives.namespaces
docker.engine.health-check
docker.compose.service-depends-on
devin.devbox.nvm
k8s.scheduling.resource-requests-vs-limits
```

**When NOT to use:** Don't look up concepts you already know cold. Use it when you need the corpus definition to cite, or to discover cross-domain relationships.

---

### Tool 5: `related` — Graph Walk

**When:** Cross-domain inference — "what k8s concepts connect to this Linux primitive?" or "what other failure modes relate to this concept?"

**Input:** `{ "id": "linux.primitives.cgroup-v2", "depth": 2 }`

**Returns:** All nodes reachable within `depth` hops via relationship edges. Shows the full path.

**Parameters:**
- `id`: any node ID (concept, command, failure mode)
- `depth`: 1-4 (default 2, max 4)

**Power use cases:**
- "What failure modes does cgroup-v2 affect?" → `related` with depth 1
- "How does DNS connect to Devin's session networking?" → `related` from `linux.networking.dns` with depth 3
- "What concepts feed into exit code 137?" → `related` from the fm-id

---

### Tool 6: `cite` — Source URL Lookup

**When:** You want to give the user the canonical doc URL to back up a recommendation. Use this whenever you make a non-obvious claim.

**Input:** `{ "source_id": "k8s-resource-management" }`

**Returns:** Title, URL, tier (T0/T1/T2), license note, notes.

**Tiers:**
- T0: Primary source (official docs, source code)
- T1: Authoritative (well-known blog, conference talk)
- T2: Community (Stack Overflow, blog post)

**Example source-ids:**
```
docker-engine-oomkilled
k8s-resource-management
bash-debug-oom
bash-fix-env
bash-cmd-history
```

---

### Tool 7: `stats` — Corpus Inventory

**When:** Start of session — understand what's available before answering. Also impressive to show during interview ("let me check my corpus coverage").

**Input:** `{}` (no arguments)

**Returns:** Per-domain table: sources, documents, concepts, commands, config_keys, failure_modes, relationships. Plus quality grades (% of failure modes that are "thin" — <3 diag or <2 fix steps).

**Current corpus (approximate):**

| Domain | Sources | Commands | Failure Modes | Concepts |
|--------|---------|----------|---------------|----------|
| docker | 200+ | 250+ | 80+ | 120+ |
| linux | 150+ | 200+ | 70+ | 100+ |
| devin | 50+ | 40+ | 40+ | 60+ |
| k8s | 100+ | 100+ | 80+ | 80+ |
| methodology | 30+ | 15+ | 30+ | 20+ |
| firecracker | 50+ | 30+ | 40+ | 30+ |
| ecs | 50+ | 60+ | 60+ | 40+ |

---

### Tool 8: `capture` — Live Diagnostic Bundle

**When:** You want to RUN actual diagnostic commands on the live system and capture output. **SIDE EFFECT: executes shell commands.**

**Input:** `{ "bundle_or_flag": "<bundle-name | --list | --from-fm fm-id>" }`

**Available bundles:**
| Bundle | What it runs |
|--------|-------------|
| `oom` | dmesg OOM, cgroup memory, top processes, docker stats |
| `network-egress` | iptables, route, ss, curl to external endpoints |
| `dns` | /etc/resolv.conf, dig, nslookup, systemd-resolved |
| `systemd-unit` | systemctl status, journalctl, unit file cat |
| `k8s-pending` | kubectl describe pod, events, node resources |
| `docker-state` | docker ps, docker system df, inspect all containers |
| `perf-stalls` | top, iostat, vmstat, cpu.stat throttle counts |
| `devin-vpn` | VPN status, route table, connectivity to internal hosts |

**Dynamic bundles:** `--from-fm docker.fm.exit-137-oomkilled` synthesizes a bundle from that failure mode's diagnostic steps and runs them.

**Features:**
- Auto-redacts secrets (AWS keys, GitHub tokens, JWTs, passwords)
- Times each command
- Handles timeouts gracefully (5s default per command)
- Cross-platform (Linux, WSL, Windows)

---

## MCP Server 2: `motherduck` — Raw SQL

**When:** Ad-hoc queries the harness tools don't cover. Direct DuckDB access.

**How:** Claude Code's MCP automatically provides a `query` tool that accepts SQL.

**Schema (per domain):**
```sql
-- Every domain (docker, linux, devin, k8s, methodology, firecracker, ecs) has:
<domain>.sources        -- id, url, title, subdomain, tier, license_note, fetched_at, parser, notes
<domain>.documents      -- source_id, section_path, content_md (full-text indexed via BM25)
<domain>.concepts       -- id, name, kind, description, source_ids[], aliases[]
<domain>.commands       -- id, command, purpose, flags, source_ids[], aliases[]
<domain>.config_keys    -- id, key_path, default_value, description, valid_range, source_ids[]
<domain>.failure_modes  -- id, symptom, error_patterns[], root_cause_class, affected_concepts[],
                        -- diagnostic_steps (JSON), fix_steps (JSON), confidence, last_verified, source_ids[]
<domain>.relationships  -- from_id, to_id, rel_type, source_id, notes
```

**Cross-domain views:**
```sql
meta.all_sources        -- UNION ALL of all domain sources
meta.all_documents
meta.all_concepts
meta.all_commands
meta.all_config_keys
meta.all_failure_modes
meta.all_relationships
```

**Example queries:**
```sql
-- Find all failure modes with confidence > 90%
SELECT domain, id, symptom, confidence
FROM meta.all_failure_modes
WHERE confidence > 0.9
ORDER BY confidence DESC;

-- Commands containing 'proxy'
SELECT domain, command, purpose
FROM meta.all_commands
WHERE command ILIKE '%proxy%';

-- All debug/fix scripts as concepts
SELECT domain, id, name, description
FROM meta.all_concepts
WHERE kind = 'tool' AND id LIKE '%bash-%';

-- Relationship graph for a specific concept
SELECT from_id, rel_type, to_id
FROM meta.all_relationships
WHERE from_id = 'docker.engine.health-check'
   OR to_id = 'docker.engine.health-check';
```

---

## MCP Server 3: `filesystem` — File Access

**When:** Need to read repo files (scripts, configs, docs). Claude Code already has file access, but this MCP makes it available as a tool.

**Tools:** `read_file`, `write_file`, `search_files`, `list_directory`

**Key paths:**
```
bash/debug/*.sh          — 19 read-only diagnostic scripts
bash/fix/*.sh            — 17 fix scripts (dry-run default, --apply to execute)
bash/query.sh            — CLI DuckDB query tool
bash/ingest-to-duckdb.py — script to re-ingest into corpus
cmd_history.txt          — ~1300 lines of categorized commands (seeds atuin Ctrl+R)
practice/*.sh            — 32 practice scenarios
cluely/*.md              — 10 interview guide documents (this file = #10)
PRINT-READY-REFERENCE.md — 20-section printed cheatsheet
INTERVIEW-WORKFLOW.md    — tab layout + interview timeline
_db/knowledge.duckdb     — the DuckDB corpus (85 MB)
```

---

## MCP Server 4: `memory` — Knowledge Graph

**When:** Building persistent cross-domain inferences during a debugging session. Entity-relation graph that persists between calls.

**Storage:** `_db/knowledge_graph.json`

**Tools:**
- `create_entities` — add typed entities (concept, failure-mode, tool, etc.)
- `create_relations` — link entities
- `read_graph` — dump current graph state
- `search_nodes` — find entities by query
- `open_nodes` — get specific entity details
- `delete_entities` / `delete_relations`

**Use case during interview:**
As you discover facts during debugging, capture them:
```
Entity: "customer-issue-1" (type: incident) → observations: ["exit 137", "RSS spike at 14:02"]
Relation: "customer-issue-1" → diagnosed_as → "docker.fm.exit-137-oomkilled"
```

This builds a persistent context that survives across tool calls, so later queries can reference earlier discoveries.

---

## CLI Commands (fallback when MCP unavailable)

All commands from the repo root:

```bash
# Primary tools — same as MCP tools
pnpm harness ask "container exits 137"
pnpm harness lookup "proxy DNS TLS"
pnpm harness playbook docker.fm.exit-137-oomkilled
pnpm harness concept linux.primitives.cgroup-v2
pnpm harness related docker.fm.exit-137-oomkilled 3
pnpm harness cite docker-engine-oomkilled
pnpm harness stats
pnpm harness capture oom
pnpm harness capture --list
pnpm harness capture --from-fm docker.fm.exit-137-oomkilled

# Practice / drill
pnpm harness drill                    # interactive drill selector
pnpm harness drill 01                 # specific drill by number

# Raw query (dev/debug — returns DB state)
pnpm harness query "test"
```

---

## Bash Query Script (`bash/query.sh`)

Queries DuckDB directly without Node/pnpm. Fastest local option.

```bash
bash bash/query.sh commands "compose proxy"      # search commands by keyword
bash bash/query.sh failures "OOM killed"          # search failure modes by symptom
bash bash/query.sh scripts "tls"                  # search debug/fix scripts
bash bash/query.sh concepts "cgroup"              # search concepts
bash bash/query.sh all "dns timeout"              # search everything (commands + failures + scripts)
```

**Output:** Color-coded, domain-tagged results. Max 30 commands, 15 failures, 20 scripts/concepts per query.

---

## Debug Scripts (19 scripts)

All read-only. Safe to run anytime. Pattern: `bash bash/debug/<script>.sh <container> [args]`

| Script | Purpose | Key output |
|--------|---------|------------|
| `oom.sh` | OOM kill diagnosis | dmesg, cgroup memory, docker inspect OOMKilled |
| `dns.sh` | DNS resolution | /etc/resolv.conf, dig, getent |
| `tls.sh` | TLS/cert chain | openssl s_client, cert dates, issuer chain |
| `network.sh` | Container networking | iptables, routes, connectivity |
| `procs.sh` | Process tree + zombies | ps tree, D-state, zombie detection |
| `leak.sh` | Memory/FD leak sampling | RSS + fd count over time |
| `cgroup.sh` | cgroup limits | memory.max, cpu.max, memory.events |
| `throttle.sh` | CPU throttling | cpu.stat nr_throttled, nr_periods |
| `disk.sh` | Disk usage + I/O | df, du, iostat per process |
| `secrets.sh` | Env var / secret check | docker exec env, /proc/environ |
| `ulimits.sh` | FD exhaustion | fd count vs limits, socket breakdown |
| `restart.sh` | Restart loop analysis | RestartCount, events, last logs |
| `gateway.sh` | Multi-symptom triage | Chains ALL debug scripts, filters for issues |
| `compose.sh` | Compose debugging | config validation, service status, logs, deps |
| `proxy.sh` | Corporate proxy | env vars, MITM detection (Zscaler/Netskope), per-tool config |
| `volumes.sh` | Volume/bind mounts | mount listing, host permissions, container UID |
| `build.sh` | Docker build | Dockerfile lint, layer sizes, cache, multi-stage |
| `logs.sh` | Log management | per-container log sizes, log rate, daemon config |
| `blueprint.sh` | Devin env.yaml | YAML validation, sections, tabs, secrets |

---

## Fix Scripts (17 scripts)

All dry-run by default. Add `--apply` to execute. Pattern: `bash bash/fix/<script>.sh <args> [--apply]`

| Script | Purpose | --apply does |
|--------|---------|-------------|
| `env.sh` | Set env var in container | docker exec + writes /etc/profile.d |
| `hosts.sh` | Add /etc/hosts entry | Appends hostname mapping |
| `hosts-rm.sh` | Remove /etc/hosts entry | Deletes hostname mapping |
| `dns.sh` | Fix DNS resolution | Prepends custom DNS to resolv.conf |
| `cabundle.sh` | Install CA cert | Concat CA → system trust store |
| `cert-renew.sh` | Generate self-signed cert | openssl req → new cert + key |
| `reload.sh` | SIGHUP processes | Sends HUP to matched processes |
| `restart-process.sh` | Kill + restart | Kills process, relies on supervisor restart |
| `restart-container.sh` | Docker restart | docker restart <container> |
| `recreate-init.sh` | Recreate with --init | Recreates container with PID 1 init |
| `install-tools.sh` | Install debug tools | apt-get dig/openssl/curl/jq in container |
| `prune.sh` | Docker system prune | docker system prune -af (frees disk) |
| `compose.sh` | Compose fix | restart/rebuild/reset/fix-deps |
| `proxy.sh` | Configure proxy | Sets proxy for shell/npm/pip/git/Docker |
| `volume-perms.sh` | Fix volume perms | chown to match container UID |
| `log-rotate.sh` | Fix log rotation | Truncate now + set max-size limits |
| `blueprint.sh` | Fix env.yaml | fix YAML tabs, section ordering, secrets |

---

## Decision Tree: Which Tool When

```
User describes symptom
    │
    ├─ Natural language, vague → ask (MCP tool)
    │     └─ Wrong top match? → lookup → find correct fm-id → playbook
    │
    ├─ Know the exact fm-id → playbook (MCP tool)
    │
    ├─ Need to explain WHY → concept (MCP tool)
    │     └─ Cross-domain chain? → related (depth 2-3)
    │
    ├─ Need a doc URL → cite (MCP tool)
    │
    ├─ Want to run diagnostics on the live box → capture (MCP tool)
    │     └─ Or run bash script: bash bash/debug/<script>.sh <container>
    │
    ├─ Need quick command lookup → bash bash/query.sh commands "keyword"
    │     └─ Or: Ctrl+R in terminal (atuin-seeded from cmd_history.txt)
    │
    ├─ Need ad-hoc SQL → motherduck MCP server
    │
    └─ Building session context → memory MCP server
```

---

## Interview Workflow: MCP in Action

**T-0 (symptom described):**
```
→ call ask("<symptom>")
→ read TALK TRACK aloud
→ "My first hypothesis is [root_cause_class]. Let me verify by checking [diag step 1]."
```

**T+2 min (diagnosing):**
```
→ run DIAGNOSE commands one at a time
→ each command output confirms/refutes hypothesis
→ if wrong: call lookup("<different terms>") to find alternate fm
→ if deep dive needed: call concept("<primitive-id>") to explain
```

**T+5 min (diagnosis confirmed):**
```
→ "Root cause confirmed: [symptom]. Here's my fix plan."
→ read FIX steps from ask output
→ "Before I apply: [validation step]. And here's my rollback: [rollback step]."
→ call cite("<source-id>") for URL: "Per the Docker docs at [URL]..."
```

**T+8 min (fix applied):**
```
→ run validation command
→ "Fix verified. To prevent recurrence: [recommendation]."
→ call related("<fm-id>") to show related failure modes
→ "There's also a related failure mode around [related fm] that we should watch for."
```

---

## Corpus Maintenance

**Re-ingest after adding scripts or commands:**
```bash
python3 bash/ingest-to-duckdb.py
# Then rebuild FTS indexes (separate step due to DuckDB transaction behavior):
python3 -c "
import duckdb
con = duckdb.connect('_db/knowledge.duckdb')
for d in ['docker','linux','devin']:
    con.execute(f'DROP SCHEMA IF EXISTS fts_{d}_documents CASCADE')
for d in ['docker','linux','devin']:
    con.execute(\"INSTALL fts; LOAD fts;\")
    con.execute(f\"PRAGMA create_fts_index('{d}.documents','source_id','content_md','section_path',stemmer='english',stopwords='english',lower=1,strip_accents=1,overwrite=1)\")
con.close()
"
```

**What the ingest covers:**
- 19 debug scripts → sources + concepts + relationships to failure_modes
- 17 fix scripts → sources + concepts + relationships to failure_modes
- ~1300 cmd_history.txt entries → commands (categorized by domain from section headers)
- cmd_history.txt itself → source in each domain

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────┐
│  SYMPTOM → ask "symptom"                         │
│  BROWSE  → lookup "terms"                        │
│  RUNBOOK → playbook docker.fm.xxx                │
│  DEFINE  → concept linux.primitives.xxx          │
│  GRAPH   → related <id> 2                        │
│  SOURCE  → cite <source-id>                      │
│  COUNTS  → stats                                 │
│  RUN     → capture oom | capture --from-fm <id>  │
│  CLI     → pnpm harness <cmd> [args]             │
│  BASH    → bash bash/query.sh all "keyword"      │
│  DEBUG   → bash bash/debug/<name>.sh <container> │
│  FIX     → bash bash/fix/<name>.sh <args> --apply│
└──────────────────────────────────────────────────┘
```
