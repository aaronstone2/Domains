#!/usr/bin/env bash
# Scenario: docker pull from a private registry behind a self-signed cert
#           or org-CA-signed cert. docker daemon doesn't read the system
#           trust bundle — it needs its own per-registry config under
#           /etc/docker/certs.d/<host:port>/ca.crt.
# Symptom:  "x509: certificate signed by unknown authority" from `docker pull`
#           even after you fixed it for curl/git/npm system-wide.
# Suggested: ha "docker pull cert error private registry"
# Restore:  stop the registry container

set -uo pipefail
DIR="/tmp/domains-practice/20-reg"
NAME="domains-practice-private-reg"
PORT=15000
HOST="localhost:${PORT}"

start() {
  command -v docker >/dev/null 2>&1 || { echo "[20] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[20] docker daemon unreachable"; exit 1; }
  command -v openssl >/dev/null 2>&1 || { echo "[20] needs openssl"; exit 1; }
  mkdir -p "$DIR"
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # Generate a self-signed cert for the registry (CN=localhost, SAN=localhost)
  openssl req -x509 -newkey rsa:2048 -keyout "$DIR/reg.key" -out "$DIR/reg.crt" \
    -days 365 -nodes -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null

  # Run a private registry behind that cert
  docker run -d --name "$NAME" \
    -p $PORT:5000 \
    -v "$DIR/reg.crt:/certs/cert.crt:ro" \
    -v "$DIR/reg.key:/certs/cert.key:ro" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/cert.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/cert.key \
    registry:2 >/dev/null

  echo "[20] private registry up at https://$HOST"
  sleep 2

  cat <<EOF

Scenario:  You stood up an internal docker registry at $HOST. It uses a
           self-signed (or org-CA-signed) cert. \`docker pull\` from it
           fails with "x509: certificate signed by unknown authority"
           — even on a box where you ALREADY installed the CA in the
           system trust store and curl works fine to the same host.

           The catch: dockerd doesn't read /etc/ssl/certs. It has its
           own per-registry trust path. Find it; install the cert there;
           reload.

           Find:
           1. Confirm the failure mode (it really IS dockerd not trusting it)
           2. Where dockerd looks for per-registry CAs
           3. The right install (cert.d path) + how to reload without restart

What's true: $HOST is serving a self-signed cert. dockerd has not been told
             to trust it. \`docker pull $HOST/test\` will fail with x509.

Try:       pnpm harness ask "docker pull self-signed cert error"

  # 1. Reproduce
  docker pull $HOST/nonexistent-image 2>&1 | head

  # 2. Confirm curl ALSO fails (or already passes if you ran scenario 19)
  curl -v https://$HOST/v2/ 2>&1 | grep -iE 'ssl|cert|verify' | head

  # 3. See what cert the registry presents
  echo | openssl s_client -connect $HOST 2>/dev/null \\
    | openssl x509 -noout -issuer -subject -dates -ext subjectAltName

  # 4. The fix: install cert under /etc/docker/certs.d/<host:port>/ca.crt
  sudo mkdir -p /etc/docker/certs.d/$HOST
  sudo cp $DIR/reg.crt /etc/docker/certs.d/$HOST/ca.crt
  # NOTE: directory name MUST exactly match the registry's host:port as
  # used in image refs. If you pull "registry.acme.com/img" → directory
  # is /etc/docker/certs.d/registry.acme.com. With non-default port,
  # include it: /etc/docker/certs.d/registry.acme.com:5000/

  # 5. Reload — modern dockerd picks up cert.d on next pull, no restart needed
  docker pull $HOST/nonexistent-image 2>&1 | head -3
  # The error should now be 404/manifest-not-found, NOT a cert error
  # → that means the cert chain validated; image just doesn't exist (expected)

  # 6. Compare alternatives:
  # (a) /etc/docker/certs.d/<host>/ca.crt    ← THE RIGHT WAY
  # (b) Add to insecure-registries           ← skips ALL TLS validation; bad
  # (c) Set "insecure": true on this registry in daemon.json + restart docker

Reveal:    $0 reveal
Restore:   $0 restore (stops registry; doesn't auto-remove /etc/docker/certs.d/...)
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$DIR"
  # Don't silently undo /etc/docker/certs.d changes the user made
  echo "[20] cleaned (NOTE: if you installed /etc/docker/certs.d/$HOST/ca.crt,"
  echo "                  remove it manually: sudo rm -rf /etc/docker/certs.d/$HOST)"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[20] registry container $NAME still up. Run: $0 restore"
    return 1
  else
    echo "[20] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[20-private-registry-cert] reveal:

  Failure mode id:    docker.fm.private-registry-cert-not-trusted
                      (the dockerd-specific subtype of cert-untrusted —
                       distinct from system trust because dockerd has its
                       OWN trust store, /etc/docker/certs.d/, that's
                       independent of the OS bundle.)
  Why it happens:     dockerd is statically linked + sandboxed; it doesn't
                      use the OS's libssl trust bundle by default. Per-registry
                      certs go under /etc/docker/certs.d/<host>[:<port>]/.
                      The PORT is part of the directory name when non-443.

  Diagnostic flow:
    1. docker pull <registry>/img    → reproduces with x509 error
    2. curl -v https://<registry>/v2/ → confirms cert is/isn't trusted at OS
                                          level. If curl succeeds but docker
                                          fails, you've found the dockerd-
                                          specific issue. If curl ALSO fails,
                                          fix the system bundle FIRST (scen 19).
    3. openssl s_client -connect <reg> → see what cert is being served
    4. ls /etc/docker/certs.d/<host[:port]>/ → does dockerd already have a
                                                  ca.crt for this host?
    5. journalctl -u docker -n 50    → dockerd logs the verification failure
                                          with details (verify-error: ...)

  Three fix paths (descending order of correctness):

  (A) Install the CA cert per-registry [RIGHT]:
      sudo mkdir -p /etc/docker/certs.d/<host[:port]>
      sudo cp ca.crt /etc/docker/certs.d/<host[:port]>/ca.crt
      docker pull ...     # picks up new ca.crt, no daemon restart needed
                          # (dockerd reads cert.d at pull time)

      For mTLS (registry requires CLIENT cert):
        Add client.cert + client.key in same dir; dockerd uses them
        automatically.

  (B) Insecure-registries (LAST RESORT — disables verification):
      Edit /etc/docker/daemon.json:
        { "insecure-registries": ["<host[:port]>"] }
      sudo systemctl restart docker
      → use ONLY for dev / lab / CI. Never production.

  (C) Use HTTP instead of HTTPS (almost never right):
      sudo systemctl set-environment ... ; sudo systemctl restart docker
      → registry must be served over HTTP; insecure-registries must include it

  Common gotchas:
    - PORT in the directory name must match. Pulling "host:5000/img" needs
      /etc/docker/certs.d/host:5000/ — not /etc/docker/certs.d/host/.
    - The CA file MUST be named ca.crt (not ca.pem, not myca.crt).
    - If you have an intermediate CA, concat root + intermediate INTO ca.crt:
        cat intermediate.crt root.crt > /etc/docker/certs.d/<host>/ca.crt
    - On macOS docker desktop: the dance is different (system keychain).
    - Buildkit / containerd: they have their OWN trust paths (containerd uses
      /etc/containerd/certs.d/<host>/hosts.toml). If `docker buildx build`
      can pull but `docker pull` can't (or vice versa), check both.

  Cross-stack:
    - k8s pulling from a private registry: it's the KUBELET that pulls, not
      docker. The CA must be on every node's containerd/cri-o trust path.
    - If using containerd directly (k8s 1.24+):
        /etc/containerd/certs.d/<host>/hosts.toml with
        [host."https://<host>"]
          ca = "/etc/containerd/certs.d/<host>/ca.crt"

  Reference: pnpm harness playbook docker.fm.private-registry-cert-not-trusted
             pnpm harness playbook docker.fm.private-pkg-pull-fail
             pnpm harness ask "docker pull cert error"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
