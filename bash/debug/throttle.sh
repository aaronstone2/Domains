#!/usr/bin/env bash
# debug/throttle.sh — CPU throttling probe (DevBox classic: "slow but %CPU low")
#
# Reads: /sys/fs/cgroup/cpu.stat, docker stats
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/throttle.sh [container]
# Example: debug/throttle.sh staff-tls

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Host: cpu.stat throttling"
cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep -E 'nr_throttled|throttled_usec'

if [ -n "$c" ]; then
  cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
  base=/sys/fs/cgroup/system.slice/docker-${cid}.scope
  section "Container cpu.stat"
  cat "$base/cpu.stat" 2>/dev/null | grep -E 'nr_throttled|throttled_usec'
  section "Container cpu.max (quota period)"
  cat "$base/cpu.max" 2>/dev/null
  section "docker stats (point-in-time %CPU)"
  docker stats --no-stream --format 'name={{.Name}} cpu={{.CPUPerc}} mem={{.MemPerc}}' "$c"
fi

section "Sample throttled_usec twice with 2s gap"
if [ -n "$c" ]; then
  base=/sys/fs/cgroup/system.slice/docker-$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null).scope
  t1=$(awk '/throttled_usec/ {print $2}' "$base/cpu.stat" 2>/dev/null)
  sleep 2
  t2=$(awk '/throttled_usec/ {print $2}' "$base/cpu.stat" 2>/dev/null)
else
  t1=$(awk '/throttled_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null)
  sleep 2
  t2=$(awk '/throttled_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null)
fi
echo "delta: $((t2 - t1)) microseconds throttled in 2s"

section "Hint"
echo "throttled_usec climbing while %CPU appears low → cgroup quota is the bottleneck"
echo "Fix: raise --cpus / --cpu-quota, or shed load, or profile what's hot"
echo "DevBox often allots fractional CPU shares — visible only via cgroup, not top"
