# `docker/security` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.5 — 2026-05-03 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase E). Continued from docker engine, runtime, networking, compose (Phase 3.1–3.4).

**Outputs:**

| Table | Rows landed | Plan target |
|---|---:|---:|
| `docker.concepts` (`id LIKE 'docker.security.%'`) | **50** | 50 |
| `docker.commands` (`id LIKE 'docker.security.%'`) | **4** | 4 |
| `docker.config_keys` (`id LIKE 'docker.security.%'`) | **81** | 80 |

Cumulative flags across 4 commands: **5**. Cumulative examples: **9**. Total security rows: **135**.

**Verification:**

- ✓ Counts hit targets exactly (config_keys +1 from extra apparmor template DSL keyword).
- ✓ 0 orphan source_ids across all three tables.
- ✓ 0 PK collisions.
- ✓ Concept kind distribution exactly per plan: subsystem 5, primitive 10, feature 12, role-key 8, concept 15.
- ✓ Config_keys scope distribution: daemon.json-security 20, seccomp-profile-json 15, apparmor-profile-template 11, rootless-env 10, daemon-tls 10, dct-env 10, subuid-subgid-file 5.
- ✓ Spot-check 5 random rows per table — sane, source_ids resolvable.

**Method:** continued duckdb-CLI fallback. Dumped 9 security docs (skipping `docker-docs-security-antivirus` 725 chars = low signal, `docker-docs-rootless-troubleshoot` per plan → P4 strict-defer) to `domains/docker/raw/scratch_p3/`.

**Boundary respect:**

- **STRICT DEFER** of `docker-docs-rootless-troubleshoot` (16,065 chars, troubleshoot doc) per plan — reserved entirely for P4 failure-modes pass. NOT mined here for any concept/command/config_key.
- Docker Content Trust commands (`docker trust *`) catalogued here (only 4 — sign, inspect, revoke, key-load) because no `docker-cli-trust-*` man pages are in the corpus. Surface drawn from `docker-docs-security-trust` + `docker-docs-security-trust-automation`. **Phase 1.5 candidate:** fetch `docs.docker.com/reference/cli/docker/trust/*` to enrich command rows.
- `daemon.json-security` re-keys 20 daemon-config keys for their security semantic (engine catalogues canonical `daemon.json` scope; security adds the security-perspective view of the same field). PK distinct via scope.
- `seccomp-profile-json` schema overlaps with `docker.runtime.cfg.oci-config-json.linux.seccomp.*`. Distinction: runtime catalogues the runtime-spec view (the OCI-side schema); security catalogues the standalone seccomp profile JSON file format consumed by `--security-opt seccomp=<file>` and dockerd's `seccomp-profile`. Both valid; P5 will wire `same-as`.
- AppArmor profile DSL keywords catalogued under `apparmor-profile-template` scope as a documentation surface, not a knob set — these describe the policy syntax users write, not configuration values.
- DCT key roles catalogued as `kind: role-key` (5 TUF roles + DCT passphrase + cosign keypair = 8). Distinct from `subsystem` because they're cryptographic identities, not running components.
- Rootless mode is documented heavily here even though it overlaps with `docker.engine.feature.userns-remap` — rootless is a security feature, userns-remap is the daemon-level mechanism. P5 wires `relates-to`.

**Source attribution diligence:** all 9 security docs are T1 reference-only (Docker Inc. docs). No T2/T3 sourcing; commands.json sources are entirely T1 trust + trust-automation pages.

### Deferred to P4 (failure-modes, horizontal across all domains)

Sample failure-mode seeds for the security layer (most live in `docker-docs-rootless-troubleshoot` reserved for P4):

1. **`Got permission denied while trying to connect to the Docker daemon socket`** — user not in `docker` group, OR daemon-socket perms wrong, OR rootless setup not sourced. Diagnose: `id`, `ls -l /var/run/docker.sock`. Source: docker-docs-engine-security.
2. **`Error response from daemon: failed to create endpoint X: cannot link to container/image registry: signed image required`** — `DOCKER_CONTENT_TRUST=1` set but image is unsigned. Fix: `docker trust inspect <image>`, sign it, or unset DCT for the pull. Source: docker-docs-security-trust.
3. **userns-remap container can't access bind mount** — host file owned by root:root, container's root maps to dockremap (high uid). Fix: chown the host path to the dockremap range, OR don't bind-mount root-owned paths. Source: docker-docs-userns-remap.
4. **Rootless `setup failed: subuid/subgid not configured`** — `/etc/subuid` and `/etc/subgid` missing entries for the user. Fix: `usermod --add-subuids 100000-165535 alice` (and same for subgids). Source: docker-docs-rootless.
5. **Rootless docker fails: 'unprivileged user namespaces are disabled'** — kernel sysctl `kernel.unprivileged_userns_clone=0` (Debian default). Fix: `sysctl -w kernel.unprivileged_userns_clone=1`. Source: docker-docs-rootless.
6. **Seccomp blocks newer syscall in upstream kernel** — moby's default profile is allowlist-based; new syscalls aren't in the list, so they get EPERM. Symptom: `clone3` failing, `openat2` failing. Fix: update Docker (newer default profile), or `--security-opt seccomp=unconfined` as a debug step. Source: docker-docs-security-seccomp.
7. **AppArmor `Permission denied` on a benign operation** — custom profile too restrictive. Diagnose: `dmesg | grep DENIED`, `aa-status`. Fix: `--security-opt apparmor=unconfined` to confirm; then patch the profile. Source: docker-docs-security-apparmor.
8. **DCT signing fails: 'Failed to read trust data'** — TUF metadata corrupt or missing for the GUN. Fix: `rm -rf ~/.docker/trust/tuf/<server>/<repo>` to force re-fetch (loses local cache). Source: docker-docs-security-trust.
9. **TLS handshake failure between client and dockerd** — cert SAN doesn't include the host clients connect to. Fix: regenerate server cert with proper SANs. Source: docker-docs-security-protect-access.
10. **`unauthorized: authentication required` mid `docker push` with DCT on** — registry auth ok but Notary auth missing. Fix: `docker login` separately to the Notary server (some setups require both).Source: docker-docs-security-trust-automation.
11. **Rootless dockerd died after logout** — `loginctl enable-linger` not run, so user-mode systemd shut down at logout. Fix: `loginctl enable-linger <user>`. Source: docker-docs-rootless.
12. **`docker run --privileged` overrides everything** — bypasses seccomp, AppArmor, capability-drops, devices allowlist. Symptom: 'why is my hardening profile not enforcing?'. Source: docker-docs-engine-security.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates:

- `docker.security.seccomp-profile` ↔ `docker.runtime.cfg.oci-config-json.linux.seccomp` (security catalogs the JSON schema; runtime catalogs how it's wired into the runtime-spec).
- `docker.security.apparmor-profile` ↔ `linux.primitives.apparmor` (LSM kernel side).
- `docker.security.selinux-context` ↔ `linux.primitives.selinux`.
- `docker.security.capability-bounding-set` ↔ `linux.primitives.capabilities`.
- `docker.security.linux-uid-mapping` / `linux-gid-mapping` ↔ `docker.runtime.namespace-user` ↔ `linux.primitives.user-namespace`.
- `docker.security.subuid-file` / `subgid-file` ↔ `linux.systemd.user-namespace-config`.
- `docker.security.slirp4netns` ↔ `linux.networking.tun-tap` (kernel side).
- `docker.security.userns-remap-mode` ↔ `docker.engine.feature.userns-remap` (engine catalogs the daemon flag; security catalogs the security feature it implements).
- `docker.security.rootless-mode` ↔ `docker.runtime.cfg.containerd-toml.cri.runtime.disable_apparmor` (rootless containerd has different LSM defaults).
- `docker.security.content-trust-DCT` ↔ `docker.runtime.auth-bearer-token` (Notary auth flow uses bearer tokens too).
- `docker.security.image-signing-cosign` ↔ `docker.runtime.referrers-api` (cosign attaches signatures via the referrers API).
- `docker.security.daemon-socket-attack-surface` ↔ `docker.engine.docker-sock` ↔ `docker.compose.compose-secret` (compose secrets are the alternative to mounting docker.sock for CI runners).
- `docker.security.cap-drop-all-baseline` ↔ `docker.compose.cfg.services.cap_drop` (compose YAML surface).

In-leaf edges:

- `default-seccomp-profile` is a `seccomp-profile`; same for `default-apparmor-profile`.
- `userns-remap-mode` consumes `subuid-file` + `subgid-file`; `rootless-mode` does too.
- `rootless-mode` requires `unprivileged-userns` + `cgroup-delegation-systemd`.
- `slirp4netns` is the rootless-mode network primitive; `vpnkit` the macOS analog.
- `notary-server` + `notary-signer` together implement `content-trust-DCT`.
- `tuf-repository` consists of metadata signed by the 5 `*-key` role-keys.
- `mtls-daemon-socket` is a feature implemented by `dockerd-tls-listener`.
- `cap-drop-all-baseline` + `no-new-privileges` + `read-only-rootfs` + `tmpfs-mount-noexec` together = `least-privilege` + `defense-in-depth`.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase E)
- Predecessor leaf logs: `domains/docker/{engine,runtime,networking,compose}/PROGRESS.md`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
- Phase 1.5 candidates: `docs.docker.com/reference/cli/docker/trust/*` man pages (DCT CLI surface).
- P4 source reservation: `docker-docs-rootless-troubleshoot` (16,065 chars) — strict-defer.
