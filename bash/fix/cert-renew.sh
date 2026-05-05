#!/usr/bin/env bash
# fix/cert-renew.sh — generate new self-signed cert (TEST USE ONLY)
#
# Default: dry-run. Add --apply to execute.
# WARNING: self-signed only — production must use proper CA / cert-manager / ACME.
#
# Usage:   fix/cert-renew.sh <container> <hostname> [days=365] [--apply]
# Example: fix/cert-renew.sh staff-tls metrics.corp.internal 365 --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; name="$2"; days="${3:-365}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$name" ] && { echo "usage: $0 <container> <hostname> [days=365] [--apply]" >&2; exit 2; }

section "TEMP FIX: self-signed cert for '$name' valid $days days (TEST ONLY)"
run "docker exec $c sh -c 'mkdir -p /etc/ssl/custom && openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/ssl/custom/$name.key -out /etc/ssl/custom/$name.crt -days $days -subj \"/CN=$name\"'"

section "PERMANENT FIX"
echo "  Use cert-manager (k8s) / ACME (Let's Encrypt) / your internal CA pipeline."
echo "  Audit issuance: check for '-days 0' bug if certs come out zero-day."
echo "  Automate renewal via cron / k8s CronJob — never wait for production cert to expire."

section "VERIFY"
echo "  docker exec $c sh -c 'openssl x509 -in /etc/ssl/custom/$name.crt -noout -dates'"
echo "  docker exec $c sh -c 'openssl x509 -in /etc/ssl/custom/$name.crt -noout -subject'"

$APPLY || echo "(dry-run; pass --apply to execute)"
