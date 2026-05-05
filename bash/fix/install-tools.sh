#!/usr/bin/env bash
# fix/install-tools.sh — install dig+openssl+curl+jq inside container (debugging tools)
#
# Default: dry-run. Add --apply to execute.
# Tries apt-get first (Debian/Ubuntu base), falls back to apk (Alpine).
#
# Usage:   fix/install-tools.sh <container> [--apply]
# Example: fix/install-tools.sh staff-tls --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container> [--apply]" >&2; exit 2; }

section "FIX: install diagnostic tools in '$c' (apt or apk)"
run "docker exec $c sh -c '(apt-get update -y && apt-get install -y --no-install-recommends dnsutils openssl curl jq net-tools iproute2) 2>/dev/null || (apk add --no-cache bind-tools openssl curl jq net-tools iproute2)'"

section "VERIFY"
echo "  docker exec $c sh -c 'which dig openssl curl jq'"

section "PERMANENT FIX"
echo "  Bake into Dockerfile: RUN apt-get install -y dnsutils openssl curl jq"
echo "  Or use a debug-bigger image variant for staging only"
echo "  Or use docker debug image: docker run -it --pid=container:$c nicolaka/netshoot"

$APPLY || echo "(dry-run; pass --apply to execute)"
