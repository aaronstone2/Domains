# DevBox install — verified path

This document is the runbook for setting up a fresh Linux DevBox so the
domains corpus + harness MCP + Claude Code all work for an interview-day
screen-share or any practice session.

The bootstrap is now a thin bash trampoline + a TypeScript package.
The legacy 545-line bash bootstrap is preserved at `bootstrap.sh.legacy`
for one cycle of testing.

## Quick start

```bash
git clone https://github.com/aaronstone2/Domains ~/domains
cd ~/domains
./bootstrap.sh install --launch
```

You will be prompted for an Anthropic API key if none is found in the
fallback chain (see "Anthropic key" below). On success, `claude` is
exec'd with the corpus MCPs registered.

## What gets installed

The bootstrap is **modular**. Each `pnpm bootstrap` module is a
single-responsibility unit; failures are isolated and you can re-run
just the failing module without re-running everything.

Run `pnpm bootstrap list` after the trampoline gets Node + pnpm in place
to see the full registry with current state:

```text
SKIP  / NEEDED / INSTALLED   <id>                  <description>

apt-core            Always-installed apt packages (network/perf/process diagnostic + bash-completion)
apt-optional        Optional heavy apt packages (eBPF tooling, perf, btop, sysbench)
apt-docker          Docker engine + compose plugin (gated on --with-docker)
apt-k8s             kubectl from upstream stable release (gated on --with-k8s)
apt-aws             aws-cli v2 from awscli-exe-linux installer (gated on --with-aws)
node                Node.js >= 22 via NodeSource apt repo
pnpm                pnpm package manager (global, via npm)
claude-code         @anthropic-ai/claude-code CLI (global npm install)
eza                 modern ls. apt → release tarball fallback.
zoxide              smarter cd. apt → upstream installer fallback.
atuin               TUI shell history. user-local install.
docker-completion   user-local docker bash completion (handles broken Docker Desktop symlink)
bashrc              managed block in ~/.bashrc (atuin/zoxide/fzf init, aliases, demoshell, bashrc-landmines)
seed-history        cmd_history.txt → ~/.bash_history + atuin import
pnpm-install        workspace deps (so harness/MCP can run)
knowledge-graph     build _db/knowledge_graph.json if missing
verify-harness      end-to-end: `pnpm harness ask "OOMKilled"` hits the corpus
verify-mcp          JSON-RPC initialize handshake with harness MCP
```

**The DB ships with the repo.** `_db/knowledge.duckdb` (76 MB, ~1,665
sources across 5 domains) is git-tracked via `_db/.gitignore`'s
allowlist. No separate sync needed.

## Per-module retry on failure

If module `atuin` fails (e.g. transient 504 from `setup.atuin.sh`):

```text
=== summary ===
  OK    apt-core
  OK    node
  OK    pnpm
  FAIL  atuin            curl https://setup.atuin.sh failed (504)
  OK    bashrc
  OK    pnpm-install
  ...

  Retry failed module(s) with:
    pnpm bootstrap install --module=atuin
```

Run that exact command. Only `atuin` re-attempts. Idempotent — if it's
since installed by another path, the module no-ops and verifies pass.

## Anthropic key — where to put it

The key is **never** stored in code or in the repo. Resolution order
(first hit wins):

1. **CLI flag**: `./bootstrap.sh install --launch --anthropic-key=sk-ant-...`
2. **Env var**: `export ANTHROPIC_API_KEY=sk-ant-...` (then `./bootstrap.sh install --launch`)
3. **Config file**: `~/.config/domains/anthropic-key` (chmod 600 enforced; parent dir chmod 700)
4. **Interactive prompt** (hidden input) if running with a TTY
5. Fail loud with explicit guidance

When the key arrives via flag or env and isn't yet on disk, you'll be
asked once whether to save it to `~/.config/domains/anthropic-key`.
Saying yes makes future runs zero-arg.

The key is **masked everywhere** in logs as `sk-ant-…XXXX` (last 4 chars).
It's never written to stdout/stderr in clear.

### Per environment — the recommended source

| Environment | Recommended | Why |
|---|---|---|
| **Any Linux box where you already have your SSH key** | **age-encrypted file in `_secrets/anthropic-key.age` (in this repo)** — your SSH PRIVATE key decrypts it at install time. **ZERO PASTE per box, encrypted file is safe in a public repo.** | Your SSH key is your one and only "bootstrap secret" — already needed for git. |
| **Devin DevBox specifically** | Devin Secrets UI (Settings → Secrets → add `ANTHROPIC_API_KEY`) — overrides the file path | Devin injects as env var per session; key never on disk |
| **Local / WSL** (no SSH key, or want simpler) | `~/.config/domains/anthropic-key` (chmod 600 atomic) via `pnpm bootstrap key set` | Survives across reboots; owner-only |
| **One-off automated install** | `--anthropic-key=` flag | Fast; visible in `ps`/history but ephemeral |
| **CI / GitHub Actions** | secret env var (`secrets.ANTHROPIC_API_KEY`) | Standard CI pattern |

### Provisioning the local key file

The bootstrap has a dedicated subcommand for this — handles permissions,
atomic write, and validation:

```bash
pnpm bootstrap key set      # prompts for key (input hidden), persists chmod 600
pnpm bootstrap key show     # confirms source + masked value
```

Manual equivalent (if you don't want the prompt):

```bash
mkdir -p ~/.config/domains
chmod 700 ~/.config/domains
printf '%s\n' 'sk-ant-...' > ~/.config/domains/anthropic-key
chmod 600 ~/.config/domains/anthropic-key
```

### THE BEST OPTION: encrypted-in-repo with your SSH key as recipient

If you have an SSH private key on every box you use (which you do — git
needs it), this is **zero-paste forever**. The encrypted file lives in
the repo at `_secrets/anthropic-key.age` and is safe in a public repo
because nothing without your SSH PRIVATE key can decrypt it.

**One-time setup** (do this on your trusted machine):

```bash
pnpm bootstrap key encrypt
# - prompts for sk-ant-... (input hidden)
# - finds your SSH PUBLIC key at ~/.ssh/id_ed25519.pub (or id_rsa.pub)
# - runs: age -R <pubkey> -o _secrets/anthropic-key.age <<< 'sk-ant-...'
# - prints next steps
git add _secrets/anthropic-key.age
git commit -m 'ship encrypted anthropic key'
git push
```

**Every install on every box, forever** (zero work for the key):

```bash
git clone https://github.com/aaronstone2/Domains
cd Domains
./bootstrap.sh install
# bootstrap notices _secrets/anthropic-key.age exists
# bootstrap finds your ~/.ssh/id_ed25519
# bootstrap runs: age --decrypt -i ~/.ssh/id_ed25519 _secrets/anthropic-key.age
# bootstrap atomically writes plaintext to ~/.config/domains/anthropic-key (chmod 600)
# subsequent layers (verify-harness, --launch claude) read from disk silently
```

**Threat model — why this is safe in a public repo**:

- The encrypted file `_secrets/anthropic-key.age` is age-encrypted. Decryption
  requires the corresponding SSH private key.
- An attacker who clones the public repo cannot decrypt without your
  `~/.ssh/id_ed25519` private key.
- Your SSH private key already gates access to your GitHub account; if that
  key leaks, the API key being also encrypted to it is the *least* of your
  problems.
- No additional secret-management infrastructure (vault, secrets manager,
  key server) — just `age` (one binary, in apt-core) and your existing SSH
  key.
- Re-encrypt anytime by re-running `pnpm bootstrap key encrypt` (e.g. if
  you rotate the API key or want to add a second SSH recipient for a
  different machine).

**Want a different SSH key on a different box?** Encrypt with multiple
recipients:

```bash
age -R ~/.ssh/id_ed25519.pub -R ~/laptop2_id_ed25519.pub \
    -o _secrets/anthropic-key.age <<< 'sk-ant-...'
```

Each recipient can independently decrypt. Add as many as you have boxes.

## DevBox blueprint integration

DevBox uses an immutable snapshot model: install runs ONCE during the
blueprint `initialize:` build phase; the result is baked into the snapshot
and inherited by every session. This package has two dedicated modes for
that:

```yaml
# .devin/blueprint.yaml (excerpt)

initialize:
  - name: Install domains corpus + harness
    run: |
      git clone https://github.com/aaronstone2/Domains ~/domains
      cd ~/domains
      ./bootstrap.sh install --snapshot-build --with-docker
      # --snapshot-build = strict mode: any required module failure exits 1
      # so the snapshot build fails loud rather than baking a broken image.

maintenance:
  - name: Verify domains harness still works
    run: |
      cd ~/domains && ./bootstrap.sh verify --session-mode
      # --session-mode = verify-only, no installs. Surfaces module health
      # to Devin as context at session start; doesn't mutate the image.
```

If you don't use blueprints (manual install via `git clone && ./bootstrap.sh`),
the same modes work — `--snapshot-build` makes the install strict;
`--session-mode` verifies a previously-completed install.

## ACID guarantees

| Property | Implementation |
|---|---|
| **Atomicity** (per-module all-or-nothing) | Try/catch around each install. Modules with mutations (bashrc, docker-completion, anthropic-key) implement `snapshotState()` + `rollback()` — failed installs restore the previous file. |
| **Consistency** (invariants hold post-install) | Every module's `verify()` runs after `install()`. Pre-flight checks before any module runs (sudo, network, disk, PATH sanity). |
| **Isolation** (no concurrent corruption) | PID lock at `/tmp/domains-bootstrap.lock`. Two concurrent installs refuse with a clear error pointing at the holding PID. Stale-PID detection. |
| **Durability** (writes survive crashes) | All file writes go through `atomicWrite()` — write-to-tmp + rename + fsync of file and parent dir. Ratio: file content + dir-rename are both durable across power loss. |

## Common invocations

```bash
# DevBox blueprint initialize: (strict, fails snapshot build on any required failure)
./bootstrap.sh install --snapshot-build --with-docker

# DevBox blueprint maintenance: (verify-only)
./bootstrap.sh verify --session-mode

# Full local install with Claude launch
./bootstrap.sh install --launch --anthropic-key=sk-ant-...

# Lean install — skip the productivity tools (eza/zoxide/atuin/seed-history)
./bootstrap.sh install --skip-tag=productivity

# Full install with optional groups
./bootstrap.sh install --with-docker --with-k8s --with-aws --launch

# Skip claude-code install (already on PATH or you don't need it)
./bootstrap.sh install --no-claude

# Install only specific modules (good for partial recovery after a failure)
./bootstrap.sh install --module=docker-completion,bashrc

# Force re-install of a specific module (overrides isInstalled())
./bootstrap.sh install --module=bashrc --force

# See what would happen WITHOUT mutating anything
./bootstrap.sh install --dry-run

# Offline (skip network preflight + curl-based installers)
./bootstrap.sh install --offline

# Show every module + current state + tags
./bootstrap.sh list

# Run verify on every module (no install)
./bootstrap.sh verify

# Just the bashrc safety check
./bootstrap.sh landmines

# Anthropic key management
./bootstrap.sh key set        # interactive prompt → ~/.config/domains/anthropic-key
./bootstrap.sh key show       # show source + masked value

# Help
./bootstrap.sh --help
```

## Verification

After install, run any of:

```bash
# Should print "Result: clean. Safe for interview/demo."
bashrc-landmines

# Should land you in vanilla bash with no aliases. `exit` to return.
demoshell

# Should return docker.fm.oom-killed-exit-137 + a talk track + citations
pnpm harness ask "OOMKilled"

# Should print 5 domains + ~1,665 sources + ~3,500 concepts/commands
pnpm harness stats

# Tab-completion for docker subcommands should work in any new shell
docker <Tab><Tab>
```

## What changed from the legacy bash bootstrap

- **No more `grep='rg'` alias** — silently broke `grep -E/-A/-B` in the
  legacy shell. ripgrep is still installed and on PATH as `rg`; users can
  call it deliberately. We do NOT silently shadow `grep`.
- **bash-completion is now in apt-core** — was missing in the legacy, so
  Tab-completion for docker/git/kubectl never loaded.
- **python3 + python3-pip are now in apt-core** — required by methodology
  examples, offcputime-bpfcc bindings, and many practice scenarios.
- **nmap, systemd-coredump in apt-core** — coredumpctl is referenced by
  the cluely cheatsheet for exit-139 (segfault) diagnosis.
- **demoshell + bashrc-landmines functions** — escape hatch and safety
  check for shell-config corruption (e.g. inshellisense).
- **Static docker completion fallback** — Docker Desktop's
  `/usr/share/bash-completion/completions/docker` symlink frequently
  breaks; we ship our own at `~/.local/share/bash-completion/completions/docker`.
- **Per-module error isolation + rollback** — legacy bash aborted the
  install on any single failure. New version finishes everything possible,
  rolls back per-module on failure (e.g. bashrc gets restored from snapshot
  if write corrupts), and surfaces a per-module summary with retry hints.
- **Anthropic key has 4-layer fallback + atomic file persistence** — was
  just env-or-flag in legacy. Now: flag → env → ~/.config/domains/anthropic-key
  → interactive prompt → fail loud. Plus dedicated `key set` / `key show`
  subcommands and chmod 700 on parent dir, atomic write of the key file.
- **Concurrent-run lock** — `/tmp/domains-bootstrap.lock` (PID-based)
  prevents two simultaneous installs from interleaving apt-get / pnpm /
  bashrc writes.
- **Pre-flight checks** — sudo/network/disk/PATH-sanity verified BEFORE
  any module runs, so blockers fail fast.
- **DevBox modes**: `--snapshot-build` (strict; for blueprint `initialize:`)
  and `--session-mode` (verify-only; for blueprint `maintenance:`).
- **Tag-based filtering**: `--skip-tag=productivity` skips eza/zoxide/atuin
  for a leaner interview-day install.

## Architecture

```
bootstrap.sh                    # ~50-line trampoline (Node + pnpm install)
packages/bootstrap/             # TS package; @domains/bootstrap
├── src/
│   ├── index.ts                # CLI: install / verify / list / landmines
│   ├── lib/                    # Logger, Runner, BashrcBlock, flags, secrets, types
│   ├── modules/                # 18 single-responsibility installer modules
│   └── bashrc/                 # bashrc fragments composed by modules/bashrc.ts
└── README.md
bootstrap.sh.legacy             # the 545-line bash version, kept for diffing
```

The orchestrator (src/index.ts) iterates `ALL_MODULES` from
`src/modules/registry.ts`. For each: `shouldRun` (gated by config) →
`isInstalled` (skip if true unless `--force`) → `install` →
`verify`. Per-module errors are caught and reported in the summary;
they do not abort other modules.

## Cross-references

- Source: `packages/bootstrap/README.md` (developer-facing)
- Plan that drove this rewrite: `~/.claude/plans/read-domains-shared-sessions-phase-1-so-sorted-shannon.md`
- Practice scenarios that build on this install: `domains/practice/PRIORITY-TABLE.md`
- Cluely upload bundle (interview reference): `cluely/README.md`
