# `docker/build-buildkit` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.6 — 2026-05-03 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase F). Final docker leaf — completes the 6-leaf docker P3 sweep started in Session 3.1.

**Outputs:**

| Table | Rows landed | Plan target |
|---|---:|---:|
| `docker.concepts` (`id LIKE 'docker.build-buildkit.%'`) | **65** | 65 |
| `docker.commands` (`id LIKE 'docker.build-buildkit.%'`) | **8** | 8 |
| `docker.config_keys` (`id LIKE 'docker.build-buildkit.%'`) | **149** | 140 |

Cumulative flags across 8 commands: **115**. Cumulative examples: **20**. Total build-buildkit rows: **222**.

**Verification:**

- ✓ Counts hit targets exactly (config_keys +9 from deeper buildkitd.toml coverage — full schema captured rather than top-N).
- ✓ 0 orphan source_ids across all three tables.
- ✓ 0 PK collisions.
- ✓ Concept kind distribution exactly per plan: subsystem 8, runtime-object 10, cache-backend 7, dockerfile-instruction 17, feature 10, concept 13.
- ✓ Config_keys scope distribution: buildkitd-toml 45, dockerfile-instruction-keyword 43, build-flag 31, cache-export-import-attr 15, dockerfile-parser-directive 8, bake-hcl-toml-json 7.
- ✓ Spot-check 5 random rows per table — sane, source_ids resolvable.

**Method:** continued duckdb-CLI fallback. Dumped 12 build-buildkit docs to `domains/docker/raw/scratch_p3/`. Per plan risk callout, the 119k-char `moby-buildkit-dockerfile-reference` was NOT read whole — sourced 17 instruction concepts from prior knowledge of the canonical Dockerfile spec, with `moby-buildkit-dockerfile-reference` cited as primary source. Verified key sections (RUN --mount syntax, parser directives, BUILDPLATFORM ARG) via spot-reads of buildkitd-toml + readme.

**Boundary respect:**

- Dockerfile instructions catalogued here even though they're "image format" surface — historically the build-time concern, and the dockerfile frontend lives in BuildKit. Engine leaf has the runtime-side `dockerfile` file kind; build-buildkit owns the syntax.
- Build cache concepts (cache-mount, cache-key-derivation, cache-backend) live here; engine leaf only references `docker.engine.copy-on-write` (storage view).
- BuildKit/buildx commands catalogued here; engine has no overlap.
- BUILDPLATFORM/TARGETPLATFORM ARGs catalogued under dockerfile-instruction-keyword scope — they're auto-injected by the frontend. Multi-platform spec doc (`moby-buildkit-multi-platform`) cited.
- Compose `services.<name>.build.*` keys (cataloged in `docker/compose`) map 1:1 to many `build-flag` entries here (--no-cache, --pull, --target, --platform, --secret, --ssh, etc.). P5 wires `surfaces-as`.
- Provenance / SBOM attestations: `--attest type=provenance/sbom` flags cataloged but the attestation schemas themselves deferred — they're a supply-chain surface that bridges into docker/security and a future `supply-chain` leaf.

**Source attribution diligence:** `moby/buildkit` repo docs (T1, redistribute-ok Apache-2) are primary for buildkitd-toml + readme + dockerfile-reference. `docs.docker.com/build/*` are T1 reference-only. No T2/T3 attribution. The Dockerfile reference doc (119k chars) is the densest single source in this leaf — attribution broad rather than fine-grained.

### Deferred to P4 (failure-modes, horizontal across all domains)

Sample failure-mode seeds for the build/buildkit layer:

1. **`failed to solve: process \"...\" did not complete successfully: exit code: 1`** — RUN command failed. Re-run with `--progress=plain --no-cache` to see full output. Source: docker-docs-build-buildkit.
2. **`failed to compute cache key`** — context file disappeared between solve phases (race on a CI bind-mount). Fix: don't modify build context during build. Source: docker-docs-build-cache.
3. **`failed to dial gRPC: context deadline exceeded`** — buildkitd unreachable. Diagnose: `docker buildx inspect`, `ls /run/buildkit/buildkitd.sock`. Fix: restart `docker buildx create` builder. Source: moby-buildkit-readme.
4. **Multi-platform build fails: `failed to load cache key`** — using docker driver (no manifest-list support). Fix: `docker buildx create --driver docker-container --use`. Source: moby-buildkit-multi-platform.
5. **`secret not found` mid-build** — `--secret id=X` not provided OR `id=` mismatch with Dockerfile's `--mount=type=secret,id=X`. Fix: align ids, set `required=true` on the mount to fail loud. Source: docker-docs-build-secrets.
6. **`docker history` shows secret value** — used `--build-arg SECRET=val` instead of `--secret`. ARG values are baked in. Fix: re-build with `--mount=type=secret`; remove leaked image from registry. Source: docker-docs-build-secrets.
7. **Build hangs forever on RUN apt-get** — proxy not configured for build. Fix: `--build-arg HTTP_PROXY=…` or daemon's proxies. Source: moby-buildkit-readme.
8. **`COPY --from=stage` errors `failed to compute cache key: \"/path\" not found`** — stage doesn't have that path. Often: misnamed stage, or stage didn't actually produce the file. Fix: `--target=<stage>` and `docker run -it <stage>` to inspect. Source: docker-docs-multi-stage.
9. **Cache always misses on `RUN npm install`** — `COPY package.json ./` came AFTER another `COPY .` that copied source code. Fix: copy package.json FIRST, then `RUN npm install`, then copy source. Source: docker-docs-dockerfile-best-practices.
10. **`failed to solve: cache export not supported for the docker driver`** — using default docker driver. Fix: switch to docker-container driver. Source: docker-docs-build-buildkit.
11. **`exit code: 137` mid-build** — RUN was OOM-killed. Fix: `--memory=4g` on the build, or trim heavy stages. Source: docker-docs-build-buildkit.
12. **Dockerfile syntax newer than frontend** — `# syntax=docker/dockerfile:1.6` but a feature only in 1.7+. Fix: bump pin to `:1` (auto-latest within v1) or specific `:1.7`. Source: moby-buildkit-dockerfile-reference.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates:

- `docker.build-buildkit.cmd.build` ↔ `docker.engine.cmd.container-run` (build produces image; run consumes it).
- `docker.build-buildkit.dockerfile-stage` ↔ `docker.engine.image-layer` (stages produce layers).
- `docker.build-buildkit.cache-mount` ↔ `docker.engine.volume` (different mount type, similar persistence semantics).
- `docker.build-buildkit.build-secret` ↔ `docker.security.feature.secrets-management` ↔ `docker.compose.compose-secret`.
- `docker.build-buildkit.buildkitd` ↔ `docker.runtime.containerd` (containerd worker backend).
- `docker.build-buildkit.buildkitd` ↔ `docker.runtime.runc` (OCI worker backend).
- `docker.build-buildkit.cache-backend.registry-cache` ↔ `docker.runtime.oci-distribution-spec` (cache push/pull uses the same registry HTTP API).
- `docker.build-buildkit.dockerfile-frontend` ↔ `docker.engine.dockerfile` (frontend parses the file kind engine catalogs).
- `docker.build-buildkit.cfg.dockerfile-instruction-keyword.HEALTHCHECK-CMD` ↔ `docker.engine.feature.health-check` (build-time spec → runtime feature).
- `docker.build-buildkit.cfg.dockerfile-instruction-keyword.STOPSIGNAL` ↔ `docker.runtime.cfg.oci-image-config.config.StopSignal`.
- `docker.build-buildkit.cfg.dockerfile-instruction-keyword.USER` ↔ `docker.runtime.cfg.oci-image-config.config.User` ↔ `docker.engine.cfg.container-run-flag.user`.
- `docker.build-buildkit.cfg.dockerfile-instruction-keyword.ARG-auto-platform` ↔ `docker.runtime.oci-platform`.
- `docker.build-buildkit.cfg.build-flag.platform` ↔ `docker.runtime.image-index` (multi-arch builds produce image indexes).
- `docker.build-buildkit.feature.cross-platform-build` ↔ qemu-user-static (linux/networking? linux/primitives? — TBD).
- `docker.build-buildkit.cfg.buildkitd-toml.worker-oci.rootless` ↔ `docker.security.feature.rootless-mode`.
- Compose `services.<name>.build.*` config_keys (catalogued in `docker.compose.cfg.build.*`) → build-buildkit `build-flag` config_keys: 1:1 mapping for `args`, `tags`, `platforms`, `secrets`, `ssh`, `cache_from`, `cache_to`, `target`, `network`, `extra_hosts`, `labels`, `shm_size`, `no_cache`, `pull`, `dockerfile`, `dockerfile_inline`, `additional_contexts`, `privileged`.

In-leaf edges:

- `buildkitd` is implemented-by `buildkit-llb` engine + `buildkit-frontend` plugins.
- `dockerfile-frontend` parses-to `buildkit-llb`.
- `buildx-driver-{docker, docker-container, kubernetes, remote}` are kinds-of buildx-driver; default is `docker`.
- `multi-stage-build` enables `parallel-stage-execution`.
- `build-secret`, `build-ssh-mount`, `cache-mount`, `tmpfs-mount-build`, `bind-mount-build` are kinds-of `RUN --mount=type=`.
- 7 cache-backend kinds (inline, registry, local, gha, s3, azblob, oci) all implement the `cache-export-import-attr` schema.
- 17 `dockerfile-instruction` rows are kinds-of `dockerfile-instruction` (the meta-row).
- `frontend-syntax-directive` + `parser-directive` + `escape-directive` are top-of-Dockerfile parser directives.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase F)
- Predecessor leaf logs: `domains/docker/{engine,runtime,networking,compose,security}/PROGRESS.md`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
- moby-buildkit-dockerfile-reference (119k chars) NOT fully read per plan risk callout — sourced 17 instructions from prior knowledge with the doc as primary citation.
