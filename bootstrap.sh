#!/usr/bin/env bash
# bootstrap.sh — fast trampoline: Node + pnpm + workspace deps, then TS.
#
# Optimized for cold DevBox: binary tarball node (~2s), parallel apt check,
# pnpm corepack enable (~0.5s). Target: under 10s to TS handoff on bare box.
#
# Usage:
#   ./bootstrap.sh                                          # full install
#   ./bootstrap.sh install --with-docker --launch           # docker + launch claude
#   ./bootstrap.sh install --module=atuin                   # retry one module
#   ./bootstrap.sh install --dry-run                        # preview
#   ./bootstrap.sh list                                     # see all modules + state
#   ./bootstrap.sh verify                                   # post-install checks
#   ./bootstrap.sh landmines                                # bashrc safety check
#   ./bootstrap.sh --help                                   # full help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }

# ---- Node + pnpm (fast path: binary tarball) ----
NODE_VER="22.15.0"
NODE_OK=false
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1 || echo 0)"
  [[ "$NODE_MAJOR" -ge 22 ]] && NODE_OK=true
fi

if ! $NODE_OK; then
  say "installing Node.js $NODE_VER (binary tarball — fast)"
  NODE_DIR="/usr/local/lib/node-v${NODE_VER}"
  if [[ ! -d "$NODE_DIR" ]]; then
    curl -fsSL "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.gz" \
      | $SUDO tar xz -C /usr/local/lib/
    $SUDO mv "/usr/local/lib/node-v${NODE_VER}-linux-x64" "$NODE_DIR"
  fi
  # Symlink into /usr/local/bin (idempotent)
  for bin in node npm npx; do
    $SUDO ln -sf "$NODE_DIR/bin/$bin" "/usr/local/bin/$bin"
  done
fi

if ! command -v pnpm >/dev/null 2>&1; then
  say "installing pnpm"
  $SUDO npm install -g pnpm 2>/dev/null
fi

# ---- Workspace deps (skip if already present) ----
if [[ -d "$REPO_DIR/node_modules/.pnpm" ]]; then
  say "workspace deps present (skipping pnpm install)"
else
  say "pnpm install (workspace)"
  if ! pnpm install --prefer-offline 2>&1 | tail -3; then
    warn "pnpm install FAILED"
    exit 1
  fi
fi

# ---- Hand off to TS ----
say "handing off to @domains/bootstrap (TypeScript)"
TSX_BIN="$REPO_DIR/node_modules/.bin/tsx"
if [[ ! -x "$TSX_BIN" ]]; then
  warn "tsx not found at $TSX_BIN — pnpm install may have failed"
  exit 1
fi
exec "$TSX_BIN" "$REPO_DIR/packages/bootstrap/src/index.ts" "$@"
