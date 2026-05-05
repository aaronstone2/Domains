#!/usr/bin/env bash
# debug/oom.sh — diagnose OOM kill of a container (or host-wide if no container)
#
# Reads: docker inspect, dmesg, cgroup memory.events, /proc/*/status VmSwap, ps RSS
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/oom.sh [container]
# Example: debug/oom.sh staff-tls
#          debug/oom.sh                       # host-wide
#          debug/oom.sh staff-tls > notes/logs/$(date +%F-%H%M)-oom.log

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Container OOM signal"
if [ -n "$c" ]; then
  docker inspect "$c" --format '{{.Name}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}} MemLimit={{.HostConfig.Memory}}'
  docker inspect "$c" --format 'log: {{.LogPath}}'
else
  echo "(no container — skipping docker inspect)"
fi

section "Kernel OOM events (last 10)"
sudo dmesg -T 2>/dev/null | grep -iE 'killed process|out of memory|oom-killer' | tail -10

section "Cgroup memory.events"
if [ -n "$c" ]; then
  cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
  cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/memory.events 2>/dev/null
else
  cat /sys/fs/cgroup/memory.events 2>/dev/null
fi

section "Top RSS consumers (host)"
ps -eo pid,rss,comm --sort=-rss | head -10

section "Per-process VmSwap (top 5 swappers)"
for p in /proc/[0-9]*; do
  s=$(awk '/^VmSwap/{print $2}' "$p"/status 2>/dev/null)
  [ -z "$s" ] || [ "$s" -eq 0 ] && continue
  printf '%s %skB %s\n' "$(basename "$p")" "$s" "$(cat "$p"/comm 2>/dev/null)"
done | sort -k2 -rn | head -5

section "Memory summary"
free -h
