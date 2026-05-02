# Plan — `methodology/use-red-method`

> Stub form. Phases A and B were done at the domain level in session 1.1 (44 sources / 1.27 MB into `methodology.{sources,documents}` + FTS). This file tracks the per-leaf work that happens *after* the corpus exists.

## Context

USE Method (Brendan Gregg), RED Method (Tom Wilkie), off-CPU analysis, Flame Graphs, eBPF-era diagnostic tooling (`perf`, `bpftrace`, `bcc`, `perf-tools`). The "what to measure and how to find the bottleneck" half of the methodology layer.

Underpins docker/runtime, linux/primitives, linux/networking, and devin/devbox failure-modes — the framework names land here so docker/linux failure-modes can list them in `affected_concepts`.

## Phase status

| Phase | Status | Where |
| --- | --- | --- |
| A — Survey | DONE | `methodology.sources WHERE subdomain='use-red-method'` (18 sources, T1–T3) |
| B — Document ingest | DONE | `methodology.documents` (18 docs, ~622 KB total). FTS built. |
| C — Concepts/Commands/Config-keys | **THIS SESSION** | extract/{concepts,commands,config_keys}.json → `methodology.concepts/commands/config_keys` |
| D — Failure-modes | DEFERRED | Horizontal phase (per PREAMBLE doctrine). Methodology rarely has its own failure-modes; its value is being the `affected_concepts` referent for docker/linux failure-modes. |
| E — Relationships | DEFERRED | Horizontal phase. Cross-domain links land after every domain has P3. |

## Phase C scope

Targets (full-range per session plan):
- ~70 concepts
- ~120 commands
- 0 config_keys (use-red-method is concept/command-heavy; config_keys live in sre-debugging)

Sources prioritized (see plan §2 of `~/.claude/plans/groovy-yawning-raven.md`):

- `brendangregg-perf` (210 KB) — gold one-liner index, ~50 commands
- `bpftrace-language` (71 KB) + `bpftrace-stdlib` (56 KB) — probe types + builtin functions, ~50 commands + ~15 concepts
- `brendangregg-flamegraphs` (64 KB), `brendangregg-offcpu`, `brendangregg-cpu-utilization-wrong` — concepts + commands
- `brendangregg-ebpf` (102 KB) — eBPF construct concepts (kprobe, uprobe, tracepoint, USDT, BPF map, ring buffer)
- `brendangregg-usemethod` + `brendangregg-use-method-linux` — USE meta + per-resource subtypes
- `bcc-readme` — one concept per BCC tool (~30)
- `perf-tools-readme` — Brendan's wrapper scripts (~10 concepts)
- `bpftrace-oneliners` — additive curated tutorial, ~10 commands

Sources deferred:
- `brendangregg-return-of-frame-pointers` — specialist topic; ingestion already in DB but skipped for P3 yield
- `brendangregg-mongodb` and other case studies — narrative, low row yield

## Phase C non-droppable hooks

These IDs MUST land — they're cross-domain referents for docker/linux failure-modes in Phase 4:

- `methodology.use-method`
- `methodology.red-method`
- `methodology.off-cpu-analysis`
- `methodology.flame-graph`
- `methodology.ebpf`
- `methodology.cmd.perf.record`
- `methodology.cmd.perf.stat`
- `methodology.cmd.bpftrace.kprobe`

## Open questions

(populated during execution)
