#!/usr/bin/env bash
# debug/tls.sh — diagnose TLS handshake + cert chain to a host:port
#
# Reads: openssl s_client output, container env vars (CA paths)
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/tls.sh [container] [host:port]
# Example: debug/tls.sh staff-tls auth.corp.internal:8443
#          debug/tls.sh '' registry.npmjs.org:443
#          debug/tls.sh staff-tls auth.corp.internal:8443 > notes/logs/$(date +%F-%H%M)-tls.log

set +e

c="${1:-}"; hp="${2:-localhost:443}"
host="${hp%:*}"; port="${hp##*:}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "TLS handshake to $hp"
in_c "echo | openssl s_client -connect $hp -servername $host 2>&1 | grep -E 'subject|issuer|verify|CN='"

section "Cert dates"
in_c "echo | openssl s_client -connect $hp 2>&1 | openssl x509 -noout -dates 2>/dev/null"

section "Cert chain (server-presented)"
in_c "echo | openssl s_client -connect $hp -showcerts 2>&1 | grep -E 'depth|verify|^ *[is]:'"

section "Container CA env vars"
in_c "env | grep -iE 'CA_|CERT|SSL'"

section "Trust store files"
in_c "ls -la /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt 2>/dev/null"

section "Date sanity (clock skew check)"
date -u
curl -sI https://www.google.com 2>/dev/null | grep -i ^date

section "Hint"
echo "UNABLE_TO_GET_ISSUER_CERT_LOCALLY  → CA bundle missing intermediate or wrong path"
echo "CERT_HAS_EXPIRED                   → cert dates are in the past or clock is off"
echo "SELF_SIGNED_CERT_IN_CHAIN          → trusted CA root missing from container"
echo "Node uses NODE_EXTRA_CA_CERTS; Python uses REQUESTS_CA_BUNDLE; curl uses --cacert"
