#!/usr/bin/env bash
# fix/env.sh — set env var inside running container (process needs restart to pick up)
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/env.sh <container> <KEY> <VALUE> [--apply]
# Example: fix/env.sh staff-tls NODE_EXTRA_CA_CERTS /etc/ssl/custom/full-chain.pem --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

c="$1"; key="$2"; val="$3"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$key" ] || [ -z "$val" ] && { echo "usage: $0 <container> <KEY> <VALUE> [--apply]" >&2; exit 2; }

section "TEMP FIX: write env to /etc/profile.d (picked up by new shells)"
run "docker exec $c sh -c 'echo \"export $key=$val\" >> /etc/profile.d/dfix-env.sh'"
echo "  NOTE: running processes won't see this until restarted."
echo "  Next step: bash bash/fix/restart-process.sh $c --apply"

section "PERMANENT FIX (do this in your deployment config)"
echo "  docker-compose: add 'environment: $key: $val' under the service"
echo "  docker run:     -e $key=$val ..."
echo "  k8s:            env: [{name: $key, value: $val}]"

section "VERIFY"
echo "  docker exec $c sh -c '. /etc/profile.d/dfix-env.sh && echo \$${key}'  # new shell"
echo "  docker exec $c sh -c 'cat /proc/1/environ | tr \"\\0\" \"\\n\" | grep $key'  # PID 1 (needs restart to change)"

$APPLY || echo "(dry-run; pass --apply to execute)"
