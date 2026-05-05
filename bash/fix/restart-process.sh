#!/usr/bin/env bash
# fix/restart-process.sh — kill processes inside container so PID 1 respawns them
#
# Default: dry-run. Add --apply to execute.
# Most container PID 1s have a supervisor / restart policy that respawns the
# killed process. For containers where PID 1 is the app itself, use restart-container.
#
# Usage:   fix/restart-process.sh <container> [process_pattern] [--apply]
# Example: fix/restart-process.sh staff-tls 'gateway\|node' --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; pat="${2:-gateway\\|server\\|node}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container> [pattern] [--apply]" >&2; exit 2; }

section "TEMP FIX: kill processes matching '$pat' in '$c' (PID 1 should respawn)"
run "docker exec $c sh -c 'pkill -f $pat'"

if $APPLY; then sleep 1; fi

section "VERIFY"
echo "  docker exec $c sh -c 'pgrep -af $pat'  # should show new PIDs"

$APPLY || echo "(dry-run; pass --apply to execute)"
