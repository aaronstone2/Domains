#!/usr/bin/env bash
# debug/logs.sh — diagnose container log issues (rotation, size, disk impact)
#
# Reads: docker inspect LogPath, log file sizes, logrotate config
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/logs.sh [container]
# Example: debug/logs.sh staff-tls
#          debug/logs.sh              # check all containers

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Docker logging driver (daemon default)"
docker info --format '{{.LoggingDriver}}' 2>/dev/null
cat /etc/docker/daemon.json 2>/dev/null | python3 -c '
import sys,json
try:
  cfg = json.load(sys.stdin)
  ld = cfg.get("log-driver","(not set)")
  lo = cfg.get("log-opts",{})
  print(f"  daemon.json: driver={ld} opts={lo}")
except: print("  (no daemon.json or parse error)")
' 2>/dev/null

if [ -n "$c" ]; then
  section "Log config for container: $c"
  docker inspect "$c" --format '{{.HostConfig.LogConfig.Type}} opts={{json .HostConfig.LogConfig.Config}}' 2>/dev/null

  section "Log file path + size"
  logpath=$(docker inspect "$c" --format '{{.LogPath}}' 2>/dev/null)
  if [ -n "$logpath" ] && [ -f "$logpath" ]; then
    echo "  Path: $logpath"
    ls -lh "$logpath" 2>/dev/null | awk '{print "  Size: "$5}'
    echo "  Lines: $(wc -l < "$logpath" 2>/dev/null)"
  else
    echo "  (no log file found — might be using non-json-file driver)"
  fi

  section "Last 10 log lines"
  docker logs --tail 10 "$c" 2>&1

  section "Log rate (lines in last 60s)"
  docker logs --since 60s "$c" 2>&1 | wc -l | { read -r n; echo "  $n lines in last 60s ($((n/60)) lines/sec)"; }
else
  section "All container log sizes (sorted by size)"
  docker ps -aq 2>/dev/null | while read -r cid; do
    name=$(docker inspect "$cid" --format '{{.Name}}' 2>/dev/null | sed 's/^\///')
    logpath=$(docker inspect "$cid" --format '{{.LogPath}}' 2>/dev/null)
    if [ -n "$logpath" ] && [ -f "$logpath" ]; then
      size=$(du -sh "$logpath" 2>/dev/null | awk '{print $1}')
      printf "  %-30s %s  %s\n" "$name" "$size" "$logpath"
    fi
  done | sort -k2 -rh
fi

section "Docker disk usage (overall)"
docker system df 2>/dev/null

section "/var/lib/docker size"
sudo du -sh /var/lib/docker/containers/ 2>/dev/null
sudo du -sh /var/lib/docker/overlay2/ 2>/dev/null

section "Host log disk usage"
du -sh /var/log/ 2>/dev/null
ls -lhS /var/log/*.log 2>/dev/null | head -5

section "HINTS"
echo "• Container log filling disk: add --log-opt max-size=10m --log-opt max-file=3"
echo "• In docker-compose: logging: { driver: json-file, options: { max-size: 10m, max-file: '3' } }"
echo "• In daemon.json: { \"log-opts\": { \"max-size\": \"10m\", \"max-file\": \"3\" } }"
echo "• Truncate a log NOW: sudo truncate -s 0 \$(docker inspect --format '{{.LogPath}}' CONTAINER)"
echo "• Check log rate: docker logs --since 60s CONTAINER 2>&1 | wc -l"
