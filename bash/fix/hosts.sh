#!/usr/bin/env bash
# fix/hosts.sh — append /etc/hosts entry inside container
#
# Default: dry-run. Add --apply to execute.
#
# Usage:   fix/hosts.sh <container> <ip> <hostname> [--apply]
# Example: fix/hosts.sh staff-tls 10.0.0.5 db.corp.internal --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; ip="$2"; host="$3"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,8p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$ip" ] || [ -z "$host" ] && { echo "usage: $0 <container> <ip> <hostname> [--apply]" >&2; exit 2; }

section "TEMP FIX: append /etc/hosts entry inside '$c'"
run "docker exec $c sh -c 'echo \"$ip  $host\" >> /etc/hosts'"

section "PERMANENT FIX"
echo "  docker-compose: under the service:"
echo "    extra_hosts:"
echo "      - \"$host:$ip\""
echo "  k8s pod spec:"
echo "    hostAliases:"
echo "      - ip: \"$ip\""
echo "        hostnames: [\"$host\"]"

section "VERIFY"
echo "  docker exec $c getent hosts $host"

$APPLY || echo "(dry-run; pass --apply to execute)"
