#!/usr/bin/env bash
# fix/cabundle.sh — concat root + intermediate CA → /etc/ssl/custom/full-chain.pem
#
# Default: dry-run. Add --apply to execute.
#
# Usage:   fix/cabundle.sh <container> <root.pem> <intermediate.pem> [--apply]
# Example: fix/cabundle.sh staff-tls /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac; done
set -- "${ARGS[@]}"

c="$1"; root="$2"; inter="$3"
out="/etc/ssl/custom/full-chain.pem"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,9p' "$0" | sed 's/^# *//'
  exit 0
fi
[ -z "$c" ] || [ -z "$root" ] || [ -z "$inter" ] && { echo "usage: $0 <container> <root.pem> <intermediate.pem> [--apply]" >&2; exit 2; }

section "TEMP FIX: concat $root + $inter → $out"
run "docker exec $c sh -c 'mkdir -p /etc/ssl/custom && cat $root $inter > $out'"
run "docker exec $c sh -c 'echo \"BEGIN-count: \$(grep -c \"BEGIN CERTIFICATE\" $out)\"'"

section "PERMANENT FIX"
echo "  Build the bundle at image-build time, ship as a single file:"
echo "    COPY full-chain.pem /etc/ssl/custom/full-chain.pem"
echo "    ENV NODE_EXTRA_CA_CERTS=/etc/ssl/custom/full-chain.pem"
echo "  For corp PKI: run 'update-ca-certificates' in Dockerfile to add to system trust"

section "NEXT STEP — point Node at the bundle"
echo "  bash/fix/env.sh $c NODE_EXTRA_CA_CERTS $out --apply"

section "VERIFY"
echo "  docker exec $c sh -c 'grep -c BEGIN $out'  # should be 2"
echo "  docker exec $c sh -c 'openssl verify -CAfile $out $out'"

$APPLY || echo "(dry-run; pass --apply to execute)"
