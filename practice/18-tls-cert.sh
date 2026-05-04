#!/usr/bin/env bash
# Scenario: curl to an internal HTTPS service fails with x509 / certificate
#           error. Multiple causes look similar — expired cert, missing CA,
#           hostname mismatch, mTLS missing client cert. Distinguish them.
# Symptom:  "x509: certificate signed by unknown authority" / "certificate
#           has expired" / "certificate is not valid for ..."
# Suggested: ha "TLS certificate error curl"
# Restore:  remove staged certs

set -uo pipefail
DIR="/tmp/domains-practice/18-tls"
SERVERPID="$DIR/server.pid"
PORT=18443

start() {
  command -v openssl >/dev/null 2>&1 || { echo "[18] needs openssl"; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "[18] needs python3"; exit 1; }
  mkdir -p "$DIR"

  if [[ -f "$SERVERPID" ]] && kill -0 "$(cat "$SERVERPID")" 2>/dev/null; then
    echo "[18] server already running"
  else
    # Generate a self-signed cert (= "unknown authority" by default, since
    # the system CA bundle doesn't include it). CN is "wrong-hostname" so
    # any other hostname triggers a hostname-mismatch error too.
    openssl req -x509 -newkey rsa:2048 -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
      -days 365 -nodes -subj "/CN=wrong-hostname.example.com" 2>/dev/null

    # Run a tiny TLS server. python -m http.server doesn't do TLS; use a
    # 4-line python that wraps the socket.
    setsid python3 -c "
import http.server, ssl, sys
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('$DIR/cert.pem', '$DIR/key.pem')
srv = http.server.HTTPServer(('127.0.0.1', $PORT), http.server.SimpleHTTPRequestHandler)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$SERVERPID"
    sleep 0.7
  fi

  cat <<EOF

Scenario:  Your app needs to talk to https://localhost:$PORT/ but curl fails:
             "curl: (60) SSL certificate problem: ..." or
             "x509: certificate signed by unknown authority"

           Three things could be wrong, all show similar errors:
             (a) Cert is signed by a CA your trust bundle doesn't include
             (b) Cert's CN/SAN doesn't match the hostname you used
             (c) Cert is expired

           You need to distinguish them with diagnostic commands and
           then propose the right fix per cause.

What's true: The server cert is self-signed (no public CA), CN is
             "wrong-hostname.example.com", expires in 365 days. So the
             real issues here are: (a) unknown CA, (b) hostname mismatch
             when connecting via "localhost". Date is fine.

Try:       pnpm harness ask "TLS certificate error"

  # 1. Reproduce the exact error
  curl -v https://localhost:$PORT/ 2>&1 | grep -iE 'ssl|cert|verify' | head -10

  # 2. See the raw cert the server presents (no verification — diagnostic only)
  echo | openssl s_client -connect localhost:$PORT -servername localhost 2>/dev/null \\
    | openssl x509 -text -noout | head -30

  # 3. Pull cert details: subject, issuer, dates, SANs
  echo | openssl s_client -connect localhost:$PORT 2>/dev/null \\
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName

  # 4. Distinguish the failure mode:
  #    (a) Unknown CA       → curl with --cacert tests it
  #    (b) Hostname mismatch → curl with --resolve tests it
  #    (c) Expired           → openssl x509 -checkend 0 returns non-zero
  curl --cacert $DIR/cert.pem https://localhost:$PORT/    # tries (a)
  curl --resolve wrong-hostname.example.com:$PORT:127.0.0.1 \\
       --cacert $DIR/cert.pem https://wrong-hostname.example.com:$PORT/  # tries (a)+(b)
  openssl x509 -in $DIR/cert.pem -checkend 0 && echo "not expired" || echo "expired"

  # 5. System CA bundle inspection (where curl looks for trusted CAs)
  curl-config --ca 2>/dev/null
  ls /etc/ssl/certs/ | head -5
  awk -v cmd='openssl x509 -noout -subject' '/-----BEGIN/{close(cmd)}; {print | cmd}' \\
    /etc/ssl/certs/ca-certificates.crt 2>/dev/null | head -5

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$SERVERPID" ]]; then
    kill "$(cat "$SERVERPID")" 2>/dev/null || true
    sleep 0.3
    kill -9 "$(cat "$SERVERPID")" 2>/dev/null || true
    rm -f "$SERVERPID"
  fi
  rm -rf "$DIR"
  echo "[18] cleaned"
}

verify() {
  if [[ -f "$SERVERPID" ]] && kill -0 "$(cat "$SERVERPID")" 2>/dev/null; then
    echo "[18] server still running. Run: $0 restore"
    return 1
  else
    echo "[18] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[18-tls-cert] reveal:

  Failure mode id:    linux.fm.tls-cert-verification-failed
                      (a family with subtypes: unknown-ca, hostname-mismatch,
                       expired, mtls-client-cert-missing, intermediate-missing,
                       sni-mismatch)
  Why each subtype happens + how to detect:

    (a) UNKNOWN CA / SELF-SIGNED:
        Error:   "x509: certificate signed by unknown authority"
                 "SSL certificate problem: unable to get local issuer certificate"
        Detect:  echo | openssl s_client -connect host:port  shows issuer; if
                 issuer == subject, cert is self-signed. Otherwise check whether
                 the issuer CA exists in /etc/ssl/certs/ca-certificates.crt
                 (Debian/Ubuntu) or /etc/pki/tls/certs/ca-bundle.crt (RHEL).
        Fix:     curl --cacert /path/to/issuer.crt   (one-off)
                 sudo cp issuer.crt /usr/local/share/ca-certificates/ \
                   && sudo update-ca-certificates  (system-wide)
                 For language SDKs: SSL_CERT_FILE env var, or
                 NODE_EXTRA_CA_CERTS for node, REQUESTS_CA_BUNDLE for python

    (b) HOSTNAME MISMATCH:
        Error:   "certificate is not valid for any name given"
                 "subjectAltName does not match"
        Detect:  cert subject CN or SAN doesn't include the hostname you
                 connect via. openssl x509 -ext subjectAltName shows what's
                 covered. Most modern code REQUIRES SAN — CN-only certs are
                 rejected on newer libraries.
        Fix:     reissue cert with correct SANs:
                   openssl req -addext "subjectAltName=DNS:host1,DNS:host2,IP:1.2.3.4"
                 Or: connect via the right hostname (--resolve in curl).
                 For internal LB: make sure cert has SAN for both LB hostname
                 AND backend service name.

    (c) EXPIRED:
        Error:   "certificate has expired"
                 "x509: certificate has expired or is not yet valid"
        Detect:  openssl x509 -in cert.pem -checkend 0   (exit 1 = expired)
                 openssl x509 -in cert.pem -dates  shows notBefore / notAfter
        Fix:     reissue cert; restart the service. Long-term: cert-manager
                 / acme-client / Let's Encrypt automation.

    (d) MISSING INTERMEDIATE:
        Error:   "unable to verify the first certificate"
                 (passes some clients, fails others)
        Detect:  openssl s_client -showcerts  — chain has only leaf, no
                 intermediate. Browsers cache intermediates from past visits;
                 curl/openssl don't.
        Fix:     server config must serve full chain (leaf + intermediates).
                 nginx: ssl_certificate fullchain.pem;
                 caddy: handles automatically; envoy: tls_certificate_chain

    (e) mTLS — CLIENT CERT MISSING / WRONG:
        Error:   "tls: bad certificate" / "alert handshake failure"
                 (server rejects client during handshake)
        Detect:  curl -v shows "alert handshake failure" or
                 "alert certificate required". openssl s_client --cert / --key
                 succeeds with the right pair.
        Fix:     curl --cert client.crt --key client.key
                 Or for SDKs: configure client cert in the HTTP client.

  Diagnostic order (use this verbatim in interview):
    1. curl -v <url>            → reproduce; read the error line
    2. openssl s_client -connect host:port -servername host  → see the cert
    3. openssl x509 -noout -dates -subject -issuer -ext subjectAltName
                                  → all the things at once
    4. Cross-check: does the local CA bundle have the issuer? Is the
       hostname in the SANs? Is notAfter in the future?
    5. The error message + the data above name the subtype.

  Trade-off:          --insecure / -k disables verification. NEVER use this
                      in a "fix" — it's only for diagnostic. Real fix is
                      always one of the categories above.

  Reference: pnpm harness playbook linux.fm.tls-cert-verification-failed
             pnpm harness ask "TLS certificate error"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
