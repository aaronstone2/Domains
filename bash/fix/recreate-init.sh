#!/usr/bin/env bash
# fix/recreate-init.sh — recipe to recreate container with --init (FIXES ZOMBIES)
#
# NEVER auto-applies — losing run-flags is worse than zombies. Always prints
# the recipe; user copies + runs after adding back any extra docker-run flags.
#
# Usage:   fix/recreate-init.sh <container>
# Example: fix/recreate-init.sh staff-tls

set +e

c="$1"
section() { echo ""; echo "=== $* ==="; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] && { echo "usage: $0 <container>" >&2; exit 2; }

img=$(docker inspect "$c" --format '{{.Config.Image}}' 2>/dev/null)
cmd=$(docker inspect "$c" --format '{{join .Config.Cmd " "}}' 2>/dev/null)
# NOTE: port extraction grabs first binding per port — review if container has multiple bindings
ports=$(docker inspect "$c" --format '{{range $p, $v := .NetworkSettings.Ports}}-p {{(index $v 0).HostPort}}:{{$p}} {{end}}' 2>/dev/null)
mounts=$(docker inspect "$c" --format '{{range .Mounts}}-v {{.Source}}:{{.Destination}} {{end}}' 2>/dev/null)

section "FIX: recreate '$c' with --init flag (PID 1 zombie reaping)"
echo "Strategy: tini becomes PID 1 inside container, reaps exited children correctly."
echo ""
echo "Image:  $img"
echo "Cmd:    $cmd"
echo "Ports:  $ports"
echo "Mounts: $mounts"
echo ""

section "RECIPE — copy, add back any extra flags from your scenario script, run manually"
echo "  docker stop $c && docker rm $c"
echo "  docker run -d --init --name $c $ports $mounts $img $cmd"
echo ""
echo "  (this script INTENTIONALLY does not auto-apply — losing run-flags is worse than zombies)"

section "PERMANENT FIX"
echo "  docker-compose: add 'init: true' under the service"
echo "  k8s: pods get init by default in modern k8s; otherwise use shareProcessNamespace + sidecar"

section "VERIFY (after manual recreate)"
echo "  docker exec $c ps -p 1 -o cmd  # should show 'tini' or '/sbin/docker-init'"
echo "  docker exec $c sh -c 'ps -eo state | awk \"\\\$1==\\\"Z\\\"\" | wc -l'  # should be 0"
