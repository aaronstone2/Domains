#!/usr/bin/env bash
# fix/prune.sh — docker system prune -af (frees disk)
#
# Default: dry-run. Add --apply to execute.
# WARNING: removes ALL stopped containers + ALL images not in use by a running
# container + all networks not in use + all build cache. Cannot be rolled back.
#
# Usage:   fix/prune.sh [--apply]
# Example: fix/prune.sh --apply

set +e

APPLY=false
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; -h|--help)
  sed -n '2,10p' "$0" | sed 's/^# *//'; exit 0 ;;
esac; done

section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

section "BEFORE"
docker system df 2>/dev/null

section "FIX: docker system prune -af"
echo "  WARNING: removes stopped containers + unused images + unused networks + build cache"
run "docker system prune -af"

section "AFTER"
$APPLY && docker system df 2>/dev/null

section "VERIFY"
echo "  docker system df  (compare BEFORE vs AFTER reclaim)"
echo "  df -h /var/lib/docker  (check filesystem-level freed bytes)"

$APPLY || echo "(dry-run; pass --apply to execute)"
