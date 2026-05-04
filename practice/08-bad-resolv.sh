#!/usr/bin/env bash
# Scenario: Container's DNS resolution is broken. ping IP works, ping name doesn't.
# Symptom:  nslookup fails, but routing is fine.
# Suggested:`ha "container DNS not resolving"`
# Restore:  docker rm -f the container

set -uo pipefail
NAME="domains-practice-bad-dns"

start() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[08-bad-resolv] needs docker"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[08-bad-resolv] docker daemon unreachable"
    exit 1
  fi

  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # Inject a deliberately broken /etc/resolv.conf via volume mount.
  # 192.0.2.X is the documentation/test range — guaranteed unreachable.
  local tmpfile="/tmp/domains-practice-08-resolv.conf"
  echo "nameserver 192.0.2.53" > "$tmpfile"

  docker run -d --name "$NAME" \
    -v "$tmpfile":/etc/resolv.conf:ro \
    alpine sh -c 'while true; do sleep 30; done' >/dev/null

  cat <<EOF

Scenario:  Container "$NAME" has internet routing but DNS lookups time out.
           \`ping 8.8.8.8\` works; \`ping google.com\` fails. Figure out what's
           wrong with name resolution.

What's true: The container's /etc/resolv.conf points to an unreachable nameserver
             (in the test/documentation IP range 192.0.2.0/24).

Try:       \`pnpm harness ask "container DNS not resolving"\`
           \`docker exec $NAME ping -c 2 8.8.8.8\`           # routing works
           \`docker exec $NAME nslookup google.com\`         # DNS fails
           \`docker exec $NAME cat /etc/resolv.conf\`        # the smoking gun
           \`docker exec $NAME getent hosts google.com\`     # nsswitch path
           \`docker inspect $NAME --format '{{json .HostConfig.Dns}}'\`
           \`docker inspect $NAME --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{end}}'\`

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -f "/tmp/domains-practice-08-resolv.conf"
  echo "[08-bad-resolv] cleaned"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[08-bad-resolv] container $NAME still exists. Run: $0 restore"
    return 1
  else
    echo "[08-bad-resolv] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[08-bad-resolv] reveal:

  Failure mode id:    docker.fm.dns-not-resolving-from-container
                      docker.fm.embedded-dns-misroute (if docker DNS proxy involved)
  Why it happens:     /etc/resolv.conf points at an unreachable nameserver.
                      In this case the file is volume-mounted from the host so
                      docker's normal DNS injection is bypassed.
  Diagnostic order:
    1. ping 8.8.8.8                  → confirms routing/egress is fine
    2. ping google.com               → fails differently (name resolution)
    3. nslookup google.com           → "no servers could be reached" / timeout
    4. cat /etc/resolv.conf          → 192.0.2.53 (test range, never works)
    5. inspect mounts                → /etc/resolv.conf is bind-mounted from host
    6. test the nameserver           → curl -m 2 53/udp on 192.0.2.53 → timeout
  Fix paths:
    (A) Remove the bad mount:        docker rm + re-run without -v on /etc/resolv.conf
    (B) Pass --dns explicitly:       docker run --dns 8.8.8.8 ...
    (C) If using docker-compose:     `dns:` key in service definition
    (D) For systemd-resolved hosts:  may need --dns 127.0.0.11 (docker's embedded DNS)
  Trade-off:          --dns flag overrides for ALL lookups in the container.
                      Sometimes you want only ONE nameserver overridden — for
                      that, use a custom resolv.conf with multiple nameserver lines.
  Production note:    In k8s, this is the dnsConfig field on the pod spec.

  Reference: pnpm harness ask "container DNS not resolving" or "DNS slow"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
