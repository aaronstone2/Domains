#!/usr/bin/env bash
# fix/volume-perms.sh — fix Docker volume / bind mount permission issues
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/volume-perms.sh <container> <mount-path> [--apply]
# Example: fix/volume-perms.sh staff-tls /app/data --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

c="$1"; mpath="$2"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,8p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$mpath" ] && { echo "usage: $0 <container> <mount-path> [--apply]" >&2; exit 2; }

section "Current state"
echo "  Container user:"
docker exec "$c" id 2>/dev/null

echo "  Mount info:"
docker inspect "$c" --format '{{json .Mounts}}' 2>/dev/null | python3 -c '
import sys,json
mpath = "'"$mpath"'"
try:
  mounts = json.load(sys.stdin)
  for m in mounts:
    if m.get("Destination") == mpath:
      print(f"  Type={m[\"Type\"]} Src={m[\"Source\"]} RW={m[\"RW\"]}")
except: pass
' 2>/dev/null

echo "  Host-side permissions:"
src=$(docker inspect "$c" --format '{{range .Mounts}}{{if eq .Destination "'"$mpath"'"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)
[ -n "$src" ] && ls -ld "$src" 2>/dev/null | sed 's/^/    /'

section "Fix option 1: Match container UID on host"
container_uid=$(docker exec "$c" id -u 2>/dev/null)
container_gid=$(docker exec "$c" id -g 2>/dev/null)
if [ -n "$src" ] && [ -n "$container_uid" ]; then
  run "sudo chown -R $container_uid:$container_gid '$src'"
else
  echo "  (can't determine source path or container UID)"
fi

section "Fix option 2: Run container as current host user"
echo "  Recreate with: docker run -u \$(id -u):\$(id -g) ..."
echo "  Or in compose: user: \"\${UID}:\${GID}\""

section "Fix option 3: Make world-writable (least secure)"
if [ -n "$src" ]; then
  run "sudo chmod -R 777 '$src'"
  echo "  WARNING: world-writable — use only for dev/testing"
fi

section "VERIFY"
echo "  docker exec $c touch $mpath/test-write && echo 'write OK' && docker exec $c rm $mpath/test-write"
$APPLY && docker exec "$c" sh -c "touch $mpath/.perm-test && rm $mpath/.perm-test && echo 'write OK'" 2>/dev/null

$APPLY || echo "(dry-run; pass --apply to execute)"
