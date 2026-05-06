#!/usr/bin/env bash
# bootstrap.sh — fast trampoline: Node → pre-built bundle. No pnpm/tsx needed.
#
# Optimized for bare interview DevBox:
#   1. Binary tarball Node install (~2s if needed)
#   2. Hand off to pre-built dist/bootstrap.js (~1s)
#   Total on bare box: ~3s. Warm: ~1s.
#
# The bundle is committed to git — no pnpm install or tsx required on the
# critical path. pnpm install runs later as a bootstrap module (pnpm-install)
# to set up workspace deps for the harness CLI.
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

# ---- Node (fast path: binary tarball, ~2s) ----
NODE_VER="22.15.0"
NODE_OK=false
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1 || echo 0)"
  [[ "$NODE_MAJOR" -ge 22 ]] && NODE_OK=true
fi

if ! $NODE_OK; then
  say "installing Node.js $NODE_VER (binary tarball)"
  NODE_DIR="/usr/local/lib/node-v${NODE_VER}"
  if [[ ! -d "$NODE_DIR" ]]; then
    curl -fsSL "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.gz" \
      | $SUDO tar xz -C /usr/local/lib/
    $SUDO mv "/usr/local/lib/node-v${NODE_VER}-linux-x64" "$NODE_DIR"
  fi
  for bin in node npm npx; do
    $SUDO ln -sf "$NODE_DIR/bin/$bin" "/usr/local/bin/$bin"
  done
  # Add tarball bin dir to PATH so npm-installed globals (pnpm) are findable.
  export PATH="$NODE_DIR/bin:$PATH"
fi

# ---- Hand off to pre-built bundle (no pnpm/tsx needed) ----
BUNDLE="$REPO_DIR/packages/bootstrap/dist/bootstrap.js"
if [[ -f "$BUNDLE" ]]; then
  exec node "$BUNDLE" "$@"
fi

# Fallback: if bundle doesn't exist, use tsx via pnpm (dev mode)
warn "pre-built bundle not found at $BUNDLE — falling back to tsx"
if ! command -v pnpm >/dev/null 2>&1; then
  say "installing pnpm"
  $SUDO npm install -g pnpm 2>/dev/null
fi
if [[ ! -d "$REPO_DIR/node_modules/.pnpm" ]]; then
  say "pnpm install (workspace)"
  pnpm install --prefer-offline 2>&1 | tail -3
fi
TSX_BIN="$REPO_DIR/node_modules/.bin/tsx"
if [[ ! -x "$TSX_BIN" ]]; then
  warn "tsx not found — pnpm install may have failed"
  exit 1
fi
exec "$TSX_BIN" "$REPO_DIR/packages/bootstrap/src/index.ts" "$@"
