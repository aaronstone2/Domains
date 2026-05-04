#!/usr/bin/env bash
# Scenario: A container can't reach the internet. curl/ping hang or fail.
# Symptom:  `docker run ... curl google.com` hangs forever or returns "could not resolve".
# Suggested:`ha "container can't reach internet"` or `ha "container no egress"`
# Restore:  docker rm -f, restore network

set -uo pipefail
NAME="domains-practice-no-egress"
NETWORK="domains-practice-isolated"

start() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[07-docker-no-egress] needs docker"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[07-docker-no-egress] docker daemon unreachable"
    exit 1
  fi

  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true

  # Create an isolated bridge network with no internet access.
  # Internal=true means no external connectivity.
  docker network create --internal "$NETWORK" >/dev/null

  # Run a long-lived container on the isolated network.
  docker run -d --name "$NAME" --network "$NETWORK" \
    alpine sh -c 'while true; do sleep 30; done' >/dev/null

  cat <<EOF

Scenario:  Container "$NAME" can't reach the internet. \`curl google.com\` from
           inside it hangs. Figure out which layer is broken (DNS? egress?
           routing? bridge config?) and HOW the user could fix it.

What's true: The container is on an internal-only docker network that has
             no external connectivity. The container itself is fine.

Try:       \`pnpm harness ask "container cannot reach internet"\`
           \`docker exec $NAME ping -c 2 8.8.8.8\`              # IP-level egress
           \`docker exec $NAME ping -c 2 google.com\`           # name resolution
           \`docker exec $NAME nslookup google.com\`            # DNS specifically
           \`docker exec $NAME cat /etc/resolv.conf\`           # what nameservers
           \`docker network inspect $NETWORK\`                  # network config
           \`docker exec $NAME ip route\`                       # routing table

Layer-by-layer:
  1. \`ping <gateway>\` works? → bridge OK
  2. \`ping <external-ip>\` works? → egress OK
  3. \`nslookup <name>\` works? → DNS OK
  4. \`curl <name>\` works? → end-to-end OK
First layer that fails IS the bug.

Reveal:    $0 reveal
Restore:   $0 restore (rm container + network)
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  echo "[07-docker-no-egress] cleaned"
}

verify() {
  if docker network inspect "$NETWORK" >/dev/null 2>&1 || docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[07-docker-no-egress] still in broken state. Run: $0 restore"
    return 1
  else
    echo "[07-docker-no-egress] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[07-docker-no-egress] reveal:

  Failure mode id:    docker.fm.container-no-egress-umbrella
                      (or: docker.fm.container-egress-vpn-conflict if VPN scenario)
  Why it happens:     network was created with --internal, which removes default
                      route + masquerade rules. Container is on its own bridge
                      that has no path to the host's external interface.
  Diagnostic flow (layer-by-layer is the right interview signal):
    Layer 1 (link):   docker exec ping -c 2 <gateway>      (find gw via ip route)
    Layer 2 (IP):     docker exec ping -c 2 8.8.8.8        (raw external IP)
    Layer 3 (DNS):    docker exec nslookup google.com
    Layer 4 (HTTP):   docker exec curl -m 5 https://google.com
    First fail = the layer with the bug.
  Where to look:      docker network inspect <name>        → "Internal": true is the smoking gun
                      ip route on host                     → check if there's a default route
                      sudo iptables -L -t nat -n           → MASQUERADE rule for the bridge subnet?
                      sudo iptables -L DOCKER-USER -n      → DOCKER-USER chain often blocks
  Fix paths:
    (A) Recreate network without --internal:
          docker network rm <net> && docker network create <net>
        (then re-attach the container with `docker network connect`)
    (B) If --internal is intentional and you want one-off egress:
          run a sidecar with --network host that proxies
    (C) If the issue is firewalld/ufw blocking docker:
          docker.fm.host-firewall-blocks-docker
  Trade-off:          --internal is sometimes RIGHT (bastion-only access);
                      check with the user before "fixing" by removing it.

  Reference: pnpm harness ask "container can't reach internet"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
