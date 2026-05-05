#!/usr/bin/env bash
# setup.sh — one-shot bootstrap for a fresh DevBox / VM.
#
# Usage (paste into a fresh terminal):
#   bash <(curl -fsSL https://raw.githubusercontent.com/aaronstone2/Domains/main/setup.sh)
#
# What it does:
#   1. Provisions SSH private key (for age-decrypting the Anthropic API key)
#   2. Clones the repo (or pulls if already present)
#   3. Runs bootstrap (installs everything + auto-decrypts API key)
#   4. Launches Claude Code
#
# The Anthropic API key is NEVER typed or pasted — it's stored encrypted in
# the repo (_secrets/anthropic-key.age) and decrypted automatically using
# the SSH key provisioned in step 1.

set -euo pipefail

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }

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

# ---- 2. Clone / pull ----
REPO=~/Domains
if [ -d "$REPO/.git" ]; then
  say "Pulling latest"
  cd "$REPO" && git pull --ff-only
else
  say "Cloning repo"
  git clone https://github.com/aaronstone2/Domains.git "$REPO"
  cd "$REPO"
fi

# ---- 3. Bootstrap + launch ----
say "Running bootstrap (auto-decrypts API key via SSH key)"
./bootstrap.sh install --launch
