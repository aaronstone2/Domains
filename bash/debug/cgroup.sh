#!/usr/bin/env bash
# debug/cgroup.sh — cgroup limits, memory.events, cpu.stat throttling
#
# Reads: /sys/fs/cgroup/* (host + container scope)
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/cgroup.sh [container]
# Example: debug/cgroup.sh staff-tls

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Host: cgroup memory.events"
cat /sys/fs/cgroup/memory.events 2>/dev/null

section "Host: cgroup cpu.stat (throttling)"
cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep -E 'nr_throttled|throttled_usec'

section "Cgroup driver"
docker info 2>/dev/null | grep -i cgroup

if [ -n "$c" ]; then
  cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
  base=/sys/fs/cgroup/system.slice/docker-${cid}.scope
  section "Container scope: $base"
  ls "$base" 2>/dev/null | head -10
  section "Container memory"
  cat "$base/memory.events" 2>/dev/null
  cat "$base/memory.current" 2>/dev/null | xargs -I{} echo "current: {} bytes"
  cat "$base/memory.max" 2>/dev/null | xargs -I{} echo "max:     {} bytes"
  section "Container cpu"
  cat "$base/cpu.stat" 2>/dev/null | grep -E 'nr_throttled|throttled_usec'
  cat "$base/cpu.max" 2>/dev/null | xargs -I{} echo "cpu.max: {}"
  section "Container pids"
  cat "$base/pids.current" 2>/dev/null | xargs -I{} echo "current: {}"
  cat "$base/pids.max" 2>/dev/null | xargs -I{} echo "max:     {}"
fi

section "Hint"
echo "memory.events oom_kill > 0 → cgroup OOM-killed a proc"
echo "cpu.stat throttled_usec climbing → CPU quota exceeded (cgroup throttle)"
echo "pids.current near pids.max → about to hit pid limit"
