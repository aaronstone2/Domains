#!/usr/bin/env bash
# debug/disk.sh — disk usage + I/O activity + per-process I/O
#
# Reads: df, du, iostat, /proc/<pid>/io
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/disk.sh [container]
# Example: debug/disk.sh staff-tls

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi

section "df -h"
df -h | head -10

section "Top dirs by size (under /var /tmp /home /var/lib/docker)"
for d in /var /tmp /home /var/lib/docker; do
  [ -d "$d" ] && du -sh "$d"/* 2>/dev/null | sort -h | tail -3
done

section "docker system df"
docker system df 2>/dev/null

section "I/O activity (2 second sample)"
iostat -xz 1 2 2>/dev/null | tail -20

section "Per-process I/O (top 5 RSS)"
ps -eo pid,cmd --sort=-rss | head -6 | awk 'NR>1 {print $1}' | while read p; do
  [ -f "/proc/$p/io" ] && { echo "PID $p:"; cat "/proc/$p/io" 2>/dev/null | sed 's/^/  /'; }
done

section "Inode usage"
df -i | head -10

if [ -n "$c" ]; then
  section "Container df"
  docker exec "$c" df -h 2>/dev/null | head
fi

section "Hint"
echo "ENOSPC + df shows free → check inode usage (df -i) or container's overlay diff"
echo "iostat %util > 80 sustained → I/O bound; check what's hot in /proc/<pid>/io"
echo "/var/lib/docker huge → 'docker system prune -af' frees stopped containers + unused images"
