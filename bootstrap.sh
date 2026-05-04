#!/usr/bin/env bash
# bootstrap.sh — interview-day setup for AI Support Engineer screen-share
#
# Installs the diagnostic + productivity stack on a fresh Debian/Ubuntu Linux
# VM, optionally installs Claude Code + atuin + shell sugar, and (with
# --launch) drops you straight into Claude with the corpus repo as cwd.
#
# Usage:
#   ./bootstrap.sh [flags]
#
# Common one-liner (interview opener — single line, NO backslash):
#   git clone https://github.com/aaronstone2/Domains.git ~/domains && cd ~/domains && ./bootstrap.sh --launch
#
# Idempotent: safe to re-run. Bashrc additions are guarded by markers.
#
# `set -e` is intentionally NOT used — apt mirror blips, missing kernel headers,
# and other transient issues should not abort the install. Each step has its
# own || warn fallback so failures degrade gracefully.

set -uo pipefail

# -----------------------------------------------------------------------------
# Defaults + flag parsing
# -----------------------------------------------------------------------------
ANTHROPIC_KEY=""
MODEL="claude-opus-4-7"
EFFORT="max"
LAUNCH=false
NO_CLAUDE=false
NO_SHELL_CONFIG=false
MINIMAL=false
WITH_DOCKER=false
WITH_K8S=false
WITH_AWS=false
NO_HISTORY_IMPORT=false

show_help() {
  cat <<'EOF'
bootstrap.sh — interview-day setup

Usage:
  ./bootstrap.sh [flags]

Flags:
  --anthropic-key=KEY     Set ANTHROPIC_API_KEY for launched Claude session
                          (or pass via env: ANTHROPIC_API_KEY=... ./bootstrap.sh)
  --model=NAME            Claude model (default: claude-opus-4-7)
  --effort=LEVEL          Claude effort (default: max)
  --launch                After install, exec `claude --model ... --effort ...`
  --no-claude             Skip installing Claude Code via npm
  --no-shell-config       Skip .bashrc/atuin/aliases setup (just install tools)
  --no-history-import     Skip seeding atuin from cmd_history.txt
  --minimal               Skip heavier optionals (bpfcc-tools, sysbench, btop)
  --with-docker           Install docker.io + containerd (default: assume present)
  --with-k8s              Install kubectl
  --with-aws              Install awscli v2 (for ECR/AWS-related scenarios)
  -h, --help              This message

Examples:
  ./bootstrap.sh                                  # tools + shell, no Claude launch
  ./bootstrap.sh --anthropic-key='sk-...' --launch
  ./bootstrap.sh --minimal --no-claude            # fast install, just tools

Notes:
  - Assumes Debian/Ubuntu (apt). Other distros: install equivalents manually.
  - Sudo will prompt once for the apt installs. Re-run is idempotent.
  - API key is NEVER stored in this repo. Pass via flag or env at run time.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --anthropic-key=*) ANTHROPIC_KEY="${1#*=}"; shift ;;
    --anthropic-key) ANTHROPIC_KEY="$2"; shift 2 ;;
    --model=*) MODEL="${1#*=}"; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --effort=*) EFFORT="${1#*=}"; shift ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --launch) LAUNCH=true; shift ;;
    --no-claude) NO_CLAUDE=true; shift ;;
    --no-shell-config) NO_SHELL_CONFIG=true; shift ;;
    --no-history-import) NO_HISTORY_IMPORT=true; shift ;;
    --minimal) MINIMAL=true; shift ;;
    --with-docker) WITH_DOCKER=true; shift ;;
    --with-k8s) WITH_K8S=true; shift ;;
    --with-aws) WITH_AWS=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "unknown flag: $1 (try --help)" >&2; exit 1 ;;
  esac
done

# Pick up env-var fallback for the key
if [[ -z "$ANTHROPIC_KEY" && -n "${ANTHROPIC_API_KEY:-}" ]]; then
  ANTHROPIC_KEY="$ANTHROPIC_API_KEY"
fi

# -----------------------------------------------------------------------------
# Pretty logging
# -----------------------------------------------------------------------------
RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'
BOLD=$'\e[1m'; DIM=$'\e[2m'; RESET=$'\e[0m'

step() { echo "${BOLD}${BLUE}==>${RESET}${BOLD} $*${RESET}"; }
ok()   { echo "${GREEN}✓${RESET} $*"; }
warn() { echo "${YELLOW}⚠${RESET}  $*"; }
err()  { echo "${RED}✗${RESET} $*" >&2; }

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
step "bootstrap.sh starting in $REPO_DIR"

if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get not found. This script targets Debian/Ubuntu. Install equivalents manually for your distro."
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  warn "running as root — some user-scoped installs (atuin, npm global) will install for root. That's usually fine on a clean VM."
  SUDO=""
else
  SUDO="sudo"
  if ! sudo -n true 2>/dev/null; then
    warn "sudo will prompt for your password once."
  fi
fi

# -----------------------------------------------------------------------------
# 1) apt packages
# -----------------------------------------------------------------------------
step "installing apt packages"

# Core diagnostic + productivity (always installed)
APT_CORE=(
  # General
  git curl ca-certificates jq vim less

  # Networking debug
  iproute2 iptables nftables conntrack
  dnsutils                       # dig, nslookup
  netcat-openbsd                 # nc
  tcpdump
  net-tools                      # netstat, ifconfig (legacy but interview-day useful)

  # Performance / observability
  sysstat                        # iostat, mpstat, sar, pidstat
  htop
  lsof strace ltrace
  procps                         # ps, top, kill, free, uptime, vmstat
  bsdmainutils                   # column, hexdump (used in scripts often)

  # Files / process
  file rsync
  openssl

  # Productivity (TUI)
  ripgrep fzf

  # Editors / paging niceties
  bat                            # called batcat on Ubuntu/Debian
)

# Optional heavy bits
APT_OPTIONAL=(
  # eBPF tooling — pulls a few hundred MB
  bpfcc-tools "linux-headers-$(uname -r)"
  bpftrace

  # perf
  "linux-tools-common"
  "linux-tools-generic"
  "linux-tools-$(uname -r)"

  # Misc
  btop
  sysbench
)

# Optional gated by flags
APT_DOCKER=(docker.io docker-compose-plugin containerd uidmap)
APT_K8S=()   # populated below (kubectl needs apt-key dance)
APT_AWS=()   # awscli installed via official installer below

# Set noninteractive so apt doesn't try to open a pager / prompt
export DEBIAN_FRONTEND=noninteractive

$SUDO apt-get update -y || warn "apt-get update failed (network blip or stale mirror); continuing with cached lists"
$SUDO apt-get install -y "${APT_CORE[@]}" || warn "some core apt packages failed; continuing"

if ! $MINIMAL; then
  # linux-headers may not be available on every kernel; let it fail gracefully
  $SUDO apt-get install -y "${APT_OPTIONAL[@]}" || warn "some optional packages (bpfcc/perf/headers) failed — fine if your kernel doesn't have a matching headers package"
else
  ok "skipping optional heavy packages (--minimal)"
fi

if $WITH_DOCKER; then
  step "installing docker.io"
  $SUDO apt-get install -y "${APT_DOCKER[@]}" || warn "docker install failed; might already be present"
  $SUDO usermod -aG docker "$USER" || true
  warn "you'll need to log out + back in for docker group membership to take effect"
fi

if $WITH_K8S; then
  step "installing kubectl"
  if ! command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
    curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    $SUDO install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
    ok "kubectl ${KUBECTL_VERSION} installed"
  else
    ok "kubectl already present: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
  fi
fi

if $WITH_AWS; then
  step "installing aws-cli v2"
  if ! command -v aws >/dev/null 2>&1; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    (cd /tmp && unzip -q awscliv2.zip && $SUDO ./aws/install --update)
    rm -rf /tmp/aws /tmp/awscliv2.zip
    ok "aws-cli v2 installed"
  else
    ok "aws already present: $(aws --version 2>&1 | head -1)"
  fi
fi

# -----------------------------------------------------------------------------
# 2) Node.js (only if Claude Code is wanted)
# -----------------------------------------------------------------------------
if ! $NO_CLAUDE; then
  step "ensuring Node.js + npm are present"
  if ! command -v npm >/dev/null 2>&1; then
    # NodeSource setup — install Node 22.x (current LTS-ish for npm globals)
    curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash -
    $SUDO apt-get install -y nodejs
    ok "node $(node --version) + npm $(npm --version) installed"
  else
    ok "node $(node --version) + npm $(npm --version) already present"
  fi

  step "installing @anthropic-ai/claude-code via npm -g"
  if ! command -v claude >/dev/null 2>&1; then
    $SUDO npm install -g @anthropic-ai/claude-code
    ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'see `claude --help`')"
  else
    ok "Claude Code already present: $(claude --version 2>/dev/null || echo installed)"
  fi
fi

# -----------------------------------------------------------------------------
# 3) Productivity tools that don't ship in apt: eza, zoxide, atuin
# -----------------------------------------------------------------------------
install_eza() {
  if command -v eza >/dev/null 2>&1; then
    ok "eza already present"
    return
  fi
  step "installing eza"
  # eza ships a deb in their releases; fall back to cargo-via-apt if that fails
  if $SUDO apt-get install -y eza 2>/dev/null; then
    ok "eza installed via apt"
  else
    warn "eza not in apt; falling back to manual install"
    EZA_URL="$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest \
      | grep -oP 'https://[^"]*x86_64-unknown-linux-musl\.tar\.gz' | head -1)"
    if [[ -n "$EZA_URL" ]]; then
      curl -fsSL "$EZA_URL" -o /tmp/eza.tar.gz
      tar -xzf /tmp/eza.tar.gz -C /tmp
      $SUDO install -m 0755 /tmp/eza /usr/local/bin/eza
      rm -f /tmp/eza /tmp/eza.tar.gz
      ok "eza installed manually"
    else
      warn "couldn't find an eza release URL; skipping. Aliases will fall back to ls."
    fi
  fi
}

install_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    ok "zoxide already present"
    return
  fi
  step "installing zoxide"
  if $SUDO apt-get install -y zoxide 2>/dev/null; then
    ok "zoxide installed via apt"
  else
    warn "zoxide not in apt; using upstream installer"
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  fi
}

install_atuin() {
  if command -v atuin >/dev/null 2>&1; then
    ok "atuin already present: $(atuin --version 2>/dev/null || echo installed)"
    return
  fi
  step "installing atuin (shell history replacement)"
  curl --proto '=https' --tlsv1.2 -fsSf https://setup.atuin.sh | bash
  # atuin installer puts binary in $HOME/.atuin/bin
  if [[ -d "$HOME/.atuin/bin" ]]; then
    export PATH="$PATH:$HOME/.atuin/bin"
  fi
  if command -v atuin >/dev/null 2>&1; then
    ok "atuin installed"
  else
    warn "atuin install ran but binary not on PATH yet; will be picked up after sourcing bashrc"
  fi
}

if ! $NO_SHELL_CONFIG; then
  install_eza || true
  install_zoxide || true
  install_atuin || true
fi

# -----------------------------------------------------------------------------
# 4) Bash history seeding (so atuin has useful starting state)
# -----------------------------------------------------------------------------
if ! $NO_SHELL_CONFIG && ! $NO_HISTORY_IMPORT; then
  HIST_FILE="$REPO_DIR/cmd_history.txt"
  if [[ -f "$HIST_FILE" ]]; then
    step "seeding bash history from cmd_history.txt"
    # Append the curated commands to ~/.bash_history (no dups)
    touch "$HOME/.bash_history"
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      if ! grep -qxF -- "$line" "$HOME/.bash_history" 2>/dev/null; then
        echo "$line" >> "$HOME/.bash_history"
      fi
    done < "$HIST_FILE"
    if command -v atuin >/dev/null 2>&1; then
      atuin import bash 2>/dev/null || warn "atuin import bash failed; that's fine — first manual run will set it up"
      ok "history seeded into atuin"
    else
      warn "atuin not on PATH yet; bash history was updated but atuin import was skipped"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# 5) Bashrc additions (idempotent via markers)
# -----------------------------------------------------------------------------
if ! $NO_SHELL_CONFIG; then
  BASHRC="$HOME/.bashrc"
  MARKER_BEGIN="# >>> domains-bootstrap >>>"
  MARKER_END="# <<< domains-bootstrap <<<"

  # Strip any prior block first (so re-runs replace, not append)
  if grep -qF "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
    step "updating existing bashrc block"
    # Use sed to delete between markers (inclusive)
    tmp="$(mktemp)"
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip   { print }
    ' "$BASHRC" > "$tmp"
    mv "$tmp" "$BASHRC"
  else
    step "adding bashrc block"
  fi

  cat >> "$BASHRC" <<EOF

$MARKER_BEGIN
# Generated by bootstrap.sh from https://github.com/aaronstone2/Domains
# Re-run bootstrap.sh to update; remove this block to disable.

# atuin (shell history) — only if installed
if [[ -d "\$HOME/.atuin/bin" ]]; then
  export PATH="\$PATH:\$HOME/.atuin/bin"
fi
if command -v atuin >/dev/null 2>&1; then
  eval "\$(atuin init bash)"
fi

# zoxide (smarter cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "\$(zoxide init bash)"
fi

# fzf key bindings (Ctrl-R for fuzzy history)
if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  source /usr/share/doc/fzf/examples/completion.bash 2>/dev/null || true
fi

# Productivity aliases (graceful fallback if tool isn't installed)
command -v eza    >/dev/null && alias ls='eza --icons --group-directories-first'
command -v batcat >/dev/null && alias cat='batcat --paging=never --plain'
command -v bat    >/dev/null && alias cat='bat --paging=never --plain'
command -v rg     >/dev/null && alias grep='rg'
command -v zoxide >/dev/null && alias cd='z'

# Repo-specific aliases (sourced from current dir of repo)
if [[ -f "$REPO_DIR/.aliases" ]]; then
  source "$REPO_DIR/.aliases"
fi

# Quick claude wrapper for one-shot questions
explain() {
  if command -v claude >/dev/null 2>&1; then
    claude --print "Explain this concisely + suggest a fix: \$*"
  else
    echo "claude not installed (run bootstrap.sh without --no-claude)" >&2
  fi
}

$MARKER_END
EOF
  ok "bashrc block written"
fi

# -----------------------------------------------------------------------------
# 6) Repo deps: pnpm + corpus install (so harness commands work)
# -----------------------------------------------------------------------------
if [[ -f "$REPO_DIR/package.json" ]]; then
  step "installing pnpm + corpus deps (so `pnpm harness …` works)"
  if ! command -v pnpm >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      $SUDO npm install -g pnpm
      ok "pnpm installed"
    else
      warn "npm not present; skipping pnpm install (re-run without --no-claude, or install Node manually)"
    fi
  fi
  if command -v pnpm >/dev/null 2>&1; then
    (cd "$REPO_DIR" && pnpm install --silent 2>&1 | tail -3) || warn "pnpm install had issues; harness may not work"
    ok "corpus deps installed"
  fi
fi

# -----------------------------------------------------------------------------
# 7) Done — summary + optional launch
# -----------------------------------------------------------------------------
echo ""
step "bootstrap complete"
echo ""
echo "  ${BOLD}Tools installed${RESET}: see your shell — try ${DIM}htop, btop, rg, fzf (Ctrl-R), z, eza, bat${RESET}"
if ! $NO_SHELL_CONFIG; then
  echo "  ${BOLD}Shell config${RESET}: bashrc updated. ${YELLOW}Run \`source ~/.bashrc\` or open a new shell.${RESET}"
fi
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "  ${BOLD}Corpus harness${RESET}: ${DIM}cd $REPO_DIR && pnpm harness --list${RESET} (after sourcing bashrc)"
  echo "  ${BOLD}Cheat sheet${RESET}:    ${DIM}$REPO_DIR/domains/_shared/rehearsal/CHEATSHEET.md${RESET}"
fi
echo ""

if $LAUNCH; then
  if [[ -z "$ANTHROPIC_KEY" ]]; then
    err "--launch given but no API key. Set --anthropic-key=... or ANTHROPIC_API_KEY env var."
    exit 1
  fi
  if ! command -v claude >/dev/null 2>&1; then
    err "claude not installed. Re-run without --no-claude."
    exit 1
  fi
  step "launching Claude (model=$MODEL effort=$EFFORT)"
  echo ""
  cd "$REPO_DIR"
  export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
  exec claude --model "$MODEL" --effort "$EFFORT"
elif [[ -n "$ANTHROPIC_KEY" ]]; then
  warn "API key was provided but --launch not specified. To launch later:"
  echo "    export ANTHROPIC_API_KEY='<your-key>'"
  echo "    claude --model $MODEL --effort $EFFORT"
fi
