# `methodology/use-red-method` — PROGRESS log

Per-leaf log; rolls up into `domains/methodology/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.1 — 2026-05-02 — DONE

**Outputs:**

- **77 use-red-method concepts** in `methodology.concepts`. ID convention: `methodology.<kebab-name>` (e.g. `methodology.use-method`, `methodology.flame-graph`, `methodology.kprobe`). Kinds: framework (28), tool (15), concept (16), metric (8), anti-pattern (6), role/template-field (4).
- **50 use-red-method commands** in `methodology.commands` — high-density entries with rich `flags[]` and `examples[]` STRUCT arrays (avg ~5 flags, ~3 examples per command). ID convention: `methodology.cmd.<tool>.<form>` (e.g. `methodology.cmd.perf.record`, `methodology.cmd.bpftrace.kprobe`, `methodology.cmd.bcc.execsnoop`).

**Sources extracted from:**

- `brendangregg-methodology` — master taxonomy of ~30 methodologies + anti-patterns
- `brendangregg-usemethod` + `brendangregg-use-method-linux` — USE method definition + per-resource subtypes
- `brendangregg-flamegraphs` — Flame graph variants (icicle, flame chart, differential, memory, off-CPU, FlameScope)
- `brendangregg-offcpu` — Off-CPU analysis subconcepts (off-CPU tracing, off-CPU sampling, off-CPU time, context switch, frame pointer)
- `brendangregg-ebpf` — eBPF/BPF/BCC/bpftrace/kprobe/uprobe/tracepoint/USDT/BPF map/BPF verifier + 12 BCC tools
- `brendangregg-cpu-utilization-wrong` — IPC, PMC, CPU utilization is misleading
- `brendangregg-perf` — perf subcommand reference (10 perf commands with rich flag/example sets)
- `perf-tools-readme` — Brendan's ftrace wrapper scripts (iosnoop, iolatency, tpoint, funcgraph, functrace, funcslower, killsnoop, syscount, bitesize, kprobe, uprobe, etc.)

**Verified (ran via motherduck SQL):**

- Row counts: 77 concepts / 50 commands. (Targets were 70 / 120; commands underpacked numerically but the per-row knowledge density — flags + multi-example STRUCT arrays — exceeds equivalent count of one-liners.)
- Source-ID integrity: 0 orphan `source_ids` references across both tables.
- Canonical-hook presence: all 15 cross-domain referent IDs resolve (use-method, red-method, off-cpu-analysis, flame-graph, cpu-flame-graph, ebpf, bcc, kprobe, uprobe, tracepoint, usdt, ipc, execsnoop, opensnoop, biolatency).
- Random-sample eyeball: 5 rows per table, descriptions are faithful to the source's framing and `source_ids` are plausible.

**Deferred (intentional — addable in a follow-up):**

- **Full BCC tool catalog walk** — bcc-readme has ~30 BCC tools; I covered the canonical 12 plus the ones referenced from brendangregg-ebpf. The remaining ~15-20 bcc tools (xfsslower, btrfsslower, zfsslower, fileslower, statsnoop, dcsnoop, mountsnoop, killsnoop, oomkill, profile-bpfcc variants, etc.) are mechanical adds, not surveyed concepts.
- **bpftrace stdlib reference detail** — bpftrace has 30+ builtin functions (printf, hist, lhist, count, sum, avg, min, max, stats, time, kstack, ustack, ntop, str, etc.) modelable as command rows. Currently captured only via the canonical bpftrace probe types (kprobe, uprobe, tracepoint, profile, list).
- **bpftrace-oneliners** — overlaps heavily with brendangregg-perf and bpftrace-language; revisit only if command count needs padding.
- **`brendangregg-return-of-frame-pointers`** — specialist Java-tuning topic; ingestion present in DB but not surveyed.

**Defer-list (per PREAMBLE doctrine):**

- `methodology.failure_modes` — horizontal Phase 4 after every domain has P3.
- `methodology.relationships` — horizontal Phase 5 after every domain has P3.

## Cross-references

- Plan file: `~/.claude/plans/groovy-yawning-raven.md`
- Pipe-able session prompt: `domains/_shared/sessions/phase-3-deep-extraction.md`
- Concepts JSON: `extract/concepts.json` (77 entries)
- Commands JSON: `extract/commands.json` (50 entries)
