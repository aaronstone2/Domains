# Phase 2 — Devin DevBox primary-source capture

> **The highest-leverage session in the entire project.** External docs describe what Devin *should* be; this session captures what Devin *is* on a real DevBox. Tag everything `tier=T0`.

> **Sequencing (revised 2026-05-02, see [PREAMBLE.md](./PREAMBLE.md) → Approach commitments):** Phase 2 now runs **horizontally AFTER all 5 domains have completed their P1+P3 vertical slice**, NOT before Phase 3. It's devin-specific and timing-gated (only when DevBox access is available). When this fires, it enriches `devin/devbox` Phase 3 entries that were originally extracted from docs alone.

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this file or say: *"Run domains/_shared/sessions/phase-2-devbox-capture.md."*

You'll need a Devin session open in a browser (paid Core trial active — Aaron has confirmed this). You'll be running shell commands inside the DevBox terminal, copy-pasting outputs back into the local repo, and ingesting them as sources.

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md)

## Goal

Build a complete, accurate snapshot of the Devin DevBox runtime environment as a set of `tier=T0` sources in `devin.sources` / `devin.documents`. This is the ground truth that anchors all other Devin research.

## Critical safety notes

- **No secret values are captured.** When inspecting MCP wiring, capture env-var *names* only, never values. Likewise for `.env` files (note their existence and key names; not contents).
- **No Cognition proprietary code/binaries are committed.** If a binary is on the filesystem, note path + size + sha256, don't copy it.
- **`.gitignore`** already excludes `*.token`, `*.key`, `*sensitive*`, and `domains/**/raw/`. Keep all captures under the gitignored areas until vetted.
- **No customer data.** Don't capture anything from a customer repo cloned into the DevBox.

## Plan-mode meta-research (Phases 1–5 of plan-mode)

### Phase 1 — Initial Understanding (Explore agents)

Launch 1–2 Explore agents to:
1. Re-read `docs.devin.ai/onboard-devin/environment` and `environment-yaml` for any documented filesystem paths, processes, or default configs we should look for. (Already ingested in Phase 1.1; query `devin.documents` first.)
2. Search for public mentions of "Devin DevBox" internals — Cognition blog posts, conference talks, podcast transcripts where they discuss the runtime. Build a list of *expected* internal details to verify against capture.

### Phase 2 — Design (Plan agent)

Have the Plan agent design the capture playbook:
- Group commands by *purpose* (boot env, processes, network, docker, fs, capabilities, MCP wiring, devin-side config).
- Sequence: read-only inspection first; only then any "what does this do?" probes that may have side effects.
- Specify what gets stored where: each command output → a separate `<source-id>.txt` under `domains/devin/devbox/raw/devbox-capture-<date>/`, plus an aggregated `manifest.yaml` listing which command produced which file.

### Phase 3 — Review

Show me the proposed capture playbook before I run it on the live DevBox. I may have safety/scope concerns.

### Phase 4 — Final Plan

Write `domains/devin/devbox/PLAN.md` (use `domains/_shared/PLAN.template.md`) and `domains/devin/devbox/CAPTURE.md` (the actual command checklist for me to run in the DevBox terminal).

### Phase 5 — `ExitPlanMode`

## Capture checklist (skeleton — Plan agent will refine)

I run these in the Devin shell. Outputs land on my local machine via copy-paste, ingested as `tier=T0`.

```bash
# Boot environment
uname -a; cat /etc/os-release; cat /proc/cpuinfo | head -30; free -h; df -h; mount; cat /proc/cgroups; ls -la /sys/fs/cgroup/

# Processes at idle
ps auxf

# Network
ip a; ip route; cat /etc/resolv.conf; iptables -L -n -t nat 2>/dev/null; iptables -L -n -t filter 2>/dev/null; ss -tlnp

# Docker (if present)
docker version; docker info; docker ps -a; docker images; docker network ls; docker volume ls
[ -f /etc/docker/daemon.json ] && cat /etc/docker/daemon.json
ls -la /var/lib/docker 2>/dev/null

# Filesystem topology
find / -maxdepth 2 -type d 2>/dev/null
cat /etc/passwd; cat /etc/group; ls -la /home/* /root /workspace 2>/dev/null

# Capabilities & security
cat /proc/self/status | grep -i cap; getcap -r /usr/bin 2>/dev/null | head -50; ls /etc/sudoers.d/

# Devin-specific
find / -name '.devin*' 2>/dev/null
find / -name '*.devin.md' 2>/dev/null
ls -la $HOME/.devin 2>/dev/null; ls -la /etc/devin 2>/dev/null
env | grep -i 'DEVIN\|COGNITION' | sed 's/=.*/=<REDACTED>/'

# MCP wiring (NAMES ONLY, no values)
# In Devin Settings UI → MCP Marketplace, enumerate enabled MCPs and required env-var names; record as a YAML manifest.
```

## Execute

After the plan is approved and I've run the commands:

1. Save outputs under `domains/devin/devbox/raw/devbox-capture-<YYYY-MM-DD>/` with one file per command.
2. Build a `manifest.yaml` that lists each captured file's source-id, what command produced it, and which Devin/DevBox subdomain it falls under.
3. Extend `domains/_shared/sources.yaml` with a `tier: T0`, `license_note: redistribute-ok` (it's *my* DevBox state), `parser: trafilatura` block per captured file. Use `url: file://domains/devin/devbox/raw/devbox-capture-<date>/<file>.txt`.
4. Use a small variant of the ingest pipeline that reads from `file://` URLs (or just stage the file content directly into `devin.documents` via a one-off script).
5. **Verify** — `SELECT count(*) FROM devin.sources WHERE tier='T0'` matches the manifest.

## Anti-goal

Don't try to *interpret* the DevBox during this session. Capture is mechanical; interpretation is Phase 3 (`devin/devbox` deep extraction). The mental discipline: capture wide, interpret narrow.

## When this is done

Move to [`phase-3-deep-extraction.md`](./phase-3-deep-extraction.md) starting with the `devin/devbox` leaf — it'll synthesize T0 (this) + T1 (docs) into structured concepts/commands/failure_modes.
