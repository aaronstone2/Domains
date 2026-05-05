#!/usr/bin/env bash
# fix/dns.sh — prepend custom DNS to container resolv.conf
#
# Default: dry-run. Add --apply to execute.
# Note: changes inside container revert on container restart. Use docker-compose
# 'dns:' field for permanent.
#
# Usage:   fix/dns.sh <container> <dns_ip> [--apply]
# Example: fix/dns.sh staff-tls 10.0.0.53 --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; dns="$2"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$dns" ] && { echo "usage: $0 <container> <dns_ip> [--apply]" >&2; exit 2; }

section "TEMP FIX: prepend nameserver $dns to '$c' resolv.conf"
run "docker exec $c sh -c 'cp /etc/resolv.conf /etc/resolv.conf.bak'"
run "docker exec $c sh -c '(echo \"nameserver $dns\"; cat /etc/resolv.conf) > /tmp/.r && cat /tmp/.r > /etc/resolv.conf && rm /tmp/.r'"

section "PERMANENT FIX"
echo "  docker run:     --dns $dns ..."
echo "  docker-compose: dns: [\"$dns\"]"
echo "  Better — host systemd-resolved forwards .corp.internal to corp DNS:"
echo "    /etc/systemd/resolved.conf.d/corp.conf:"
echo "      [Resolve]"
echo "      DNS=$dns"
echo "      Domains=~corp.internal"
echo "    systemctl restart systemd-resolved"

section "VERIFY"
echo "  docker exec $c cat /etc/resolv.conf | head -3"
echo "  docker exec $c getent hosts <some-corp-host>"

$APPLY || echo "(dry-run; pass --apply to execute)"
