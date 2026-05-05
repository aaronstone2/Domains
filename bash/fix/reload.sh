#!/usr/bin/env bash
# fix/reload.sh — SIGHUP processes inside container (graceful reload)
#
# Default: dry-run. Add --apply to execute.
# Use when app honors SIGHUP for config-reload (nginx, haproxy, etc.). For
# Node/Python apps that don't, use restart-process instead.
#
# Usage:   fix/reload.sh <container> [process_pattern] [--apply]
# Example: fix/reload.sh proxy nginx --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; pat="${2:-node}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container> [pattern] [--apply]" >&2; exit 2; }

section "TEMP FIX: SIGHUP processes matching '$pat' in '$c'"
run "docker exec $c sh -c 'pgrep -f $pat | xargs -r kill -HUP'"

section "VERIFY"
echo "  docker exec $c sh -c 'pgrep -af $pat'"

$APPLY || echo "(dry-run; pass --apply to execute)"
