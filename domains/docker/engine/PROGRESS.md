# `docker/engine` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.1 — 2026-05-02 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md`; pipe-able session prompt `domains/_shared/sessions/phase-3-deep-extraction.md`. Continued from docker Phase 1 (104 sources / 1.34M chars, BM25 FTS built).

**Outputs:**

| Table | Rows landed | Plan target | Plan range |
|---|---:|---:|---|
| `docker.concepts` (`id LIKE 'docker.engine.%'`) | **90** | 90 | 75–100 |
| `docker.commands` (`id LIKE 'docker.engine.%'`) | **16** | 16 | 14–18 |
| `docker.config_keys` (`id LIKE 'docker.engine.%'`) | **217** | 200 | 175–220 |

Cumulative flags across all 16 commands: **197**. Cumulative examples: **37**. Total engine rows landed: **323**.

**Verification (acceptance per plan):**

- ✓ Counts hit targets / within ranges.
- ✓ 0 orphan source_ids (anti-join `docker.concepts/commands/config_keys` `source_ids[]` against `docker.sources` returned 0 rows).
- ✓ 0 PK collisions across the three tables.
- ✓ Concept kind distribution matches plan: subsystem 10 / runtime-object 12 / driver 14 / feature 12 / file 10 / primitive 8 / state 6 / concept 18.
- ✓ Config_keys scope distribution: daemon.json 97, container-run-flag 52, log-driver-options 36, mount-spec 15, env 11, storage-opts 6.
- ✓ Spot-check 5 random rows per table — all sane, source_ids resolvable.

**Method delta vs plan:** motherduck MCP disconnected immediately after `ExitPlanMode` (mid-session); fell back to local `duckdb` CLI (v1.5.2) per PREAMBLE's MCP/tooling stack. Bulk-dumped engine `documents.content_md` to `domains/docker/raw/scratch_p3/<source_id>.md` via `COPY ... TO …` for direct in-context reading. Loaded JSON via `INSERT OR REPLACE INTO docker.<table> SELECT * FROM read_json_auto(…)`. No drift from plan-mode design.

**Net delta vs target:**

- concepts +0 / -0
- commands +0 (added container-start + container-rm to land 16 — they're trivial CLI wrappers but harness needs them)
- config_keys +17 (a few ambitious-target additions in `container-run-flag` scope: full `--health-*` set, `--cpu-period/--cpu-quota`, `--memory-swappiness`, `--memory-reservation`, `--cpuset-mems`, `--label-file`, `--env-file`, `--workdir`, `--user`; all driven by `docker-cli-container-run`'s flag table). Total well within ambitious ceiling 220.

**Source attribution diligence:** `wsargent-docker-cheat-sheet` (T2) used only as secondary `source_ids[]` on rows whose primary is T1 (e.g. `docker.engine.docker-context`, `docker.engine.docker-cli`, `docker.engine.docker-build-context`, `docker.engine.docker-image-history`, `docker.engine.dockerfile`, `docker.engine.dockerignore`, `docker.engine.nicolaka-netshoot`). `iximiuz-debugger-images` (T3 unknown-license) only used for the slim/distroless/debug-sidecar concepts where it's the single most authoritative source on the topic; corpus-only.

**Boundary respect:** engine-leaf does NOT pre-empt networking-leaf. `docker.engine.network` is a pure runtime-object surfaced via `--network` and `docker inspect` — bridge / iptables-DOCKER-chain / userland-proxy / port-binding details are reserved for `docker/networking`. Daemon.json keys that surface networking (`bridge`, `bip`, `mtu`, `iptables`, `userland-proxy`, etc.) ARE catalogued here under `daemon.json` scope (engine owns the daemon-config view); networking will re-key the same on-host concepts under its own scopes (`bridge-driver-opt`, etc.).

### Deferred to P4 (failure-modes, horizontal across all domains)

The following sources were strictly deferred per the plan and are NOT mined for P3 rows:

- **`docker-docs-engine-daemon-troubleshoot`** (17,549 chars) — the dense troubleshoot page. Reserved entirely for the P4 pass.

Sample failure-mode seeds (URLs + brief symptom) to draft when P4 fires for docker:

1. `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` — group/socket perms, daemon not running, wrong DOCKER_HOST. Diagnosis: `id`, `systemctl status docker`, `ls -l /var/run/docker.sock`. Sources: docker-docs-daemon-remote-access, docker-docs-engine-daemon-troubleshoot.
2. **Container exit code 137 (OOM)** — cgroup memory limit hit, OOM-killer fired. Diagnosis: `docker inspect --format '{{.State.OOMKilled}}'`, `docker inspect --format '{{.HostConfig.Memory}}'`, `dmesg | grep -i oom`. Fix: raise `--memory`, fix leak. Sources: docker-cli-container-run, docker-cli-container-stop.
3. **`docker stop` hangs 10 seconds then SIGKILLs** — pid 1 doesn't propagate signals (shell-form ENTRYPOINT, or `bash -c` wrapper). Fix: exec-form ENTRYPOINT, or `--init`. Sources: docker-cli-container-stop, docker-cli-container-kill.
4. **`docker logs` returns nothing** — non-cache log driver in use (fluentd/syslog/gelf/awslogs/etc.). Diagnosis: `docker inspect --format '{{.HostConfig.LogConfig.Type}}'`. Fix: switch to json-file/local/journald or read upstream. Source: docker-docs-logging-configure.
5. **`no space left on device` writing under /var/lib/docker** — disk full. Diagnosis: `docker system df -v`, `df -h /var/lib/docker`. Fix: `docker system prune -af --volumes`, or move data-root to a bigger disk. Sources: docker-cli-system-df, docker-docs-manage-pruning.
6. **Daemon refuses to start: `unable to configure the Docker daemon with file /etc/docker/daemon.json`** — invalid JSON, OR same option specified both as flag (in systemd unit's ExecStart) and in daemon.json. Diagnosis: `dockerd --validate`, `journalctl -xu docker.service`. Source: docker-docs-engine-daemon, docker-docs-cli-dockerd.
7. **Live restore upgrade fails to reconnect containers** — skipped a major version, or daemon-options that changed (bridge IP, graph driver) prevent the reconnect. Source: docker-docs-daemon-live-restore.
8. **Logs filling disk** — json-file with no `max-size` rotation. Source: docker-docs-logging-configure, docker-docs-logging-json-file.
9. **`ip6_tables` module not loaded inside Docker-in-Docker** — manual `modprobe ip6_tables` or `--ip6tables=false`. Source: docker-docs-daemon-ipv6.
10. **Bind mount source path doesn't exist with `--mount`** — `bind-create-src` opt-in or use `-v`. Source: docker-docs-storage-bind-mounts.
11. **Broken iptables rules persist after stale containers** — `docker network prune` to clean up. Source: docker-docs-manage-pruning.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates to wire when linux/devin/k8s P3 rows exist:

- `docker.engine.linux-namespace` ↔ `linux.primitives.namespaces` (kernel-level mechanism).
- `docker.engine.cgroup-v1` / `docker.engine.cgroup-v2` ↔ `linux.primitives.cgroups-v1`/`cgroups-v2`.
- `docker.engine.capability` ↔ `linux.primitives.capabilities`.
- `docker.engine.seccomp-profile` ↔ `docker.security.seccomp-profile-json` and `linux.primitives.seccomp`.
- `docker.engine.apparmor-profile` ↔ `docker.security.apparmor-profile-template` and `linux.primitives.apparmor`.
- `docker.engine.selinux-label` ↔ `linux.primitives.selinux`.
- `docker.engine.docker-sock` ↔ `devin.devbox.devbox` (devin sessions historically include docker.sock pass-through).
- `docker.engine.runc` / `docker.engine.containerd` ↔ `docker.runtime.runc` / `docker.runtime.containerd` (engine-perspective vs runtime-internal-perspective; `composes-into` rel-type).
- `docker.engine.overlay2-driver` ↔ `linux.filesystem.overlayfs`.
- `docker.engine.network` ↔ `docker.networking.docker-network` (engine-perspective vs networking-perspective; `surfaces-as` rel-type).
- `docker.engine.dockerfile` ↔ `docker.build-buildkit.dockerfile-instruction-keyword` (~17 instruction concepts).
- `docker.engine.live-restore` ↔ `linux.systemd.systemctl-reload` (reload-vs-restart semantics).

In-leaf edges to wire (mostly `composed-of`, `provides`, `controlled-by`):

- `docker-engine` composed-of `dockerd` + `containerd` + `runc` + `containerd-shim` + `docker-cli`.
- `dockerd` controlled-by `daemon-json`.
- `dockerd` listens-on `docker-sock`.
- `containerd` listens-on `containerd-sock`.
- `volume` instance-of `runtime-object`; `named-volume` / `anonymous-volume` specialize `volume`.
- `bind-mount` / `volume` / `tmpfs-mount` are kinds-of `mount-point`.
- `overlay2-driver` implements `storage-driver`; `vfs-driver` / `btrfs-driver` / `zfs-driver` likewise.
- `json-file-log-driver` / `local-log-driver` / `journald-log-driver` / `fluentd-log-driver` / `syslog-log-driver` / `gelf-log-driver` / `none-log-driver` implement `logging-driver`.
- `docker-init` implements `pid1-zombie-reaping`.
- `tls-mtls-daemon-socket` controls `docker-sock` (when listening on TCP).

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md`
- Pipe-able session prompt: `domains/_shared/sessions/phase-3-deep-extraction.md`
- Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`
- Predecessor extracts (shape mirrors): `domains/devin/devbox/extract/{concepts,commands,config_keys}.json`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
