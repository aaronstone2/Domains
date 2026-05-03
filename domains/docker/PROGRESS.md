# Docker — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.1 — 2026-05-02 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-1-sou-sparkling-biscuit.md`; pipe-able session prompt `domains/_shared/sessions/phase-1-source-corpus.md`.

**Outputs:**

- **90 sources, 90 documents, 1,253,972 chars indexed** in `docker.sources` / `docker.documents`.
- BM25 FTS index `fts_docker_documents` built (porter stemmer, english stopwords).

**Per-subdomain breakdown:**

| subdomain      | sources | mean chars | total chars | T1 | T2 | T3 | redistribute-ok | reference-only | unknown |
|---             |---:     |---:        |---:         |---:|---:|---:|---:             |---:            |---:     |
| engine         | 28      | 14,854     | 415,904     | 25 | 1  | 2  | 6               | 20             | 2       |
| runtime        | 17      | 15,457     | 262,776     | 16 | 0  | 1  | 16              | 0              | 1       |
| compose        | 16      | 9,588      | 153,404     | 16 | 0  | 0  | 15              | 1              | 0       |
| build-buildkit | 12      | 20,756     | 249,074     | 12 | 0  | 0  | 5               | 7              | 0       |
| networking     | 9       | 11,576     | 104,184     | 9  | 0  | 0  | 3               | 6              | 0       |
| security       | 8       | 8,579      | 68,630      | 8  | 0  | 0  | 0               | 8              | 0       |

By tier: T1=86, T2=1 (wsargent CC-BY-4.0), T3=3 (iximiuz × 3, license unverified — private corpus only).

By license: redistribute-ok=45, reference-only=42, unknown=3.

**Net delta:** existing docker rows = 11; removed `docker-compose-spec-gh` (replaced by 15 modular files from compose-spec/compose-spec); fixed `oci-runtime-spec-gh` URL from `/blob/main/spec.md` to `raw.githubusercontent.com/.../main/spec.md` (was an HTML-page URL paired with `parser: github-md` — would have ingested HTML, never tested before this session); added 81 net-new entries.

**Verified (acceptance per plan):**

- All 90 sources fetched (0 fetch failures, 0 unfetched).
- Mean doc length 13,933 chars (above 5,000 threshold; methodology pilot was 28,874).
- 0 thin docs <500 chars (threshold ≤4). ✓
- 9 small docs <2 KB:
  - `docker-docs-root` (549) — landing page; intentional.
  - `compose-spec-00-overview` (803) — overview file; intentional.
  - `iximiuz-tag-docker` (884) — tag-index page; expected (link list, not content).
  - `runc-create-8` (1,301), `docker-cli-container-inspect` (1,351), `docker-docs-build-bake` (1,342), `docker-docs-build-cache` (1,586), `runc-run-8` (1,695), `runc-spec-8`/`compose-spec-15-profiles`/`docker-docs-compose-startup-order`/`compose-spec-09-secrets`/`runc-exec-8`/`moby-buildkit-multi-platform`/`compose-spec-08-configs` near 1.5–3 KB.
- BM25 FTS index built; 7 verification queries below.

**BM25 verification queries (top-5 per query):**

| # | Query | Top-5 (score) | Expected hit in top-5? |
|---|---|---|---|
| 1 | rootless docker permission denied | moby-buildkit-rootless 3.80, docker-docs-engine-security 3.66, docker-docs-security-apparmor 3.52, **docker-docs-userns-remap 3.34**, docker-docs-security-seccomp 3.00 | partial (userns-remap ✓; rootless missing — see follow-up) |
| 2 | OCI runtime exec failed | iximiuz-debugger-images 3.69, docker-docs-cli-dockerd 3.13, **runc-exec-8 2.95**, **oci-runtime-spec-runtime 2.89**, moby-buildkit-buildkitd-toml 2.71 | partial (runc-exec-8 ✓, runtime-spec adjacent ✓) |
| 3 | exit code 137 OOMKilled | containerd-getting-started 2.23, docker-cli-container-ls 1.97, compose-spec-deploy 1.83, **docker-cli-container-run 1.51**, moby-buildkit-dockerfile-reference 1.48 | partial (container-run ✓) |
| 4 | iptables DOCKER chain | **docker-docs-network-firewall 3.70**, docker-docs-daemon-remote-access 2.16, docker-docs-cli-dockerd 1.77, docker-docs-security-certificates 1.71, docker-cli-container-exec 1.64 | partial (firewall ✓; bridge missing) |
| 5 | buildkit cache backend | moby-buildkit-readme 4.27, docker-docs-build-buildkit 4.06, compose-spec-build 3.86, **moby-buildkit-buildkitd-toml 3.82**, moby-buildkit-dockerfile-reference 3.40 | partial (buildkitd-toml ✓; multiple buildkit hits) |
| 6 | compose depends_on healthcheck condition | **docker-docs-compose-startup-order 5.99**, **compose-spec-05-services 4.66**, compose-spec-13-merge 2.96, compose-spec-deploy 2.54, wsargent-docker-cheat-sheet 2.29 | full ✓ |
| 7 | image pull manifest unknown | **oci-distribution-spec 5.08**, **oci-image-spec-manifest 4.17**, oci-image-spec-config 3.03, moby-buildkit-readme 2.65, docker-docs-buildkit-configure 2.59 | full ✓ |

**Q1 partial-miss analysis:** the docker-docs-rootless body (4,679 chars) does NOT contain the literal phrase "permission denied"; it links out to the troubleshoot page (which we did not ingest). moby-buildkit-rootless wins because it has both terms. Action item: add `docker-docs-rootless-troubleshoot` (https://docs.docker.com/engine/security/rootless/troubleshoot/) in a Phase 1.5 follow-up. The plan agent flagged it, but it was trimmed during dedupe.

**Q4 partial-miss analysis:** docker-docs-network-bridge ranked 6+. It's a 23 KB doc that mentions iptables but uses "DOCKER" (uppercase) as a container/runtime name, diluting the term-frequency for "DOCKER chain". The firewall page (winner) is the tighter hit. Acceptable.

**Sources failed:** none (0 of 90).

**Source list adjustments made during execution:**

- Removed `docker-compose-spec-gh` (single 80 KB merged spec.md) and replaced with 15 modular `compose-spec-*` files. Rationale: per-concept FTS isolation. Confirmed by Q6 — `compose-spec-05-services` ranks 2nd for the depends_on/healthcheck query.
- Fixed `oci-runtime-spec-gh` URL from `https://github.com/.../blob/main/spec.md` (returns rendered HTML) to `https://raw.githubusercontent.com/.../main/spec.md` (returns raw markdown). The previous URL was paired with `parser: github-md` (passthrough), so a fetch would have ingested HTML wrapper noise, never tested before this session because docker-domain fetches hadn't run.
- Added `notes:` clarifying license-unverified status on 3 iximiuz entries; methodology pilot has prior art for this (Wizard Zines).

**Infra delta (this session):** none. All work reused the methodology-pilot pipeline (`ingest fetch` → JSONL staging → motherduck MCP `INSERT OR REPLACE BY NAME` → `PRAGMA create_fts_index`). The auto-fallback wrapper for thin trafilatura pages was not needed — Step-0 verification confirmed trafilatura returns clean docs.docker.com markdown without Hugo-shortcode pollution.

**License posture (verified during plan-mode):**

- `docs.docker.com` — `reference-only` (proprietary docs, Docker Inc. publication despite Apache-2 source repo). 42 entries.
- `raw.githubusercontent.com/...` (moby/buildkit, opencontainers/*, containerd/*, compose-spec, docker/cli, wsargent) — `redistribute-ok` (Apache-2 verified per repo LICENSE). 45 entries.
- `iximiuz.com` — `unknown` (no CC license statement found on footer). 3 entries with `notes: license unverified — private corpus only`. **Action item: verify license posture if iximiuz content appears in interview-day output.**

**Deferred to later sessions:**

- `docker-docs-rootless-troubleshoot` (https://docs.docker.com/engine/security/rootless/troubleshoot/) — Q1 BM25 result indicates a corpus gap; trimmed during dedupe but should be added.
- `moby/moby/api/swagger.yaml` (Engine API OpenAPI spec) — deferred per plan; needs custom `parser: openapi-yaml` flattener to be FTS-friendly.
- Custom `manpage` parser preserving SYNOPSIS/DIAGNOSTICS — trafilatura/github-md adequate.
- `mintlify` parser — devin-only, not used in docker.
- Additional runc man pages (kill, state, delete, list, ps, update, pause, etc.) — 14 man pages skipped per plan; can fold in selectively in Phase 1.5.
- 5 docker/cli man pages skipped (system_*, volume_*, image_push, container_kill, container_stop) — interview-likelihood low.
- 7 OCI image-spec adjacent files skipped (image-layout.md, media-types.md, annotations.md, etc.) — Phase 1.5 candidates.
- 5 docs.docker.com network/security pages skipped (ipvlan, none, antivirus, trust-automation, content-trust) — P3 may surface need.

**Next phases for this domain:**

- **Phase 3** (Concepts/Commands/Config-keys): per the vertical-domain doctrine, this same vertical continues into `domains/_shared/sessions/phase-3-deep-extraction.md` for docker. Use the corpus we just built. Per leaf priority: `docker/engine` first (daemon failure modes are interview-most-likely), then `docker/runtime` (OCI/runc — exit codes, mount semantics), then `docker/networking`, `docker/build-buildkit`, `docker/compose`, `docker/security`.
- **Phase 4** (Failure-modes) — horizontal across all P3s; deferred until linux/devin/k8s also have P3 extraction.

### Session 1.5 — 2026-05-02 — DONE (gap-filler from session 1.1)

**Added 14 follow-up sources** flagged in session 1.1 PROGRESS.md `Deferred to later sessions`. Total docker rows now **104** (90 → 104), total content **1,336,795 chars** (was 1,253,972).

| subdomain      | added | new total | content delta |
|---             |---:   |---:       |---:           |
| engine         | 3     | 31        | +12,420 chars (container-kill, container-stop, system-df) |
| networking     | 3     | 12        | +34,088 chars (ipvlan 27 KB, none, image-push) |
| security       | 3     | 11        | +20,720 chars (rootless-troubleshoot 16 KB, trust-automation, antivirus 725 chars) |
| runtime        | 5     | 22        | +15,595 chars (runc-kill/state/delete, image-spec image-layout/media-types) |

**Verified:**

- All 14 follow-up fetches succeeded (0 failures); total docker fetches now 104/104.
- 1 thin doc <500 chars (runc-state-8 at 261 — Cobra-generated minimal man page; acceptable, threshold ≤4).
- BM25 FTS index rebuilt.
- **Q1 re-run** ("rootless docker permission denied") now returns top-5: moby-buildkit-rootless 3.89, docker-docs-engine-security 3.72, docker-docs-security-apparmor 3.62, **docker-docs-userns-remap 3.41**, **docker-docs-rootless-troubleshoot 3.38**. **2 of 2 expected hits ✓** — corpus gap closed.

**Why these 14 and not the rest of the deferred list:**

- docker-docs-rootless-troubleshoot — explicit Q1 corpus gap from session 1.1.
- runc-{kill,state,delete}-8 — listed as P2 in original plan (leaked-container debugging surface); cheap to fetch.
- oci-image-spec-{image-layout,media-types} — define filesystem layout + media-type semantics for image-format errors; complement existing oci-image-spec-{config,manifest,descriptor}.
- docker-docs-network-{ipvlan,none} — networking driver completeness alongside existing bridge/overlay/host/macvlan rows.
- docker-docs-security-{trust-automation,antivirus} — flagged in session 1.1 as P3-may-surface-need; cheap to add now.
- docker-cli-{container-kill,container-stop,system-df,image-push} — interview-likely commands (signal handling, graceful shutdown, disk-usage debugging, registry push errors) skipped in original plan.

**Still deferred:**

- moby/moby/api/swagger.yaml — needs custom `parser: openapi-yaml` flattener.
- 11 remaining runc man pages (pause, resume, restore, checkpoint, events, list, ps, update, start) — niche/CRIU surface, low interview-likelihood.
- Custom `manpage` strict parser — trafilatura/github-md adequate.

## Phase 3 — Concepts / Commands / Config-keys (per-leaf rollup)

| Leaf | concepts | commands | config_keys | session log |
|---|---:|---:|---:|---|
| `docker/engine` | 90 | 16 | 217 | [domains/docker/engine/PROGRESS.md](engine/PROGRESS.md) |
| `docker/runtime` | 78 | 12 | 138 | [domains/docker/runtime/PROGRESS.md](runtime/PROGRESS.md) |
| `docker/networking` | 56 | 10 | 100 | [domains/docker/networking/PROGRESS.md](networking/PROGRESS.md) |
| `docker/compose` | 61 | 8 | 184 | [domains/docker/compose/PROGRESS.md](compose/PROGRESS.md) |
| `docker/security` | 50 | 4 | 81 | [domains/docker/security/PROGRESS.md](security/PROGRESS.md) |
| `docker/build-buildkit` | 65 | 8 | 149 | [domains/docker/build-buildkit/PROGRESS.md](build-buildkit/PROGRESS.md) |
| **total** | **400** | **58** | **869** | |

**Phase 3 docker domain — DONE 2026-05-03.** All 6 leaves landed across 6 sessions (3.1–3.6). 1,327 rows total in concepts + commands + config_keys; commands carry an additional 614 flags + 141 examples in STRUCT arrays. 0 orphan source_ids domain-wide; 0 PK collisions across all 6 leaves. Verified: kind/scope distributions hit plan targets exactly or within tolerance per leaf.

Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (executed end-to-end).

Phase 1.5 candidates surfaced during P3 (deferred for a follow-up source patch):

- `docs.docker.com/reference/cli/docker/compose/{up,down,ps,logs,exec,run,build,restart}/` — compose CLI man pages (compose leaf had to source-derive flag detail from spec docs + cheat sheet).
- `docs.docker.com/reference/cli/docker/trust/*` — DCT CLI man pages (security leaf same).

P4 reservations (failure-mode mining, deferred horizontal pass):

- `docker-docs-engine-daemon-troubleshoot` (engine leaf, 17,549 chars).
- `docker-docs-rootless-troubleshoot` (security leaf, 16,065 chars).
- 60+ failure-mode seeds catalogued across the 6 PROGRESS files; ~10–12 per leaf.

## Cross-references

- Plan file (Phase 1): `~/.claude/plans/read-domains-shared-sessions-phase-1-sou-sparkling-biscuit.md`
- Master plan: `~/.claude/plans/i-am-applying-for-indexed-hellman.md`
- Pipe-able session prompts: `domains/_shared/sessions/phase-1-source-corpus.md`, `phase-3-deep-extraction.md`
- Methodology pilot reference: `domains/methodology/PROGRESS.md` (44 sources / 1.27 MB precedent)
