#!/usr/bin/env bash
# fix/proxy.sh — configure corporate proxy settings for tools
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/proxy.sh <proxy-url> [no-proxy-list] [--apply]
# Example: fix/proxy.sh http://proxy.corp.local:8080 "localhost,127.0.0.1,.corp.local" --apply
#          fix/proxy.sh http://proxy:3128 --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

proxy="$1"; noproxy="${2:-localhost,127.0.0.1}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$proxy" = "-h" ] || [ "$proxy" = "--help" ] || [ -z "$proxy" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Shell environment variables"
run "export HTTP_PROXY='$proxy'"
run "export HTTPS_PROXY='$proxy'"
run "export http_proxy='$proxy'"
run "export https_proxy='$proxy'"
run "export NO_PROXY='$noproxy'"
run "export no_proxy='$noproxy'"

section "Persist in /etc/profile.d/ (all users, all shells)"
run "echo 'export HTTP_PROXY=$proxy' | sudo tee /etc/profile.d/corp-proxy.sh"
run "echo 'export HTTPS_PROXY=$proxy' >> /etc/profile.d/corp-proxy.sh"
run "echo 'export NO_PROXY=$noproxy' >> /etc/profile.d/corp-proxy.sh"

section "npm proxy config"
run "npm config set proxy $proxy"
run "npm config set https-proxy $proxy"

section "pip proxy config"
run "pip config set global.proxy $proxy"

section "git proxy config"
run "git config --global http.proxy $proxy"
run "git config --global https.proxy $proxy"

section "Docker daemon proxy"
echo "  To configure Docker daemon to use proxy:"
echo "  sudo mkdir -p /etc/systemd/system/docker.service.d"
echo "  cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF"
echo "  [Service]"
echo "  Environment=\"HTTP_PROXY=$proxy\""
echo "  Environment=\"HTTPS_PROXY=$proxy\""
echo "  Environment=\"NO_PROXY=$noproxy\""
echo "  EOF"
echo "  sudo systemctl daemon-reload && sudo systemctl restart docker"

section "VERIFY"
echo "  curl -v --proxy $proxy https://pypi.org/simple/ 2>&1 | head -5"
echo "  npm config get proxy"
echo "  git config --global http.proxy"

$APPLY || echo "(dry-run; pass --apply to execute)"
