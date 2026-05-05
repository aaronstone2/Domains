#!/usr/bin/env bash
# debug/gateway.sh — multi-symptom service gateway full dump (calls all the debug/ scripts)
#
# Use when N symptoms unknown — gateway 503 + multiple downstreams failing.
# Runs: oom + dns + tls + network + procs + cgroup + disk + secrets + restart
#
# Reads: see each individual script
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/gateway.sh <container>
# Example: debug/gateway.sh staff-tls > notes/logs/$(date +%F-%H%M)-gateway.log

set +e

c="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
section() { echo ""; echo ""; echo "######## $* ########"; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,11p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container>" >&2; exit 2; }

section "ENV + HOSTS + RESOLV.CONF"
docker exec "$c" sh -c 'env | sort' 2>/dev/null | head -30
echo ""
docker exec "$c" cat /etc/hosts 2>/dev/null
echo ""
docker exec "$c" cat /etc/resolv.conf 2>/dev/null

section "PROCS"
bash "$HERE/procs.sh" "$c" 2>&1 | head -60

section "NETWORK"
bash "$HERE/network.sh" "$c" 2>&1 | head -40

section "CGROUP"
bash "$HERE/cgroup.sh" "$c" 2>&1 | head -30

section "OOM"
bash "$HERE/oom.sh" "$c" 2>&1 | head -25

section "DISK"
bash "$HERE/disk.sh" "$c" 2>&1 | head -25

section "SECRETS"
bash "$HERE/secrets.sh" "$c" 2>&1 | head -20

section "RESTART"
bash "$HERE/restart.sh" "$c" 2>&1 | head -20

echo ""
echo "######## DONE — re-read top to bottom; group failures by error CLASS not by service ########"
