# `devin/devbox` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows in `_db/knowledge.duckdb`:**
- `devin.concepts` filtered `id LIKE 'devin.devbox.%'`: **64** rows (target ~50, target met)
- `devin.commands` filtered `id LIKE 'devin.devbox.%'`: **30** rows (target ~25, target met)
- `devin.config_keys` filtered `id LIKE 'devin.devbox.%'`: **65** rows (target ~50, target met)

**Source-id integrity:** All `source_ids[]` references resolve to `devin.sources.id` rows. No broken references.

**Source coverage:** All 16 non-incidents devbox docs read end-to-end. The status incidents archive (`devin-status-incidents-archive`, 191 KB) skipped for concepts — saved for Phase 4 failure-modes mining.

**Concept kind distribution:** subsystem, runtime-object, feature, file, network, credential, tool. Mix of static config artifacts (blueprint, agents.md, .envrc), runtime objects (snapshot, machine, microVM, hypervisor), tooling (direnv, nvm, OpenVPN, BlockDiff), and security (SOC2, AWS, encryption, MFA).

## Phase 4 candidates (failure-modes — deferred to horizontal pass)

Seeded from `devin-status-incidents-archive` (47+ public incidents) + the troubleshooting sections of blueprint/yaml/repo-setup docs:

- Session queueing delays
- Scheduled-session startup crashes
- Snapshot mutation lag
- Hypervisor scheduling pauses
- VS Code-server crashes mid-session
- Slack delivery failures
- GitHub webhook drops
- IP allowlist blocking outbound
- Snapshot pin > 7 days old (cannot pin)
- Build step timeout (1h limit hit on slow native compile)
- Setup-time command timeout (5min hit)
- Repository clone failed (access removed mid-session)
- Initialize step failed (network / package / typo)
- Maintenance step failed (lock-file drift)
- VPN connection setup failures (config.ovpn missing or systemd unit broken)
- Secrets-manager rotation pauses
- agents.md schema misconfig (Devin reads but doesn't apply)
- Large Performant migration auto-step interrupted
- Windows blueprint with Linux-only commands (apt-get on Win)
- Per-platform multi-block blueprint snapshot mismatch

## Phase 5 candidates (relationships — deferred to horizontal pass)

Cross-domain link candidates worth wiring in P5:
- `devin.devbox.snapshot` ↔ docker/runtime checkpoint/restore
- `devin.devbox.snapshot` ↔ linux/filesystem CoW (BlockDiff)
- `devin.devbox.firewall-allowlist` ↔ linux/networking netfilter / iptables
- `devin.devbox.machine` ↔ docker/engine container lifecycle
- `devin.devbox.secrets-manager` ↔ linux/primitives credential storage / keyrings
- `devin.devbox.cgroups` (implied — confirm in live capture) ↔ linux/primitives cgroups v2
- `devin.devbox.agents-md` ↔ devin/api session-create endpoint payload schema

Within-leaf relationships also pending: snapshot →[produced-by]→ build →[runs]→ blueprint; blueprint →[contains]→ initialize/maintenance/knowledge sections; etc.
