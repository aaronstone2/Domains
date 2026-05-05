#!/usr/bin/env bash
# bootstrap.sh — minimal trampoline.
#
# Job: get Node 22+ and pnpm onto the box, then exec into the real installer
# at packages/bootstrap (TypeScript, modular, single-responsibility).
#
# All the install logic lives in TS — see packages/bootstrap/README.md.
#
# Common usage:
#   ./bootstrap.sh                                          # full install
#   ./bootstrap.sh install --with-docker --launch           # docker + launch claude
#   ./bootstrap.sh install --module=atuin                   # retry one module
#   ./bootstrap.sh install --dry-run                        # preview
#   ./bootstrap.sh list                                     # see all modules + state
#   ./bootstrap.sh verify                                   # post-install checks
#   ./bootstrap.sh landmines                                # bashrc safety check
#   ./bootstrap.sh --help                                   # full help
#
# The legacy 545-line bash bootstrap is preserved at bootstrap.sh.legacy for
# one cycle so you can diff during testing. Delete it once the TS version
# has been validated end-to-end on a fresh DevBox.

set -euo pipefail

# ---- locate the repo (the dir this script lives in) ----
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# ---- sudo if not root ----
if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

# ---- helpers (minimal — full Logger lives in TS) ----
say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }

# ---- 1. Node >= 22 (required for tsx + @modelcontextprotocol/sdk) ----
NEEDS_NODE=true
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1 || echo 0)"
  if [[ "$NODE_MAJOR" -ge 22 ]]; then
    NEEDS_NODE=false
  fi
fi
if $NEEDS_NODE; then
  say "installing Node.js 22 (NodeSource)"
  if ! command -v curl >/dev/null 2>&1; then
    $SUDO apt-get update -y && $SUDO apt-get install -y curl
  fi
  curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
fi

# ---- 2. pnpm ----
if ! command -v pnpm >/dev/null 2>&1; then
  say "installing pnpm (global)"
  $SUDO npm install -g pnpm
fi

# ---- 3. Install workspace deps (cheap on re-runs) ----
# Stream output and hard-fail on non-zero. Previous version was --silent +
# `|| warn` which swallowed errors and caused downstream cascades (modules
# that needed harness deps would fail with unhelpful messages).
# Drop --frozen-lockfile so a minor pnpm-version diff between machines
# doesn't block the install.
say "pnpm install (workspace) — streaming output"
if ! pnpm install; then
  warn "pnpm install FAILED — bootstrap cannot continue safely."
  warn "Try: rm -rf node_modules pnpm-lock.yaml && pnpm install"
  exit 1
fi

# ---- 4. Hand off to the TS installer ----
# All flags (--with-docker / --module=X / --dry-run / --launch / --anthropic-key /
# --no-claude / --minimal / etc.) are parsed in packages/bootstrap/src/lib/flags.ts.
# Run `./bootstrap.sh --help` to see them.
say "handing off to @domains/bootstrap (TypeScript)"
# Direct tsx invocation. We bypass `pnpm --filter @domains/bootstrap start`
# because pnpm --filter changes cwd to the filtered package's directory
# (packages/bootstrap), which breaks every path-based check in the bootstrap
# (it would look for _db/knowledge.duckdb under packages/bootstrap/_db/,
# not the actual repo root).
#
# Calling tsx directly preserves cwd as the repo root (where this script
# lives), which is what every module expects.
TSX_BIN="$REPO_DIR/node_modules/.bin/tsx"
if [[ ! -x "$TSX_BIN" ]]; then
  warn "tsx binary not found at $TSX_BIN — pnpm install may have failed"
  exit 1
fi
exec "$TSX_BIN" "$REPO_DIR/packages/bootstrap/src/index.ts" "$@"
