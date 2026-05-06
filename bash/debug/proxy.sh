#!/usr/bin/env bash
# debug/proxy.sh — diagnose corporate proxy / HTTP_PROXY issues
#
# Reads: env vars, curl tests, pip/npm/git proxy config, CA trust stores
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/proxy.sh [container]
# Example: debug/proxy.sh staff-tls
#          debug/proxy.sh              # host-wide

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Proxy environment variables"
for v in HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy ALL_PROXY all_proxy; do
  val=$(in_c "printenv $v 2>/dev/null")
  [ -n "$val" ] && echo "  $v=$val" || echo "  $v=(unset)"
done

section "TLS trust store env vars"
for v in NODE_EXTRA_CA_CERTS REQUESTS_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE; do
  val=$(in_c "printenv $v 2>/dev/null")
  [ -n "$val" ] && echo "  $v=$val (exists=$(in_c "test -e $val && echo yes || echo NO"))" || echo "  $v=(unset)"
done

section "Direct connectivity test (bypassing proxy)"
echo "  Testing direct HTTPS to pypi.org..."
in_c "curl -sS --connect-timeout 5 -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' https://pypi.org/simple/" 2>&1 || echo "  FAILED (no direct access)"

section "Proxy connectivity test"
proxy=$(in_c "printenv HTTPS_PROXY || printenv https_proxy || printenv HTTP_PROXY || printenv http_proxy" 2>/dev/null)
if [ -n "$proxy" ]; then
  echo "  Testing via proxy $proxy..."
  in_c "curl -sS --proxy '$proxy' --connect-timeout 5 -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' https://pypi.org/simple/" 2>&1 || echo "  FAILED via proxy"
else
  echo "  (no proxy configured — skipping)"
fi

section "npm proxy config"
in_c "npm config get proxy 2>/dev/null; npm config get https-proxy 2>/dev/null; npm config get cafile 2>/dev/null; npm config get strict-ssl 2>/dev/null" 2>&1

section "pip proxy config"
in_c "pip config list 2>/dev/null | grep -iE 'proxy|cert|trusted' || echo '(no pip proxy config)'" 2>&1

section "git proxy config"
in_c "git config --global --get http.proxy 2>/dev/null || echo '(none)'; git config --global --get http.sslCAInfo 2>/dev/null || echo '(none)'" 2>&1

section "Docker daemon proxy"
cat /etc/systemd/system/docker.service.d/http-proxy.conf 2>/dev/null || echo "(no docker proxy override)"

section "MITM / proxy cert check"
echo "  Checking if pypi.org cert issuer looks like a corp proxy..."
in_c "echo | openssl s_client -connect pypi.org:443 2>/dev/null | openssl x509 -noout -issuer" 2>&1
echo "  (If issuer is Zscaler/Netskope/Symantec/Forcepoint → corp proxy intercepting TLS)"

section "HINTS"
echo "• Corp proxy TLS interception: need proxy's CA cert in ALL trust stores (system, node, pip, git, docker)"
echo "• npm behind proxy: npm config set proxy http://proxy:port && npm config set https-proxy http://proxy:port"
echo "• pip behind proxy: pip install --proxy http://proxy:port OR pip config set global.proxy http://proxy:port"
echo "• git behind proxy: git config --global http.proxy http://proxy:port"
echo "• NO_PROXY must include internal hostnames (comma-separated, no spaces)"
echo "• If proxy requires auth: http://user:pass@proxy:port (URL-encode special chars)"
