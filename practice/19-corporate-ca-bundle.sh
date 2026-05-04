#!/usr/bin/env bash
# Scenario: Corporate proxy (Zscaler/Netskope/PaloAlto) MITMs all outbound
#           HTTPS with the org's own CA. Devin can't curl/npm/pip/git anywhere
#           on first run — every tool returns x509 unknown-authority because
#           the org CA isn't in the standard trust bundle.
#           This is THE most common Devin onboarding cert issue.
# Symptom:  npm install / pip install / curl / git clone all fail with
#           "unable to get local issuer certificate" or "self-signed
#           certificate in certificate chain"
# Suggested: ha "corporate CA proxy MITM cert install"
# Restore:  remove the staged cert + the per-tool config

set -uo pipefail
DIR="/tmp/domains-practice/19-corp-ca"
SERVERPID="$DIR/server.pid"
PORT=18444
CORP_CA_CN="ACME-Corp-Root-CA"

start() {
  command -v openssl >/dev/null 2>&1 || { echo "[19] needs openssl"; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "[19] needs python3"; exit 1; }
  mkdir -p "$DIR"

  if [[ -f "$SERVERPID" ]] && kill -0 "$(cat "$SERVERPID")" 2>/dev/null; then
    echo "[19] already running"
  else
    # Step 1: generate a fake "corporate root CA"
    openssl req -x509 -newkey rsa:2048 -keyout "$DIR/corp-ca.key" -out "$DIR/corp-ca.crt" \
      -days 365 -nodes -subj "/CN=$CORP_CA_CN" 2>/dev/null

    # Step 2: generate a server cert SIGNED by that corp CA
    openssl req -newkey rsa:2048 -keyout "$DIR/srv.key" -out "$DIR/srv.csr" \
      -nodes -subj "/CN=localhost" 2>/dev/null
    openssl x509 -req -in "$DIR/srv.csr" -CA "$DIR/corp-ca.crt" -CAkey "$DIR/corp-ca.key" \
      -CAcreateserial -out "$DIR/srv.crt" -days 365 \
      -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1") 2>/dev/null

    # Step 3: serve HTTPS using that server cert (chain = leaf only)
    setsid python3 -c "
import http.server, ssl
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('$DIR/srv.crt', '$DIR/srv.key')
srv = http.server.HTTPServer(('127.0.0.1', $PORT), http.server.SimpleHTTPRequestHandler)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$SERVERPID"
    sleep 0.7
  fi

  cat <<EOF

Scenario:  You're working in a Devin DevBox at \$BIG_CORP. Every outbound
           HTTPS connection (npm install, pip install, docker pull, git clone)
           fails with x509 / unknown-authority. The corporate proxy MITMs
           all HTTPS and re-signs with "$CORP_CA_CN" — a CA that isn't in
           any standard trust bundle. You can't proceed until that CA is
           trusted by EVERY tool you'll use.

           Find:
           1. Which CA the proxy is presenting (the issuer string)
           2. Which tools need separate trust-store install
           3. The right install path for system + npm + pip + docker + git

What's true: A real proxy isn't running, but $DIR/corp-ca.crt is a fake
             corporate root CA. $DIR/srv.crt is a leaf signed by it. The
             local HTTPS server at https://localhost:$PORT/ presents the
             leaf only (no chain), and the leaf's issuer is "$CORP_CA_CN".

Try:       pnpm harness ask "corporate CA proxy MITM install everywhere"

  # 1. Reproduce: curl fails because $CORP_CA_CN isn't trusted
  curl -v https://localhost:$PORT/ 2>&1 | grep -iE 'ssl|cert|verify' | head

  # 2. Identify the unknown CA
  echo | openssl s_client -connect localhost:$PORT 2>/dev/null \\
    | openssl x509 -noout -issuer -subject

  # 3. Confirm it's not in the system trust bundle
  awk -v cn="$CORP_CA_CN" '/-----BEGIN/{c=""} /Subject:/{c=\$0} /-----END/{if(c~cn)print c}' \\
    /etc/ssl/certs/ca-certificates.crt 2>/dev/null

  # 4. (Per-tool fixes — read README under reveal for the full matrix)
  # System (Debian/Ubuntu):
  sudo cp $DIR/corp-ca.crt /usr/local/share/ca-certificates/$CORP_CA_CN.crt
  sudo update-ca-certificates       # writes /etc/ssl/certs/ca-certificates.crt
  curl https://localhost:$PORT/    # should now succeed

  # Per-tool overrides (each tool ships its own trust store):
  export NODE_EXTRA_CA_CERTS=$DIR/corp-ca.crt   # node, npm
  export REQUESTS_CA_BUNDLE=$DIR/corp-ca.crt    # python requests
  export SSL_CERT_FILE=$DIR/corp-ca.crt         # most other python (urllib3)
  git config --global http.sslCAInfo $DIR/corp-ca.crt   # git
  # docker (per-registry; see scenario 20 for full daemon config)

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
  # Note: we don't auto-undo any system trust changes the user made — that
  # would silently revert their fix. They can manually:
  #   sudo rm /usr/local/share/ca-certificates/$CORP_CA_CN.crt && sudo update-ca-certificates --fresh
  rm -rf "$DIR"
  echo "[19] cleaned (NOTE: any system trust-store changes you made aren't auto-reverted)"
}

verify() {
  if [[ -f "$SERVERPID" ]] && kill -0 "$(cat "$SERVERPID")" 2>/dev/null; then
    echo "[19] server still running. Run: $0 restore"
    return 1
  else
    echo "[19] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[19-corporate-ca-bundle] reveal:

  Failure mode id:    devin.fm.internal-svc-cert-untrusted +
                      linux.fm.tls-cert-corporate-ca-not-installed
                      (this is the most common Devin onboarding cert issue —
                       the corporate proxy intercepts HTTPS and re-signs with
                       the org's own CA, which isn't in any default trust
                       bundle. Until you install it everywhere, every tool
                       fails.)
  Why it happens:     Corporate firewalls (Zscaler, Netskope, Palo Alto, Fortinet)
                      MITM HTTPS for inspection. They generate a per-org CA,
                      install it on managed laptops, and re-sign every outbound
                      cert. Devin runs in a VPC environment that lives behind
                      the same proxy — so the same CA must be installed in
                      every tool's trust store.

  Per-tool trust store matrix (CRITICAL — every tool has its own):

    | Tool          | Trust store path                                       | Update mechanism                      |
    |---------------|--------------------------------------------------------|---------------------------------------|
    | curl/wget     | /etc/ssl/certs/ca-certificates.crt (system bundle)     | sudo update-ca-certificates           |
    | OpenSSL CLI   | same as system                                          | same                                  |
    | git           | system bundle, OR http.sslCAInfo override               | git config --global http.sslCAInfo    |
    | node / npm    | NODE_EXTRA_CA_CERTS env, OR npm config set cafile       | export NODE_EXTRA_CA_CERTS=/path.crt  |
    | python requests| REQUESTS_CA_BUNDLE env, OR system bundle               | export REQUESTS_CA_BUNDLE=/path.crt   |
    | python urllib3 | SSL_CERT_FILE env                                       | export SSL_CERT_FILE=/path.crt        |
    | python certifi | bundled in pip package — replace with patched bundle    | pip install --upgrade certifi-corp    |
    | java/jdk      | $JAVA_HOME/lib/security/cacerts (JKS keystore)           | keytool -import -keystore -file       |
    | docker        | /etc/docker/certs.d/<registry-host>/ca.crt              | restart docker or push reload         |
    | go            | system bundle, OR SSL_CERT_FILE                         | export SSL_CERT_FILE=/path.crt        |
    | aws-cli       | system bundle, OR AWS_CA_BUNDLE                         | export AWS_CA_BUNDLE=/path.crt        |
    | kubectl       | system bundle, OR --certificate-authority flag           | system install                        |
    | helm          | system bundle                                           | system install                        |

  System install (Debian/Ubuntu — covers curl, git, openssl, most others):
    sudo cp corp-root-ca.crt /usr/local/share/ca-certificates/Acme-Corp-Root.crt
    sudo update-ca-certificates
    # writes /etc/ssl/certs/ca-certificates.crt; effective immediately for
    # tools that read the system bundle.

  System install (RHEL/Fedora):
    sudo cp corp-root-ca.crt /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust extract

  Per-session env-var fix (works for one shell only, no system change):
    export NODE_EXTRA_CA_CERTS=/path/corp-ca.crt
    export REQUESTS_CA_BUNDLE=/path/corp-ca.crt
    export SSL_CERT_FILE=/path/corp-ca.crt
    export GIT_SSL_CAINFO=/path/corp-ca.crt
    export AWS_CA_BUNDLE=/path/corp-ca.crt

  Diagnostic flow:
    1. curl -v https://anything                  → reproduce
    2. openssl s_client -connect host:443        → see issuer
       (issuer being your org name confirms MITM proxy)
    3. Check system bundle: awk on ca-certificates.crt for the issuer CN
    4. If absent: install per matrix above; retest with curl
    5. If still failing: check the SPECIFIC TOOL's trust store path

  Common gotchas:
    - npm config set cafile + NODE_EXTRA_CA_CERTS BOTH need to be set in
      some npm versions for child processes
    - docker daemon doesn't read system trust bundle — it has its own path
      under /etc/docker/certs.d/<host>/ca.crt (per-registry, NOT global)
    - python certifi bundles its OWN list, ignores system. Use REQUESTS_CA_BUNDLE
      to override.
    - java keystore format is JKS or PKCS12 — can't just drop a .crt in.
      Use keytool -import.

  Distribution mechanism (production answer):
    1. Bake the CA into your base image at build time (Dockerfile COPY +
       update-ca-certificates).
    2. For Devin specifically: ask the platform team for a "Devin DevBox
       base image" that already includes the corp CA — this is a one-time
       org-level fix, not per-session.
    3. For dev who can't wait: bash one-liner that exports all the env vars,
       call it from .bashrc / .zshrc.

  Reference: pnpm harness playbook devin.fm.internal-svc-cert-untrusted
             pnpm harness ask "corporate CA install all tools"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
