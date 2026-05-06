#!/usr/bin/env bash
# debug/compose.sh — diagnose docker-compose / docker compose issues
#
# Reads: compose config, service status, logs, networks, volumes
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/compose.sh [compose-file] [service]
# Example: debug/compose.sh docker-compose.yml web
#          debug/compose.sh                          # auto-detect compose file

set +e

f="${1:-}"
svc="${2:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$f" = "-h" ] || [ "$f" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

# Auto-detect compose file
if [ -z "$f" ]; then
  for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    [ -f "$candidate" ] && f="$candidate" && break
  done
fi
[ -z "$f" ] && { echo "ERROR: no compose file found. Pass one as arg or run from project dir." >&2; exit 2; }

DC="docker compose -f $f"
# fallback to docker-compose if docker compose not available
$DC version &>/dev/null || DC="docker-compose -f $f"

section "Compose file validation"
$DC config --quiet 2>&1 && echo "✓ config valid" || echo "✗ config INVALID — see errors above"

section "Compose file: services defined"
$DC config --services 2>/dev/null

section "Service status"
$DC ps 2>/dev/null

section "Containers with exit codes"
$DC ps -a --format 'table {{.Name}}\t{{.Status}}\t{{.ExitCode}}' 2>/dev/null || \
  $DC ps -a 2>/dev/null

if [ -n "$svc" ]; then
  section "Logs for service: $svc (last 40 lines)"
  $DC logs --tail 40 "$svc" 2>&1

  section "Environment for service: $svc"
  cid=$($DC ps -q "$svc" 2>/dev/null | head -1)
  if [ -n "$cid" ]; then
    docker inspect "$cid" --format '{{json .Config.Env}}' 2>/dev/null | tr ',' '\n' | tr -d '[]"'
  else
    echo "(service not running — can't inspect env)"
  fi
else
  section "Logs for all services (last 20 lines each)"
  $DC logs --tail 20 2>&1
fi

section "Networks created by compose"
docker network ls --filter "label=com.docker.compose.project" --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}' 2>/dev/null

section "Volumes created by compose"
docker volume ls --filter "label=com.docker.compose.project" --format 'table {{.Name}}\t{{.Driver}}' 2>/dev/null

section "Dependency graph"
$DC config --format json 2>/dev/null | python3 -c '
import sys,json
try:
  cfg = json.load(sys.stdin)
  svcs = cfg.get("services",{})
  for s,v in svcs.items():
    deps = v.get("depends_on",{})
    if isinstance(deps, list): deps = {d:{} for d in deps}
    for d,opts in deps.items():
      cond = opts.get("condition","started") if isinstance(opts,dict) else "started"
      print(f"  {s} -> {d} ({cond})")
  if not any(v.get("depends_on") for v in svcs.values()):
    print("  (no depends_on declared)")
except: print("  (could not parse config)")
' 2>/dev/null

section "HINTS"
echo "• If a service keeps restarting: check 'restart:' policy + exit code + logs"
echo "• If depends_on fails: use 'condition: service_healthy' + define a healthcheck"
echo "• If network issues between services: services on the same compose network use service NAME as hostname"
echo "• If env vars missing: check 'env_file:' path is correct relative to compose file"
