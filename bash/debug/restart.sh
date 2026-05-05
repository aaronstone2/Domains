#!/usr/bin/env bash
# debug/restart.sh — container restart-loop investigation
#
# Reads: docker inspect, docker events, docker logs
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/restart.sh <container>
# Example: debug/restart.sh staff-tls

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container>" >&2; exit 2; }

section "State + restart count"
docker inspect "$c" --format 'name={{.Name}} status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} policy={{.HostConfig.RestartPolicy.Name}}'

section "Recent die events (last hour)"
timeout 3 docker events --since 1h --until now --filter container="$c" --filter event=die --format '{{.Time}} exit={{.Actor.Attributes.exitCode}} signal={{.Actor.Attributes.signal}}' 2>/dev/null

section "Last 30 log lines"
docker logs --tail 30 "$c" 2>&1 | tail -30

section "Last log timestamps (gap detection)"
docker logs --tail 5 -t "$c" 2>&1 | tail -5

section "Hint"
echo "Exit 137 → SIGKILL by OOM-killer (cgroup mem limit hit). Run: bash/debug/oom.sh $c"
echo "Exit 143 → SIGTERM (graceful shutdown). Likely intentional or readiness probe failed."
echo "Exit 1   → app-level error. Read the logs above for the stack trace."
echo "Exit 0   → app returned cleanly but restart policy keeps recreating it."
echo "Restart policy 'always' or 'unless-stopped' will respawn even on exit 0."
