# `docker/runtime` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.2 — 2026-05-02 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase B). Continued from docker Phase 1 (104 sources / 1.34M chars) and Phase 3.1 (engine 90 / 16 / 217).

**Outputs:**

| Table | Rows landed | Plan target |
|---|---:|---:|
| `docker.concepts` (`id LIKE 'docker.runtime.%'`) | **78** | 75 |
| `docker.commands` (`id LIKE 'docker.runtime.%'`) | **12** | 12 |
| `docker.config_keys` (`id LIKE 'docker.runtime.%'`) | **138** | 120 |

Cumulative flags across 12 commands: **63**. Cumulative examples: **32**. Total runtime rows: **228**.

**Verification:**

- ✓ Counts hit targets (concepts +3 over, config_keys +18 over driven by deeper coverage of `oci-config-json` capabilities/seccomp/resources subkeys).
- ✓ 0 orphan source_ids across all three tables.
- ✓ 0 PK collisions.
- ✓ Concept kind distribution: subsystem 10, runtime-object 11, primitive 10, lifecycle-state 6, driver 6, registry-api 11, runtime-hook 5, concept 19.
- ✓ Config_keys scope distribution: oci-config-json 59, containerd-toml 39, oci-image-config 20, runc-cli-flag 10, oci-distribution-header 10.
- ✓ Spot-check 5 random rows per table — sane, source_ids resolvable.

**Method:** continued duckdb-CLI fallback (motherduck MCP still disconnected). Bulk-dumped 22 runtime docs to `domains/docker/raw/scratch_p3/` via `dump_runtime_docs.sql` for direct in-context reading.

**Boundary respect:**

- Linux primitives (namespaces, capabilities, cgroup controllers) catalogued here as the **runtime-spec view** — i.e. how they appear in `config.json` schema. Engine leaf has its own engine-perspective primitive concepts; `linux/primitives` will own the kernel-level mechanism. Cross-link in P5.
- Engine vs runtime overlap on `runc`, `containerd`, `containerd-shim` — engine leaf treats these as black-box subsystems consumed by dockerd; runtime leaf catalogs their internal contracts and CLI surfaces. Distinct rows, both valid; P5 will wire `composes-into`.
- Storage: docker/engine catalogs the *driver* concepts (overlay2-driver, etc.); docker/runtime catalogs the *snapshotter* plugins (overlayfs-snapshotter, native-snapshotter, etc.) — same kernel feature, different software-layer perspective.
- CRI surface (crictl, CRI plugin config) is catalogued here even though CRI is a Kubernetes interface — relevant to runtime debugging on k8s nodes. Detailed CRI semantics will live in `k8s/runtime` when that leaf lands.

**Source attribution diligence:** all sources are T1 redistribute-ok (OCI specs, containerd docs, runc man pages); no T2/T3 attribution caveats.

### Deferred to P4 (failure-modes, horizontal across all domains)

Sample failure-mode seeds for the runtime layer:

1. **`OCI runtime exec failed: container_linux.go:NNN: starting container process caused: exec: "X": executable file not found in $PATH`** — image entrypoint missing or wrong arch. Diagnosis: `docker inspect --format '{{.Config.Entrypoint}}' <id>`, `docker run --rm --entrypoint=ls <image> /`, check `--platform`. Source: docker-cli-container-run, oci-runtime-spec-runtime.
2. **`runc: container <id> already exists`** — stale state under `/run/runc/<id>/` or `/var/lib/containerd/`. Cleanup: `runc delete -f <id>`. Source: runc-create-8, runc-delete-8.
3. **`runc state: stopped` but `runc delete` errors with EBUSY on cgroup** — leftover processes in cgroup; `cat /sys/fs/cgroup/.../cgroup.procs` to find them, kill, retry delete. Source: runc-delete-8, oci-runtime-spec-config-linux.
4. **`docker run --runtime crun ... fails: unknown runtime`** — crun not registered in dockerd's `runtimes` map (engine-leaf failure-mode). Source: docker-docs-daemon-alternative-runtimes (engine), runc-spec-8 (this leaf).
5. **Image pull fails with `manifest unknown: manifest unknown`** — registry doesn't have the tag, or `--platform` doesn't match available manifests in the index. Diagnosis: `docker manifest inspect <ref>`. Source: oci-distribution-spec, oci-image-spec-manifest.
6. **`Error response from daemon: missing signature key`** — image is encrypted (image_decryption.key_model) and the node lacks the key. Source: containerd-cri-config.
7. **CRI sandbox creation fails: pull pause image** — sandbox_image is unreachable / wrong tag. Diagnosis: `crictl pull registry.k8s.io/pause:3.10.2`, check containerd's registry mirrors. Source: containerd-cri-config.
8. **Pod network setup hangs** — CNI bin_dir / conf_dir misconfigured, plugins missing. Diagnosis: `ls /opt/cni/bin /etc/cni/net.d`, kubelet logs. Source: containerd-cri-config.
9. **Cgroup driver mismatch** — kubelet says `systemd`, containerd `SystemdCgroup=false` (or vice versa). Symptom: pods stuck at PodSandboxConfigChange / kubelet in restart loop. Diagnosis: `containerd config dump | grep -i SystemdCgroup`, `cat /var/lib/kubelet/config.yaml | grep cgroupDriver`. Source: containerd-cri-config.
10. **Layer pull fails midway with ECONNRESET** — bearer token expired during long pull. Auto-retry semantics: `max_concurrent_downloads`, `max-download-attempts` (engine), `image_pull_progress_timeout` (CRI). Source: containerd-cri-config, oci-distribution-spec.
11. **`unauthorized: authentication required`** mid-pull — token expired, registry 401 with WWW-Authenticate. Re-auth required. Source: oci-distribution-spec.
12. **Runc exit 255 with no detail** — runc internal error (often config.json validation). `runc --debug create ...` for verbose output. Source: runc-exec-8, oci-runtime-spec-config-linux.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates:

- `docker.runtime.namespace-{pid,mount,network,uts,ipc,user,cgroup,time}` ↔ `linux.primitives.namespace-*` (kernel mechanism vs OCI runtime-spec view).
- `docker.runtime.linux-capability` ↔ `linux.primitives.capabilities`.
- `docker.runtime.cgroup-controller` ↔ `linux.primitives.cgroups-v2` / `cgroups-v1`.
- `docker.runtime.runc` ↔ `docker.engine.runc` (engine sees as black-box subsystem; runtime catalogs internals; `composes-into`).
- `docker.runtime.containerd` ↔ `docker.engine.containerd` (same).
- `docker.runtime.containerd-shim-runc-v2` ↔ `docker.engine.containerd-shim`.
- `docker.runtime.overlayfs-snapshotter` ↔ `docker.engine.overlay2-driver` ↔ `linux.filesystem.overlayfs`.
- `docker.runtime.cri-plugin` ↔ `k8s.runtime.cri` (when that leaf lands).
- `docker.runtime.image-manifest` / `image-config` / `image-descriptor` ↔ `docker.engine.image` / `image-layer` / `image-tag` (engine sees the result; runtime catalogs the spec).
- `docker.runtime.oci-bundle` ↔ `docker.engine.oci-config-json` / `oci-state-json` (engine references the file kinds; runtime catalogs the schema).
- `docker.runtime.seccomp-syscall-action` ↔ `docker.engine.seccomp-profile` ↔ `docker.security.seccomp-profile-json` (when security leaf lands).

In-leaf edges:

- `containerd` composed-of `containerd-content-store` + `containerd-snapshotter` + `containerd-tasks-service` + `containerd-events` + `cri-plugin`.
- `containerd` invokes `containerd-shim-runc-v2` per task; shim invokes `runc` per OCI operation.
- `oci-bundle` consists-of `oci-config-json` + rootfs.
- `image-manifest` references `image-config` + N×`layer-tarball` (all via `image-descriptor`).
- `image-index` references N×`image-manifest` (per-platform).
- `overlayfs-snapshotter` / `native-snapshotter` / `btrfs-snapshotter` / `zfs-snapshotter` / `devmapper-snapshotter` / `fuse-overlayfs-snapshotter` implement `containerd-snapshotter`.
- `oci-runtime-cli-contract` implemented-by `runc`, `crun`, youki, runsc-via-shim.
- `runc-state-creating` → `runc-state-created` → `runc-state-running` → `runc-state-stopped` (lifecycle progression).
- `manifest-v2-2` / `manifest-list` / `oci-manifest` are kinds-of registry-served manifests.
- `prestart-hook` / `createRuntime-hook` / `createContainer-hook` / `startContainer-hook` / `poststop-hook` are stages of `oci-lifecycle`.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase B)
- Predecessor leaf log: `domains/docker/engine/PROGRESS.md`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
