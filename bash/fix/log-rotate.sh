#!/usr/bin/env bash
# fix/log-rotate.sh — fix container log rotation (truncate now + set limits)
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/log-rotate.sh <container> [--apply]
#          fix/log-rotate.sh --daemon [--apply]     # set daemon-wide defaults
# Example: fix/log-rotate.sh staff-tls --apply
#          fix/log-rotate.sh --daemon --apply

set +e

APPLY=false
DAEMON=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; --daemon) DAEMON=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

c="$1"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

if $DAEMON; then
  section "Set daemon-wide log rotation defaults"
  echo "  Writing /etc/docker/daemon.json with log rotation..."
  run 'sudo python3 -c "
import json, os
p = \"/etc/docker/daemon.json\"
cfg = {}
if os.path.exists(p):
  with open(p) as f: cfg = json.load(f)
cfg[\"log-driver\"] = \"json-file\"
cfg.setdefault(\"log-opts\", {})
cfg[\"log-opts\"][\"max-size\"] = \"10m\"
cfg[\"log-opts\"][\"max-file\"] = \"3\"
with open(p, \"w\") as f: json.dump(cfg, f, indent=2)
print(\"  wrote:\", json.dumps(cfg, indent=2))
"'

  section "Restart Docker daemon to apply"
  run "sudo systemctl restart docker"
  echo "  NOTE: new defaults apply to NEW containers only. Existing containers keep old config."
  echo "  To apply to existing: recreate them (docker compose up -d --force-recreate)"
else
  [ -z "$c" ] && { echo "usage: $0 <container> [--apply] OR $0 --daemon [--apply]" >&2; exit 2; }

  section "Current log size for: $c"
  logpath=$(docker inspect "$c" --format '{{.LogPath}}' 2>/dev/null)
  if [ -n "$logpath" ] && [ -f "$logpath" ]; then
    ls -lh "$logpath" | awk '{print "  Size: "$5, "Path:", $NF}'
  else
    echo "  (no log file found)"
  fi

  section "Truncate log NOW (immediate relief)"
  if [ -n "$logpath" ]; then
    run "sudo truncate -s 0 '$logpath'"
  fi

  section "PERMANENT FIX: recreate container with log limits"
  echo "  docker run --log-opt max-size=10m --log-opt max-file=3 ..."
  echo ""
  echo "  Or in docker-compose.yml:"
  echo "    services:"
  echo "      $c:"
  echo "        logging:"
  echo "          driver: json-file"
  echo "          options:"
  echo "            max-size: \"10m\""
  echo "            max-file: \"3\""
fi

section "VERIFY"
[ -n "$logpath" ] && echo "  ls -lh $logpath" && $APPLY && ls -lh "$logpath" 2>/dev/null
echo "  docker inspect $c --format '{{.HostConfig.LogConfig}}'"

$APPLY || echo "(dry-run; pass --apply to execute)"
