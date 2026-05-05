#!/usr/bin/env bash
# debug/leak.sh — sample RSS + fd count over time to detect memory/fd leaks
#
# Reads: docker exec ps + /proc/<pid>/{status,fd}, optionally curls a port
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/leak.sh <container> [n_samples] [process_pattern]
# Example: debug/leak.sh staff-tls 30 'gateway\|node'
#          debug/leak.sh staff-tls 20

set +e

c="${1:-}"; n="${2:-30}"; pat="${3:-gateway\|server\|node}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container> [n_samples] [pattern]" >&2; exit 2; }

section "Leak watch ($n samples, 1s apart) on '$pat' inside '$c'"
echo "Tip: generate load between samples (e.g. curl the endpoint in another tab)"
echo "i  pid  RSS_MB  fd_count"
for i in $(seq 1 "$n"); do
  pid=$(docker exec "$c" sh -c "pgrep -f '$pat' | head -1" 2>/dev/null)
  [ -z "$pid" ] && { echo "$i  ?    ?       ? (no pid match)"; continue; }
  rss=$(docker exec "$c" sh -c "awk '/VmRSS/ {print int(\$2/1024)}' /proc/$pid/status 2>/dev/null")
  fd=$(docker exec "$c" sh -c "ls /proc/$pid/fd 2>/dev/null | wc -l")
  printf "%-3d %-4s %-7s %s\n" "$i" "$pid" "$rss" "$fd"
  sleep 1
done

section "Hint"
echo "RSS climbing monotonically across samples → memory leak"
echo "fd_count climbing → fd leak (forgot to close sockets / file handles)"
echo "Both flat → not a leak; might just be undersized memory limit"
