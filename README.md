# Domains

Multi-domain debugging knowledge corpus + interactive harness, built for an **AI Support Engineer** screen-share interview at Cognition (Devin.ai).

## Interview-day one-liner

On a fresh Linux VM (Debian/Ubuntu), with sudo:

```bash
git clone https://github.com/aaronstone2/Domains && cd Domains && \
  ./bootstrap.sh --anthropic-key='sk-ant-...' --launch
```

That's it. The bootstrap script:

1. Installs the diagnostic + productivity stack (`tcpdump`, `sysstat`, `lsof`, `strace`, `ripgrep`, `fzf`, `htop`, `jq`, etc.) plus optionals (`bpfcc-tools`, `bpftrace`, `perf`)
2. Installs Node.js + Claude Code via `npm -g`
3. Installs `atuin` (shell history), `zoxide` (smarter cd), `eza`, `bat`
4. Seeds `atuin` with curated commands from `cmd_history.txt` (so Ctrl-R immediately finds your debug recipes)
5. Adds a `~/.bashrc` block (idempotent — re-runs replace cleanly) that wires up aliases (`h=pnpm harness`, `cheat=open the cheatsheet`, etc.), atuin, zoxide, fzf
6. Installs corpus deps (`pnpm install`)
7. Launches `claude --model claude-opus-4-7 --effort max` with the API key set

API keys are **never stored in the repo**; they're passed at run time and live only in process env.

### Other usage patterns

```bash
# Just install tools, don't launch Claude (so you can re-run later)
./bootstrap.sh

# Minimal install — skip bpfcc-tools / btop / sysbench (faster)
./bootstrap.sh --minimal

# Add k8s + AWS tools (for ECR / EKS scenarios)
./bootstrap.sh --with-k8s --with-aws

# Just tools, no shell config (e.g. you have your own .bashrc)
./bootstrap.sh --no-shell-config

# See all flags
./bootstrap.sh --help
```

## What's in this repo

```
bootstrap.sh                          ← interview-day installer
.aliases                              ← sourced by bashrc; harness shortcuts
cmd_history.txt                       ← seed commands for atuin

domains/                              ← knowledge corpus by domain
  docker/       linux/      k8s/
  devin/        methodology/  firecracker/  ecs/
  _shared/
    sources.yaml                      ← global source registry (767 sources)
    PROGRESS.md                       ← per-phase build log
    rehearsal/
      CHEATSHEET.md                   ← single-page interview reference
      scenarios/                      ← 10 deep multi-turn rehearsal scenarios

packages/
  cli/                                ← repo scaffolding CLI
  harness/                            ← interview-day query tool
    src/commands/                     ← 9 subcommands
    bundles/                          ← 8 capture bundles for live snapshots
    drills/                           ← 10 interactive practice scenarios

_db/knowledge.duckdb                  ← gitignored; built locally from extract/ JSONs
```

## Corpus snapshot

767 sources, 1889 concepts, 706 commands, 3019 config_keys, **415 failure_modes**, 1551 relationships across 7 domains.

| Domain | sources | concepts | failure_modes | relationships |
|---|---:|---:|---:|---:|
| docker | 104 | 400 | 74 | 333 |
| linux | 172 | 521 | 91 | 315 |
| k8s | 62 | 274 | 64 | 268 |
| devin | 327 | 319 | 37 | 150 |
| methodology | 44 | 121 | 28 | 115 |
| firecracker | 37 | 172 | 71 | 236 |
| ecs | 21 | 82 | 50 | 134 |

## Harness (interview-day query tool)

After bootstrap, from any shell with the repo's `.aliases` sourced:

```bash
ha "OOMKilled in pod logs"              # one-shot: top fm + talk-track + diag/fix + citations
ha "kubectl drain hangs on PDB"         # use this 80% of the time during the interview
h stats                                 # corpus inventory + quality grades
hl "DNS slow ndots"                     # browse mode — multi-section search
hp k8s.fm.dns-pod-search-too-many       # re-render a playbook by id
hrel linux.primitives.cgroup-v2 2       # walk the relationship graph
hcap oom                                # capture an OOM diagnostic snapshot
hcap --from-fm docker.fm.exit-137-oomkilled   # synthesize from any fm
hd 01-docker-oom                        # interactive practice mode
cheat                                   # open the cheat sheet
```

`harness ask` is the **primary entry point**. It picks the top failure mode for the symptom, renders a polished sectioned response (META → TALK TRACK → DIAGNOSE → FIX → CITATIONS → NEXT) with ANSI colors when the terminal supports them, and includes a "talk track" the user can read aloud to demonstrate the eval criteria (curiosity → diagnose → trade-off → fix).

Full subcommand reference: `packages/harness/PROGRESS.md`.

## Practice material

- **`domains/_shared/rehearsal/CHEATSHEET.md`** — single-page interview reference (exit codes, symptom→fm tables, error-message taxonomy, 5-second mental models, tool quick-ref, methodology cheats, harness commands)
- **`domains/_shared/rehearsal/scenarios/`** — 10 deep multi-turn rehearsal scenarios, each ~200-300 lines: docker OOM, container egress, pod Pending, DNS slow, off-CPU stalls, Devin networking, systemd, D-state, image pull, postmortem-blame
- **`pnpm harness drill <id>`** — interactive REPL of any scenario; pauses for your response, scores keyword/command coverage, reveals canonical answer

## Build sequence

The corpus was built in 11 phases — see `domains/_shared/PROGRESS.md` for the full session log:

| Phase | Output |
|---|---|
| P0 | DuckDB schema, ingest pipeline, harness scaffold |
| P1 | 767 sources fetched + indexed across 7 domains |
| P3 | 1889 concepts, 706 commands, 3019 config_keys extracted |
| P4 + P4.5 | 415 failure_modes (cgroup OOM, DNS, egress, systemd, etc.) |
| P5 + P5.5 | 1551 relationships (intra-domain + cross-domain) |
| P6 | Harness CLI (lookup, playbook, concept, related, cite, stats) |
| P7 + P7.2 | Rehearsal verification (20/21 = 95% prompt-to-fm coverage) |
| P8 | 10 deep multi-turn rehearsal scenarios |
| P9 | `harness capture` — live system-state snapshot bundles |
| P10 | `harness drill` — interactive practice REPL |
| P11 | Single-page cheat sheet |
| P12 | `bootstrap.sh` — interview-day installer (this) |
| P13–17 | Quality pass: 145 fms deepened to 3+ diag / 2+ fix steps with concrete commands |
| P18 | MCP polish — `harness ask` one-shot, talk-track, sectioned ANSI output, aligned tables |

## Tech notes

- **Schema-per-domain DuckDB** with shared `meta` views; every domain has the same 7 tables (sources, documents, concepts, commands, config_keys, failure_modes, relationships)
- **BM25 FTS** via DuckDB's `fts` extension; per-domain indexes
- **Python ingest** at `domains/_shared/ingest/` (uv-managed) — `httpx` fetch → `trafilatura`/`manpage`/`github-md` parsers → JSONL staging → bulk load
- **TypeScript harness** at `packages/harness/` (Node 22, ESM, `duckdb-async`, `@clack/prompts`, no build step — `tsx` runs source directly)
- **pnpm workspace** with two top-level dirs: `domains/<n>/` (research) and `packages/<n>/` (TS code)

## License

Knowledge content is curated from public sources (man pages, kernel docs, vendor docs, blog posts) with `license_note` field per source distinguishing redistribute-ok from reference-only. The harness code (TS) is the author's own.
