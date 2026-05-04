# @domains/bootstrap

Modular DevBox installer. One command, many independently-runnable modules.

## Why

Replaces a 546-line bash script that copy-pasted four "apt-or-curl-fallback" installers, embedded one giant heredoc bashrc block, and aborted the whole install on any single failure. This package gives:

- **Single-responsibility modules**: each tool/step is one file in `src/modules/`. Independently runnable for retry.
- **Per-module error isolation**: a failure of `apt-optional` does not stop `atuin` from installing.
- **End-of-run summary**: prints exact retry command for each failed module.
- **Idempotent everywhere**: re-running a module with the tool already installed is a no-op + verification pass.
- **Composable bashrc**: the bashrc block is built from typed module objects in `src/bashrc/` instead of one heredoc.
- **Dry-run support**: `--dry-run` prints every shell command that would execute, changes nothing.

## Usage

Driven by `bootstrap.sh` (~30-line trampoline) at the repo root, OR directly via pnpm:

```bash
# Full install (everything)
pnpm bootstrap install

# With optional groups
pnpm bootstrap install --with-docker --with-k8s --with-aws

# Just one module (after a failure of that module mid-run)
pnpm bootstrap install --module=atuin

# Multiple modules
pnpm bootstrap install --module=atuin,bashrc

# Dry-run — print commands, change nothing
pnpm bootstrap install --dry-run

# List all modules + their state (installed/needed/skip)
pnpm bootstrap list

# Verify all modules' post-install state (no install)
pnpm bootstrap verify

# Just the bashrc-landmines check
pnpm bootstrap landmines
```

## Module shape

Every module in `src/modules/*.ts` exports an `InstallerModule`:

```ts
export interface InstallerModule {
  readonly id: string;                // CLI-stable identifier (e.g. "atuin")
  readonly description: string;       // human-readable
  readonly tags?: readonly string[];  // for filter/grouping
  shouldRun(cfg: BootstrapConfig): boolean;
  isInstalled(ctx: InstallContext): Promise<boolean>;
  install(ctx: InstallContext): Promise<void>;
  verify(ctx: InstallContext): Promise<VerifyResult>;
}
```

The orchestrator runs each `shouldRun: true` module sequentially, isolates errors, and reports.

## Layout

```
src/
├── index.ts                # CLI router
├── lib/                    # cross-module utilities
│   ├── log.ts              # Logger (step/ok/warn/skip)
│   ├── runner.ts           # Runner: exec, sudo, dry-run
│   ├── bashrc-block.ts     # idempotent marker-based replace
│   ├── flags.ts            # typed flag parsing
│   └── types.ts            # InstallerModule + BootstrapConfig
├── modules/                # one file per installer module
│   ├── apt-core.ts
│   ├── apt-optional.ts
│   ├── apt-docker.ts
│   ├── apt-k8s.ts
│   ├── apt-aws.ts
│   ├── node.ts
│   ├── pnpm.ts
│   ├── claude-code.ts
│   ├── eza.ts
│   ├── zoxide.ts
│   ├── atuin.ts
│   ├── seed-history.ts
│   ├── bashrc.ts
│   ├── docker-completion.ts
│   ├── pnpm-install.ts
│   ├── knowledge-graph.ts
│   ├── verify-harness.ts
│   ├── verify-mcp.ts
│   └── registry.ts         # ALL_MODULES order
└── bashrc/                 # bashrc block fragments (one source of truth)
    ├── safety.ts           # demoshell + bashrc-landmines functions
    ├── completions.ts      # bash-completion framework + per-tool sourcing
    ├── productivity-aliases.ts  # ls=eza, cat=bat, cd=z (NO grep=rg)
    ├── tool-init.ts        # atuin/zoxide init eval lines
    └── repo-aliases.ts
```

## Retry pattern

If module `atuin` fails mid-install:

```text
=== bootstrap install summary ===
ok    apt-core
ok    node
ok    pnpm
FAIL  atuin                — error: curl https://setup.atuin.sh failed (504)
ok    bashrc
ok    pnpm-install
ok    verify-harness

1 module(s) failed. Retry with:
  pnpm bootstrap install --module=atuin
```

The user fixes connectivity, re-runs that exact command, and only `atuin` reattempts.
