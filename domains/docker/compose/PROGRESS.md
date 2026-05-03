# `docker/compose` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.4 — 2026-05-03 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase D). Continued from docker engine, runtime, networking (Phase 3.1–3.3).

**Outputs:**

| Table | Rows landed | Plan target |
|---|---:|---:|
| `docker.concepts` (`id LIKE 'docker.compose.%'`) | **61** | 60 |
| `docker.commands` (`id LIKE 'docker.compose.%'`) | **8** | 8 |
| `docker.config_keys` (`id LIKE 'docker.compose.%'`) | **184** | 180 |

Cumulative flags across 8 commands: **81**. Cumulative examples: **19**. Total compose rows: **253**.

**Verification:**

- ✓ Counts hit targets (concepts +1, commands exact, config_keys +4 from extra services.<name> + deploy keys).
- ✓ 0 orphan source_ids across all three tables.
- ✓ 0 PK collisions.
- ✓ Concept kind distribution: feature 15, concept 14, runtime-object 12, deploy-strategy 8, healthcheck 6, interpolation 6.
- ✓ Config_keys scope distribution: services.<name> 78, services.<name>.deploy 21, services.<name>.build 20, networks.<name> 15, volumes.<name> 10, develop.watch 8, top-level 8, services.<name>.healthcheck 8, configs.<name> 6, secrets.<name> 5, services.<name>.depends_on 5.
- ✓ Spot-check 5 random rows per table — sane, source_ids resolvable.

**Method:** continued duckdb-CLI fallback. Dumped 15 compose docs to `domains/docker/raw/scratch_p3/` via `dump_compose_docs.sql`. Skipped `compose-spec-00-overview` (803 chars, low-signal index).

**Boundary respect:**

- The compose CLI man pages (`docker compose up/down/ps/logs/exec/run/build/restart`) are NOT in the corpus — Phase 1 fetched only the spec docs + `docker-docs-compose-startup-order`. The 8 command rows draw from spec docs + `docker-docs-compose-startup-order` + wsargent cheat sheet for flag listings. Detail level is honest about that gap. **Action item for Phase 1.5:** fetch `docs.docker.com/reference/cli/docker/compose/{up,down,ps,logs,exec,run,build,restart,restart}/` to backfill canonical CLI surface.
- Compose-spec service `volumes` long-form mount-spec sub-keys catalogued under `volumes.<name>` scope (alongside top-level `volumes.<name>` declaration keys). Engine leaf already owns the canonical `mount-spec` scope for `--mount type=…,src=…,dst=…` semantics; compose duplicates the user-facing forms here under its own scope to avoid PK collision and to document the YAML shape.
- `services.<name>.deploy` scope catalogues Swarm-flavored fields. Most are honored by Docker Swarm only; vanilla Compose treats `deploy.resources.{limits, reservations}` as advisory but DOES enforce limits on the cgroup. Documented in description text per row.
- `endpoint_mode: vip|dnsrr` is a Swarm primitive that overlaps with `docker.networking.swarm-routing-mesh`; here the YAML knob, there the runtime concept. P5 will wire `surfaces-as`.
- Profile semantics: a service explicitly targeted by command (e.g. `docker compose run baz`) auto-activates its profiles AND pulls in dependencies. Documented via `docker.compose.compose-profile` runtime-object + `docker.compose.cfg.services.profiles` config_key.
- Dockerfile / build-step keys are NOT catalogued here — those belong to `docker/build-buildkit` (next leaf). The `services.<name>.build` scope catalogs only the YAML-side build configuration, not the Dockerfile syntax it consumes.

**Source attribution diligence:** compose-spec-* docs are T1 redistribute-ok (Apache-2 from compose-spec/compose-spec). `docker-docs-compose-startup-order` is T1 reference-only. `wsargent-docker-cheat-sheet` (T2 redistribute-ok) used only as secondary on commands where the canonical CLI man pages are not in the corpus.

### Deferred to P4 (failure-modes, horizontal across all domains)

Sample failure-mode seeds for the compose layer:

1. **`Cannot start service X: Conflict. The container name "/<project>_X_1" is already in use`** — orphan container from a previous deploy. Fix: `docker compose down --remove-orphans` then `up`. Source: docker-docs-compose-startup-order, compose-spec-02-model.
2. **App can connect to DB locally but fails in compose** — service depends on DB with `condition: service_started` (default), DB container exists but isn't ready. Fix: define `healthcheck` on DB + use `condition: service_healthy`. Source: docker-docs-compose-startup-order.
3. **`docker compose run` containers leak** — `--rm` is NOT default for `compose run` (unlike `docker run`). Fix: always pass `--rm` to one-shot run commands, or set in CI scripts. Source: compose CLI surface.
4. **`Service X has neither an image nor a build context`** — typo in `image` field, OR conditional `build` block resolved away. Source: compose-spec-build, compose-spec-05-services.
5. **Compose project name collision** — running `docker compose -p foo up` then `docker compose up` (auto-named) creates two parallel projects with shared volume names (because external volumes don't get the prefix). Fix: always set `name:` top-level. Source: compose-spec-02-model.
6. **`extends` cycle** — `services.A.extends: B` and `services.B.extends: A`. Compose errors with cycle detection. Source: compose-spec-13-merge.
7. **`--profile` doesn't activate dependent service** — referenced via `depends_on` but the dependency itself has a `profiles: []` entry that's not active. Workaround: target the dependency explicitly OR list the profile in the dependent's profile set. Source: compose-spec-15-profiles.
8. **YAML anchor expansion silently drops fields** — `<<: *base` followed by overrides — the spec says map-merge, but some implementations override the wrong way. Solution: don't rely on `<<:` for deep maps, use Compose `extends` instead. Source: compose-spec-11-extension.
9. **Healthcheck always reports starting** — image's HEALTHCHECK uses a relative path that doesn't exist in container. Fix: use absolute paths in `test:`. Source: compose-spec-05-services.
10. **`docker compose up --watch` rebuild storm** — watch rules with `action: rebuild` on broad path triggers loop. Fix: tighten `path:` + add `ignore:`. Source: compose-spec-develop.
11. **`stop_grace_period: 0` results in lost writes** — too short to drain buffered writes in DB / queue. Fix: `stop_grace_period: 30s` for stateful services. Source: compose-spec-05-services.
12. **`COMPOSE_PROJECT_NAME` env vs `-p` flag precedence** — flag wins. CI bug source. Source: compose-spec-02-model.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates:

- `docker.compose.compose-service` ↔ `docker.engine.container` (compose service → 1+ container instances).
- `docker.compose.compose-network` ↔ `docker.networking.docker-network` (compose YAML → Docker network).
- `docker.compose.compose-network` ↔ `docker.networking.bridge-driver` / `overlay-driver` (each compose network is one of those drivers).
- `docker.compose.compose-volume` ↔ `docker.engine.volume` / `docker.engine.named-volume`.
- `docker.compose.compose-build-context` ↔ `docker.build-buildkit.build-context` (the Compose `build:` block feeds BuildKit).
- `docker.compose.cfg.services.<name>.build.*` ↔ `docker.build-buildkit.cfg.build-flag.*` (1:1 for tags, no_cache, pull, target, platforms, secrets, ssh, cache_from, cache_to, network, args, etc.).
- `docker.compose.cfg.services.healthcheck.*` ↔ `docker.engine.feature.health-check` (compose YAML → docker run --health-* flags).
- `docker.compose.compose-secret` ↔ `docker.security.feature.secrets-management` (when security leaf lands).
- `docker.compose.deploy-replicated` / `deploy-global` ↔ k8s.core.deployment / daemonset (when k8s/core lands).
- `docker.compose.endpoint_mode` (vip / dnsrr) ↔ `docker.networking.swarm-routing-mesh`.
- `docker.compose.compose-profile` ↔ `compose CLI --profile flag` (no separate concept; activation surface).
- `docker.compose.cfg.services.depends_on` ↔ `docker.engine.feature.health-check` (depends_on.condition: service_healthy reads container's healthcheck state).
- `docker.compose.cfg.services.network_mode` ↔ `docker.engine.cfg.container-run-flag.network`.

In-leaf edges:

- `compose-application` is composed-of `compose-service`s, `compose-network`s, `compose-volume`s, `compose-config`s, `compose-secret`s.
- `compose-project` instantiates one `compose-application` on a host (with project name + isolation).
- `compose-include` brings in additional `compose-application` content.
- `multi-file-merge` and `compose-extends` are two ways to compose multiple Compose files into one model.
- `service-depends-on` has 4 conditions: `started`, `healthy`, `completed-successfully` (and the implicit default = started).
- `service-deploy-strategy` chooses among `deploy-replicated`, `deploy-global`, `deploy-replicated-job`, `deploy-global-job`.
- `compose-watch` rules trigger one of {sync, rebuild, restart, sync+restart, sync+exec}.
- `compose-profile` enables/disables `compose-service`s based on activation list.
- `service-healthcheck` is consumed by `service-depends-on-condition-healthy`.
- `service-startup-order` and `service-shutdown-order` are inverses of each other.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase D)
- Predecessor leaf logs: `domains/docker/{engine,runtime,networking}/PROGRESS.md`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
- Phase 1.5 candidate: fetch `docs.docker.com/reference/cli/docker/compose/*` man pages to enrich `docker.compose.cmd.*` flag detail.
