#!/usr/bin/env bash
# debug/dns.sh — diagnose DNS resolution from a container (or host)
#
# Reads: resolv.conf, /etc/hosts, dig, getent, resolvectl
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/dns.sh [container] [hostname]
# Example: debug/dns.sh staff-tls db.corp.internal
#          debug/dns.sh '' google.com               # host-side
#          debug/dns.sh staff-tls db.corp.internal > notes/logs/$(date +%F-%H%M)-dns.log

set +e

c="${1:-}"; target="${2:-google.com}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "resolv.conf ${c:+(in $c)}"
in_c "cat /etc/resolv.conf"

section "/etc/hosts ${c:+(in $c)}"
in_c "cat /etc/hosts | grep -v '^#' | grep -v '^$'"

section "dig +short $target ${c:+(in $c)}"
in_c "dig +short $target 2>/dev/null"

section "getent hosts $target ${c:+(in $c)}"
in_c "getent hosts $target"

section "Forward + reverse trace"
in_c "dig +trace $target 2>/dev/null | tail -10"

section "resolvectl status (host, if present)"
resolvectl status 2>/dev/null | head -20

section "Hint"
echo "Container DNS chain: container → 127.0.0.11 (Docker embedded) → host's resolv.conf"
echo "If 127.0.0.53 in host resolv.conf: systemd-resolved is the next hop"
echo "Permanent fix: docker-compose 'dns:' field, or daemon.json 'dns' key"
