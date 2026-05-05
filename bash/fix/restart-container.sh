#!/usr/bin/env bash
# fix/restart-container.sh — docker restart <c>
#
# Default: dry-run. Add --apply to execute.
# Loses all in-container state changes (env tweaks, /etc/hosts edits, etc.).
# Use when you need to re-pick-up image/volume/env changes from docker-compose.
#
# Usage:   fix/restart-container.sh <container> [--apply]
# Example: fix/restart-container.sh staff-tls --apply

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

section "TEMP FIX: docker restart $c"
echo "  WARNING: loses in-container env/hosts/dns changes you may have made"
run "docker restart $c"

section "VERIFY"
echo "  docker inspect $c --format '{{.State.Status}} restarts={{.RestartCount}}'"
echo "  docker logs --tail 20 $c"

$APPLY || echo "(dry-run; pass --apply to execute)"
