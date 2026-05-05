#!/usr/bin/env bash
# debug/procs.sh — process tree + zombies + D-state + top CPU
#
# Reads: ps, /proc
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/procs.sh [container]
# Example: debug/procs.sh staff-tls

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Process tree (top 40)"
in_c "ps auxf 2>/dev/null || ps -ef --forest" | head -40

section "PID 1 (matters for zombie reaping)"
in_c "ps -eo pid,cmd | head -2 | tail -1"

section "Zombies (Z-state)"
zc=$(in_c "ps -eo state | awk '\$1==\"Z\"' | wc -l")
echo "zombie count: $zc"
if [ "$zc" -gt 0 ]; then
  in_c "ps -eo pid,ppid,state,cmd | awk '\$3 ~ /^Z/'" | head -10
  echo ""
  echo "Hint: 'docker run --init' adds tini as PID 1 to reap"
fi

section "D-state (uninterruptible — usually I/O)"
in_c "ps -eo pid,stat,wchan,cmd | awk '\$2 ~ /^D/'"

section "Top CPU (top 10)"
in_c "ps -eo pid,pcpu,rss,cmd --sort=-pcpu | head -10"

section "Top RSS (top 10)"
in_c "ps -eo pid,rss,cmd --sort=-rss | head -10"
