# Harness CLI — interview-day debugging tool

Status: Phase 9 complete. 8 subcommands operational against the 7-domain corpus + live-capture bundles.

## Subcommands

| Subcommand | Purpose | Example |
|---|---|---|
| `pnpm harness stats` | Per-domain row counts (sources/documents/concepts/commands/config_keys/failure_modes/relationships) | `pnpm harness stats` |
| `pnpm harness lookup <text>` | BM25 search across `documents` of all 5 domains + LIKE on concepts/commands/failure_modes | `pnpm harness lookup "OOM killer cgroup"` |
| `pnpm harness playbook <id>` | Render a failure mode as runbook: symptom → diagnostic_steps → fix_steps → citations | `pnpm harness playbook linux.fm.cgroup-memory-oom-kill` |
| `pnpm harness concept <id>` | Print a concept + outgoing/incoming relationships across domains | `pnpm harness concept linux.primitives.cgroup-v2` |
| `pnpm harness related <id> [depth]` | BFS the relationships graph to depth N (default 2, max 4) | `pnpm harness related linux.primitives.cgroup-v2 3` |
| `pnpm harness cite <source-id>` | Look up a source's URL/title/tier/license for citation | `pnpm harness cite kernel-docs-cgroup-v2` |
| `pnpm harness query <text>` | Stub (legacy) | — |
| `pnpm harness capture <bundle>` | Run a curated diagnostic-command bundle and emit Markdown blob | `pnpm harness capture oom` |
| `pnpm harness capture --from-fm <id>` | Synthesize a bundle from a failure_mode's diagnostic_steps | `pnpm harness capture --from-fm docker.fm.exit-137-oomkilled` |
| `pnpm harness capture --list` | List available bundles | `pnpm harness capture --list` |
| `pnpm harness drill <id>` | Interactive practice REPL — walk a scenario turn-by-turn, score keywords/commands you mention | `pnpm harness drill 01-docker-oom` |
| `pnpm harness drill random` | Pick a random drill | `pnpm harness drill random` |
| `pnpm harness drill --list` | List available drills | `pnpm harness drill --list` |

## Corpus snapshot

```
domain         sources  documents  concepts  commands  config_keys  failure_modes  relationships
docker         104      104        400       58        869          24             96
linux          172      172        521       65        1125         23             43
k8s            62       62         274       45        359          21             60
devin          327      327        319       338       357          15             26
methodology    44       44         121       50        36           12             33
TOTAL          709      709        1635      556       2746         95             258
```

258 relationships breakdown:
- 154 SQL-derived `affects-concept` edges (failure_modes → affected_concepts)
- 104 hand-curated cross-domain edges (51 distinct rel_types) wired through the chains:
  - cgroup/memory: docker.engine.cgroup-v2 → linux.primitives.cgroup-v2 → k8s.runtime.kubelet-pod-cgroup
  - capabilities/seccomp: docker.engine.seccomp-profile → linux.primitives.seccomp-subsystem ← k8s.core.security-context
  - networking/iptables: docker.engine.iptables-management + k8s.networking.kube-proxy-iptables → linux.networking.iptables-subsystem
  - dns: docker.networking.embedded-dns + k8s.networking.coredns → linux.networking.dns-protocol
  - overlayfs: docker.engine.overlay2-driver + k8s.runtime.container-rootfs → linux.filesystem.overlayfs
  - cri/runc: k8s.core.cri → docker.runtime.cri-plugin; k8s.runtime.containerd ↔ docker.runtime.containerd

## FTS indexes

All 5 domain FTS indexes built with `PRAGMA create_fts_index('<d>.documents', 'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1)`. Function name is `fts_<schema>_<table>.match_bm25(<doc_id>, <query>)` (note: `fts_<schema>_documents`, not `fts_main_<schema>_documents` as one might guess from official examples).

## Verified queries

- `lookup "OOM killer cgroup"` → top hit `k8s-node-pressure-eviction` (6.16), then `systemd-systemd-scope-5` (5.86), `kernel-docs-cgroup-v2` (5.43), `oci-runtime-spec-config-linux` (4.79) — cross-domain BM25 surfaces relevant authoritative sources.
- `lookup "iptables NAT prerouting"` → `man7-iptables-8` (7.92), `debian-nft-8` (7.82), `man7-iptables-extensions-8` (6.63), `k8s-kube-proxy` (4.92) — works across linux/docker/k8s.
- `playbook linux.fm.cgroup-memory-oom-kill` → renders 3 diagnostic steps + 1 fix step with proper kernel-docs and systemd citations.
- `concept linux.primitives.cgroup-v2` → renders concept + 6 incoming relationships from docker/k8s/linux-systemd.
- `related linux.primitives.cgroup-v2 2` → reaches docker.engine.cgroup-v2, docker.runtime.runc, k8s.runtime.cgroup-driver-cgroupfs, k8s.runtime.cgroup-v2, k8s.runtime.kubelet-pod-cgroup, linux.systemd.cgroup-integration at d=1; reaches k8s.runtime.cgroup-driver-systemd, k8s.runtime.crun, linux.primitives.namespace-subsystem at d=2.
- `cite kernel-docs-cgroup-v2` → returns title/URL/tier/license correctly.

## Architecture

```
packages/harness/src/
  index.ts              # arg router: pnpm harness <sub> [args]
  paths.ts              # repoRoot, dbPath
  db.ts                 # openDb(), DOMAINS constant, bigintReplacer
  commands/
    index.ts            # subcommand registry
    query.ts            # stub
    lookup.ts           # BM25 + LIKE across 5 domains
    playbook.ts         # failure mode runbook renderer
    concept.ts          # concept + relationships
    related.ts          # bidirectional BFS via recursive CTE
    cite.ts             # source detail
    stats.ts            # corpus rollup
```

Pattern: each command opens the DB via `openDb()`, builds a per-domain UNION ALL query over the `DOMAINS` array, casts `db.all(sql)` results through small `interface XRow {}` types via `as unknown as XRow[]`. SQL is built as template strings; all user input is `.replace(/'/g, "''")`-escaped. `tsc --noEmit` passes clean against `@mark1russell7/cue/ts/config/node.json` strictness (TS4111 included).

## Typecheck

`pnpm --filter @domains/harness typecheck` passes clean.

## Phase 9 — Live capture bundles

Added `harness capture` for live system-state snapshots. Useful when an interview-day SE wants to gather all diagnostic output for a symptom in one paste-able blob, rather than typing 5-8 commands sequentially.

### Bundles shipped

8 bundles at `packages/harness/bundles/`:

| Bundle | Platform | Commands |
|---|---|---:|
| `oom` | linux-or-wsl | 7 |
| `network-egress` | linux-or-wsl | 9 |
| `dns` | linux-or-wsl | 8 |
| `systemd-unit` | linux-or-wsl | 7 |
| `k8s-pending` | kubectl-only | 8 |
| `docker-state` | docker-only | 7 |
| `perf-stalls` | linux-or-wsl | 9 |
| `devin-vpn` | linux-or-wsl | 9 |

Schema documented at `packages/harness/bundles/SCHEMA.md`.

### `--from-fm` synthesis

Any failure_mode in the corpus can be turned into a bundle on the fly:

```
pnpm harness capture --from-fm docker.fm.exit-137-oomkilled
```

The harness extracts `diagnostic_steps` from the playbook, filters out comment-placeholders, and runs each as a command. Lets the corpus drive capture without writing N more bundle files.

### Cross-platform shell detection

`detectShell()` picks the right shell per host:

| OS | Order tried |
|---|---|
| Linux/macOS | `/bin/sh` |
| Windows | `wsl.exe bash -c` → `bash.exe -c` (Git Bash) → `cmd.exe /c` |

Selected shell is reported in the capture output header (e.g. `via wsl`).

### Default redactions

Applied to every command's output before display:

- AWS access key IDs (`AKIA[0-9A-Z]{16}`)
- GitHub PATs (`ghp_[A-Za-z0-9]{36}`)
- JWTs (`eyJ...eyJ...`)
- `password=`/`token=`/`api_key=` patterns (case-insensitive lookbehind, 8-20+ chars after)

Per-bundle additional regex patterns supported via the `redact` field.

### Verified on Windows

- `pnpm harness capture --list` → 8 bundles listed correctly
- `pnpm harness capture docker-state` → all 7 commands ran via WSL, real Docker Desktop output captured
- `pnpm harness capture --from-fm docker.fm.exit-137-oomkilled` → 4 diagnostic_steps from playbook ran, `dmesg` returned actual recent OOM kills from WSL kernel
- `pnpm harness capture <bundle> --output file.md` → 12057 bytes written cleanly
- Redaction test: AWS key, GitHub PAT, password=, JWT all replaced with `<REDACTED>` in output

## Phase 10 — Interactive drill mode

Added `harness drill` for practice — turn-by-turn playback of the 10 rehearsal scenarios with scoring against expected keywords/commands.

### Drill scenarios shipped

10 drill JSONs at `packages/harness/drills/` mirroring the markdown scenarios at `domains/_shared/rehearsal/scenarios/`. Schema at `packages/harness/drills/SCHEMA.md`.

| Drill | Difficulty | Turns |
|---|---|---:|
| `01-docker-oom` | entry | 3 |
| `02-container-egress-tree` | mid | 4 |
| `03-pod-pending` | mid | 4 |
| `04-dns-slow-pod` | mid | 4 |
| `05-app-slow-cpu-low` | advanced | 3 |
| `06-devin-internal-svc` | mid | 4 |
| `07-systemd-unit-wont-start` | entry-mid | 4 |
| `08-process-d-state` | advanced | 4 |
| `09-image-pull-fail` | mid | 4 |
| `10-postmortem-blame` | soft-skills | 4 |

### How drill mode works

1. Show a turn's `user_message`.
2. Wait for input — multi-line answer terminated by `.` on its own line.
3. Special inputs: `hint` (next progressive hint), `show` (reveal canonical without scoring), `skip`, `quit`.
4. Score: substring match the user's answer against `expected_harness_commands` and `expected_keywords` (case-insensitive).
5. Show coverage (e.g. `7/10`), the canonical SE response, then move to next turn.
6. Final summary: total cmd/keyword coverage, top-12 missed concepts to study.

### Cross-platform input handling

Detects TTY-vs-piped stdin:
- TTY: standard `readline` interactive prompt.
- Piped (CI / scripted invocation): reads all of stdin upfront, replays line-by-line. Lets the drill be smoke-tested via `printf`.

Verified on Windows: `--list`, `random`, number-prefix resolution (`drill 04` → `04-dns-slow-pod`), hint cycling (`hint` 3x then "no more hints"), `show` reveals canonical, `quit` aborts cleanly, scripted scoring works (e.g. `printf 'docker inspect OOMKilled dmesg memory.events --memory cgroup SIGKILL 137\n.\nshow\nshow\n' | pnpm harness drill 01-docker-oom` produced "7/10 keywords hit, missed: killed process").

### Drill ID resolution

Accepts:
- Full slug: `01-docker-oom`
- Number prefix: `01` (zero-padded if needed)
- Filename with extension: `01-docker-oom.json`

## Known limitations

- BM25 query is escaped only for single-quote SQL injection; complex query syntax (FTS operators) passes through as-is.
- `related` walks edges bidirectionally as undirected; the displayed `<-` / `->` arrows in `concept` show the original directionality.
- No Windows/Linux capture command yet (planned: `harness capture` to dump vmstat/ss/dmesg snapshots into a context bundle).
- `query` is the original stub from initial scaffold; superseded by `lookup`/`stats`.

## Next phases (out of scope here)

- Phase 6.5: `harness capture` for live system-state snapshots (Linux-only via WSL or remote SSH).
- Phase 6.6: streaming output (currently builds full result set in memory).
- Phase 7+: interview-day rehearsal — feed realistic failure prompts, measure time-to-citation.
