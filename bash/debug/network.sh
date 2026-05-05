#!/usr/bin/env bash
# debug/network.sh — diagnose container networking (interfaces, routes, conntrack, listening ports)
#
# Reads: ss, ip, conntrack, /etc/resolv.conf
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/network.sh [container]
# Example: debug/network.sh staff-tls
#          debug/network.sh                  # host-wide

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Listening ports (host)"
sudo ss -tlnp 2>/dev/null | head -15

section "Interfaces (host)"
ip -br link 2>/dev/null
ip -br addr 2>/dev/null

section "Routes (host)"
ip route show 2>/dev/null

section "Conntrack count"
echo "current: $(sudo cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo n/a)"
echo "max:     $(sudo cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo n/a)"

section "iptables FORWARD chain (top 10 rules)"
sudo iptables -L FORWARD -n -v --line-numbers 2>/dev/null | head -15

if [ -n "$c" ]; then
  section "Container DNS"
  in_c "cat /etc/resolv.conf"
  section "Container listening ports"
  in_c "ss -tlnp 2>/dev/null | head"
  section "Container interfaces + routes"
  in_c "ip -br addr 2>/dev/null; ip route show 2>/dev/null"
  section "Container egress test (1.1.1.1:443)"
  in_c "nc -zv -w 3 1.1.1.1 443 2>&1"
fi
