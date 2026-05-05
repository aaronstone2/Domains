#!/usr/bin/env bash
# setup.sh — one-shot bootstrap for a fresh DevBox / VM.
#
# Usage (paste into a fresh terminal):
#   bash <(curl -fsSL https://raw.githubusercontent.com/aaronstone2/Domains/main/setup.sh)
#
# What it does:
#   1. Provisions SSH private key (for age-decrypting the Anthropic API key)
#   2. Downloads repo + Node in PARALLEL (~3s)
#   3. Runs bootstrap (installs everything + auto-decrypts API key)
#   4. Launches Claude Code
#
# The Anthropic API key is NEVER typed or pasted — it's stored encrypted in
# the repo (_secrets/anthropic-key.age) and decrypted automatically using
# the SSH key provisioned in step 1.
#
# Target: SSH key paste → Claude Code ready in ~8s on a fast connection.

set -euo pipefail

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

BRANCH="${DOMAINS_BRANCH:-main}"

# ---- 1. SSH key ----
if [ -f ~/.ssh/id_ed25519 ]; then
  say "SSH key already present"
elif [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  say "Provisioning SSH key from environment"
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  python3 -c "
import os
key = os.environ['SSH_PRIVATE_KEY'].strip()
start = '-----BEGIN OPENSSH PRIVATE KEY-----'
end = '-----END OPENSSH PRIVATE KEY-----'
content = key.replace(start, '').replace(end, '').strip()
b64 = ''.join(content.split())
lines = [start]
for i in range(0, len(b64), 70):
    lines.append(b64[i:i+70])
lines.append(end)
lines.append('')
with open(os.path.expanduser('~/.ssh/id_ed25519'), 'w') as f:
    f.write('\n'.join(lines))
os.chmod(os.path.expanduser('~/.ssh/id_ed25519'), 0o600)
"
  echo "  ok"
else
  say "Paste your SSH private key (id_ed25519), then press Ctrl-D:"
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  cat > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
fi

# ---- 2. Parallel: download repo tarball + install Node ----
REPO=~/Domains
NODE_VER="22.15.0"
if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# Check if node 22+ exists
NODE_OK=false
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1 || echo 0)"
  [[ "$NODE_MAJOR" -ge 22 ]] && NODE_OK=true
fi

say "Setting up..."

# Background job 1: install Node if needed
if ! $NODE_OK; then
  (
    NODE_DIR="/usr/local/lib/node-v${NODE_VER}"
    if [[ ! -d "$NODE_DIR" ]]; then
      curl -fsSL "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.gz" \
        | $SUDO tar xz -C /usr/local/lib/
      $SUDO mv "/usr/local/lib/node-v${NODE_VER}-linux-x64" "$NODE_DIR"
    fi
    for bin in node npm npx; do
      $SUDO ln -sf "$NODE_DIR/bin/$bin" "/usr/local/bin/$bin"
    done
  ) &
  NODE_PID=$!
else
  NODE_PID=""
fi

# Foreground: download repo (tarball is ~2x faster than git clone)
if [ -d "$REPO/.git" ]; then
  cd "$REPO" && git pull --ff-only 2>/dev/null
elif [ -d "$REPO" ]; then
  cd "$REPO"
else
  mkdir -p "$REPO"
  curl -fsSL "https://github.com/aaronstone2/Domains/archive/refs/heads/${BRANCH}.tar.gz" \
    | tar xz -C "$REPO" --strip-components=1
  cd "$REPO"
fi

# Wait for Node if it was backgrounded
if [[ -n "${NODE_PID:-}" ]]; then
  wait "$NODE_PID"
  export PATH="/usr/local/lib/node-v${NODE_VER}/bin:$PATH"
fi

# ---- 3. Early API key decrypt (parallel-safe, before bootstrap) ----
# Decrypt the age-encrypted Anthropic key now so bootstrap skips the age
# subprocess entirely. This shaves ~200ms from the critical path.
AGE_FILE="$REPO/_secrets/anthropic-key.age"
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$AGE_FILE" ] && command -v age >/dev/null 2>&1 && [ -f ~/.ssh/id_ed25519 ]; then
  ANTHROPIC_API_KEY="$(age --decrypt -i ~/.ssh/id_ed25519 "$AGE_FILE" 2>/dev/null || true)"
  if [[ "$ANTHROPIC_API_KEY" == sk-ant-* ]]; then
    export ANTHROPIC_API_KEY
    # Also persist for future runs
    mkdir -p ~/.config/domains && chmod 700 ~/.config/domains
    printf '%s' "$ANTHROPIC_API_KEY" > ~/.config/domains/anthropic-key
    chmod 600 ~/.config/domains/anthropic-key
  fi
fi

# ---- 4. Bootstrap + launch ----
say "Running bootstrap"
./bootstrap.sh install --skip-preflight --launch
