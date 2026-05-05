#!/usr/bin/env bash
# fix/hosts-rm.sh — remove /etc/hosts entry from container
#
# Default: dry-run. Add --apply to execute.
#
# Usage:   fix/hosts-rm.sh <container> <hostname> [--apply]
# Example: fix/hosts-rm.sh staff-tls bad.host.example --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; host="$2"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,8p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$host" ] && { echo "usage: $0 <container> <hostname> [--apply]" >&2; exit 2; }

section "TEMP FIX: remove /etc/hosts entries for '$host' in '$c'"
run "docker exec $c sh -c 'sed -i \"/\\b$host\\b/d\" /etc/hosts'"

section "VERIFY"
echo "  docker exec $c getent hosts $host  (should fail)"

$APPLY || echo "(dry-run; pass --apply to execute)"
