#!/usr/bin/env bash
# fix/compose.sh — fix common docker-compose issues
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/compose.sh <action> [compose-file] [--apply]
# Actions: restart <svc>    — restart a specific service
#          rebuild <svc>    — rebuild + restart a service (no cache)
#          reset            — down + up all services (clean start)
#          fix-deps         — add healthcheck-based depends_on
# Example: fix/compose.sh restart web --apply
#          fix/compose.sh rebuild api docker-compose.yml --apply
#          fix/compose.sh reset --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

action="$1"; svc="$2"; f="${3:-docker-compose.yml}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$action" = "-h" ] || [ "$action" = "--help" ] || [ -z "$action" ]; then
  sed -n '2,13p' "$0" | sed 's/^# *//'
  exit 0
fi

# Auto-detect compose file
for candidate in "$f" docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [ -f "$candidate" ] && f="$candidate" && break
done

DC="docker compose -f $f"
$DC version &>/dev/null || DC="docker-compose -f $f"

case "$action" in
  restart)
    [ -z "$svc" ] && { echo "usage: $0 restart <service> [--apply]" >&2; exit 2; }
    section "Restarting service: $svc"
    run "$DC restart $svc"
    ;;
  rebuild)
    [ -z "$svc" ] && { echo "usage: $0 rebuild <service> [--apply]" >&2; exit 2; }
    section "Rebuilding service (no cache): $svc"
    run "$DC build --no-cache $svc"
    run "$DC up -d $svc"
    ;;
  reset)
    section "Full reset: down + up"
    run "$DC down --remove-orphans"
    run "$DC up -d"
    ;;
  fix-deps)
    section "MANUAL FIX: Add healthcheck-based depends_on"
    echo "  In your compose file, change:"
    echo ""
    echo "    depends_on:"
    echo "      - db"
    echo ""
    echo "  To:"
    echo ""
    echo "    depends_on:"
    echo "      db:"
    echo "        condition: service_healthy"
    echo ""
    echo "  And add a healthcheck to the db service:"
    echo ""
    echo "    healthcheck:"
    echo "      test: [\"CMD\", \"pg_isready\", \"-U\", \"postgres\"]"
    echo "      interval: 5s"
    echo "      timeout: 5s"
    echo "      retries: 5"
    ;;
  *)
    echo "Unknown action: $action" >&2
    echo "Actions: restart, rebuild, reset, fix-deps" >&2
    exit 2
    ;;
esac

section "VERIFY"
echo "  $DC ps"
$APPLY && $DC ps 2>/dev/null

$APPLY || echo "(dry-run; pass --apply to execute)"
