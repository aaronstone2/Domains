#!/usr/bin/env bash
# setup.sh — one-shot bootstrap for a fresh DevBox / VM.
#
# Usage (paste into a fresh terminal):
#   bash <(curl -fsSL https://raw.githubusercontent.com/aaronstone2/Domains/main/setup.sh)
#
# What it does:
#   1. Provisions SSH private key (for age-decrypting the Anthropic API key)
#   2. Clones the repo + installs Node in PARALLEL (~3-5s)
#   3. Runs bootstrap (installs everything + auto-decrypts API key)
#   4. Launches Claude Code
#
# The Anthropic API key is NEVER typed or pasted — it's stored encrypted in
# the repo (_secrets/anthropic-key.age) and decrypted automatically using
# the SSH key provisioned in step 1.
#
# Target: SSH key paste → Claude Code ready in ~10s on a fast connection.

set -euo pipefail

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---- 1. SSH key ----
if [ -f ~/.ssh/id_ed25519 ]; then
  say "SSH key already present"
elif [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  say "Provisioning SSH key from environment"
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  python3 -c "
import os, base64
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

# ---- 2. Parallel: clone repo + install Node ----
REPO=~/Domains
NODE_VER="22.15.0"
if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# Check if node 22+ exists
NODE_OK=false
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1 || echo 0)"
  [[ "$NODE_MAJOR" -ge 22 ]] && NODE_OK=true
fi

# Launch both in parallel
say "Setting up (parallel: clone + node)..."

# Background: install Node if needed
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

# Foreground: clone repo (or pull if exists)
if [ -d "$REPO/.git" ]; then
  cd "$REPO" && git pull --ff-only 2>/dev/null
else
  git clone --depth 1 https://github.com/aaronstone2/Domains.git "$REPO"
  cd "$REPO"
fi

# Wait for Node if it was backgrounded
if [[ -n "${NODE_PID:-}" ]]; then
  wait "$NODE_PID"
  export PATH="/usr/local/lib/node-v${NODE_VER}/bin:$PATH"
fi

# ---- 3. Bootstrap + launch ----
say "Running bootstrap"
./bootstrap.sh install --skip-preflight --launch
