#!/usr/bin/env bash
# debug/volumes.sh — diagnose Docker volume / bind mount issues
#
# Reads: docker inspect mounts, volume ls, permissions, disk usage
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/volumes.sh [container]
# Example: debug/volumes.sh staff-tls
#          debug/volumes.sh              # list all volumes

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

if [ -n "$c" ]; then
  section "Mounts for container: $c"
  docker inspect "$c" --format '{{json .Mounts}}' 2>/dev/null | python3 -c '
import sys,json
try:
  mounts = json.load(sys.stdin)
  for m in mounts:
    print(f"  Type={m.get(\"Type\",\"?\")} Src={m.get(\"Source\",\"?\")} -> Dst={m.get(\"Destination\",\"?\")} RW={m.get(\"RW\",\"?\")} Propagation={m.get(\"Propagation\",\"\")}")
except: print("  (no mounts or parse error)")
' 2>/dev/null

  section "Bind mount source permissions (host side)"
  docker inspect "$c" --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | while read -r src; do
    [ -z "$src" ] && continue
    echo "  $src"
    ls -ld "$src" 2>/dev/null | sed 's/^/    /'
    stat -c '    uid=%u gid=%g mode=%a' "$src" 2>/dev/null
  done

  section "Container user (who is the process running as?)"
  docker exec "$c" id 2>/dev/null || echo "  (container not running)"

  section "Destination path permissions (inside container)"
  docker inspect "$c" --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' 2>/dev/null | while read -r dst; do
    [ -z "$dst" ] && continue
    docker exec "$c" ls -ld "$dst" 2>/dev/null | sed "s/^/  /"
  done

  section "Volume driver & options"
  docker inspect "$c" --format '{{range .Mounts}}{{if eq .Type "volume"}}Name={{.Name}} Driver={{.Driver}}{{"\n"}}{{end}}{{end}}' 2>/dev/null
fi

section "All Docker volumes"
docker volume ls --format 'table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}' 2>/dev/null

section "Dangling volumes (no container attached)"
docker volume ls -f dangling=true --format '{{.Name}}' 2>/dev/null | head -10

section "Volume disk usage"
docker system df -v 2>/dev/null | grep -A50 'VOLUME NAME' | head -20

section "HINTS"
echo "• Permission denied on bind mount: host UID must match container UID"
echo "  Fix: docker run -u \$(id -u):\$(id -g) or chown the host dir"
echo "• Data disappeared: check if you used a volume (persistent) vs tmpfs (ephemeral)"
echo "• Bind mount shows empty in container: host path might not exist (Docker creates empty dir)"
echo "• Read-only mount: check ':ro' suffix in -v or 'read_only: true' in compose"
echo "• Docker Desktop vs Linux: bind mount paths differ (/host_mnt/... on Desktop)"
