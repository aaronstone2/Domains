#!/usr/bin/env bash
# debug/ulimits.sh — fd exhaustion / resource limit check
#
# Reads: /proc/<pid>/limits, /proc/<pid>/fd, sysctl, pids
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/ulimits.sh [container] [process_pattern]
# Example: debug/ulimits.sh staff-tls 'gateway\|node'
#          debug/ulimits.sh                              # host-wide top fd consumers

set +e

c="${1:-}"; pat="${2:-}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "System-wide file descriptor usage"
echo "fs.file-max:  $(sysctl -n fs.file-max 2>/dev/null || echo n/a)"
echo "fs.file-nr:   $(sysctl -n fs.file-nr 2>/dev/null || echo n/a)  (allocated  free  max)"

section "System-wide PID limit"
echo "kernel.pid_max:  $(sysctl -n kernel.pid_max 2>/dev/null || echo n/a)"
echo "PIDs in use:     $(ls /proc/ 2>/dev/null | grep '^[0-9]' | wc -l)"

if [ -n "$pat" ]; then
  section "Target process ($pat) fd usage vs limit"
  pid=$(in_c "pgrep -f '$pat' | head -1")
  if [ -n "$pid" ] && [ "$pid" != "0" ]; then
    fd_count=$(in_c "ls /proc/$pid/fd 2>/dev/null | wc -l")
    fd_limit=$(in_c "awk '/Max open files/ {print \$4}' /proc/$pid/limits 2>/dev/null")
    echo "PID $pid: using $fd_count / $fd_limit fds"
    if [ -n "$fd_count" ] && [ -n "$fd_limit" ] && [ "$fd_limit" != "unlimited" ]; then
      pct=$((fd_count * 100 / fd_limit))
      echo "Usage: ${pct}%"
      [ "$pct" -gt 80 ] && echo "WARNING: above 80% — EMFILE imminent!"
    fi
    section "fd breakdown (top types)"
    in_c "ls -la /proc/$pid/fd 2>/dev/null | awk '{print \$NF}' | sed 's|.*|&|' | sort | uniq -c | sort -rn | head -10"
  else
    echo "(no process matching '$pat' found)"
  fi
fi

section "Top fd consumers (processes near their limit)"
for p in /proc/[0-9]*; do
  pid=$(basename "$p")
  h=$(awk '/Max open files/{print $4}' "$p/limits" 2>/dev/null)
  used=$(ls "$p/fd" 2>/dev/null | wc -l)
  [ -z "$h" ] || [ "$h" = "unlimited" ] && continue
  [ "$used" -gt "$((h / 2))" ] && printf 'PID=%-7s used=%-6s limit=%-6s %s\n' "$pid" "$used" "$h" "$(cat "$p/comm" 2>/dev/null)"
done | sort -t= -k3 -rn | head -10

section "Hint"
echo "EMFILE = too many open files → process hit its fd limit"
echo "Fix: raise limit with 'prlimit --pid PID --nofile=soft:hard'"
echo "Permanent: docker run --ulimit nofile=65536:65536"
echo "Or in docker-compose: ulimits: { nofile: { soft: 65536, hard: 65536 } }"
