#!/usr/bin/env bash
# Scenario:  Customer's Devin session drops every few minutes. They reconnect,
#            it works for a bit, drops again. Pattern is suspicious — almost
#            exactly the same interval each time. Enterprise customer.
# Symptom:   "My session keeps disconnecting / freezing every 5-6 minutes.
#            I lose my context. Has to be a Devin bug."
# Suggested: pnpm harness ask "devin session drops every 6 minutes enterprise"
# Restore:   removes /tmp/domains-practice/30-disconnects/

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/30-disconnects"
CONN_LOG="$SCENARIO_DIR/devin-connection.log"
AWS_CONFIG="$SCENARIO_DIR/aws-network-topology.txt"

start() {
  mkdir -p "$SCENARIO_DIR"

  # Realistic Devin↔Brain connection log. The pattern is ~350s exactly
  # between disconnects — that's the smoking gun.
  cat > "$CONN_LOG" <<'EOF'
[2026-05-04T18:00:00Z] devin.session.start session_id=sess_a1b2c3 user=alice@bigco.com
[2026-05-04T18:00:00Z] devin.brain.connect endpoint=wss://brain.devin.ai/agent state=connected
[2026-05-04T18:05:51Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=12340
[2026-05-04T18:05:52Z] devin.brain.reconnect attempt=1 state=connected
[2026-05-04T18:11:43Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=11890
[2026-05-04T18:11:44Z] devin.brain.reconnect attempt=1 state=connected
[2026-05-04T18:17:35Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=12010
[2026-05-04T18:17:36Z] devin.brain.reconnect attempt=1 state=connected
[2026-05-04T18:23:27Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=11920
[2026-05-04T18:23:28Z] devin.brain.reconnect attempt=1 state=connected
[2026-05-04T18:29:19Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=12100
[2026-05-04T18:29:20Z] devin.brain.reconnect attempt=1 state=connected
[2026-05-04T18:35:11Z] devin.brain.disconnect reason="connection reset by peer" code=1006 last_msg_age_ms=11700
[2026-05-04T18:35:12Z] devin.brain.reconnect attempt=1 state=connected
EOF

  # Customer's network topology dump (provided in their ticket attachment)
  cat > "$AWS_CONFIG" <<'EOF'
# AWS network topology for bigco prod environment (customer-provided)

VPC: vpc-bigco-prod (10.50.0.0/16)
  Subnet: subnet-private-a (10.50.10.0/24) — Devin DevBox lives here
    Route table: rtb-private-a
      0.0.0.0/0 → nat-gateway-prod (nat-0a1b2c3d)
  Subnet: subnet-public-a (10.50.20.0/24)
    Route table: rtb-public-a
      0.0.0.0/0 → igw-bigco

NAT Gateway: nat-0a1b2c3d
  Type: public
  Subnet: subnet-public-a
  Tags: Environment=prod, ManagedBy=terraform

# No PrivateLink endpoints configured for *.devin.ai
# (checked: aws ec2 describe-vpc-endpoints — returns empty for devin)

# Devin DevBox uses outbound to wss://brain.devin.ai (TCP 443)
# via NAT Gateway → IGW → internet → AWS-edge → Devin's infra
EOF

  cat <<EOF

================================================================================
Customer ticket #6204 (P1 — enterprise customer, blocking 4 engineers)
================================================================================

Customer wrote:

   "Multiple engineers on our team are reporting that their Devin sessions
    keep dropping every few minutes. They have to reconnect, lose context,
    repeat instructions. This started today and didn't happen yesterday.
    We're an enterprise customer with our DevBoxes deployed inside our
    AWS VPC.

    I attached our network topology and a connection log from one of the
    affected sessions. There's nothing in our app changes that should
    have caused this — please investigate the Devin platform side."

Connection log: $CONN_LOG
Network topology (customer attachment): $AWS_CONFIG

Find:
  1. Is this a Devin platform bug or a customer-side issue?
  2. What's the precise pattern in the disconnects?
  3. What's the immediate workaround?
  4. What's the permanent fix?

Try:       pnpm harness ask "devin enterprise session drops every few minutes"
Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$SCENARIO_DIR"
  echo "[30] cleaned"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[30] still set up at $SCENARIO_DIR. Run: $0 restore"
    return 1
  else
    echo "[30] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[30-session-drops-periodically] reveal:

  Failure mode id:    devin.fm.nat-gateway-idle-timeout-disconnects
                      (enterprise-only Devin issue; not a Devin platform bug
                       per se — a customer-network-topology bug surfacing as
                       'Devin is broken')

  Why it happens:     AWS NAT Gateway has a HARD 350-second idle-connection
                      timeout (5m50s). When the WebSocket between Devin's
                      DevBox (in customer VPC) and Devin's Brain (Devin
                      infrastructure) goes idle for 350s, NAT Gateway
                      drops the connection. The DevBox sees 'connection
                      reset by peer' and reconnects. From the customer's
                      seat: 'session frozen, lost context, what is happening.'

  Diagnostic flow:
    1. Read the connection log. The spacing between disconnects is the
       smoking gun:
         awk -F'[[:space:]]' '/disconnect/ {print $1}' devin-connection.log \
           | xargs -I {} date -d {} +%s | awk 'p{print $1-p} {p=$1}'
       → ~351, 351, 352, 351, 352 seconds — too consistent to be random.
    2. NAT Gateway idle timeout = 350s (AWS docs). Match.
    3. Confirm the topology: customer's DevBox routes egress through
       NAT Gateway (no PrivateLink endpoint for *.devin.ai).
    4. Check for PrivateLink in their config:
         aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=*devin*
       → empty (the actual cause)

  Customer-side fixes (in increasing order of effort + correctness):

    (A) [BAND-AID, immediate] Add an app-layer keepalive — Devin DevBox
        sends a tiny WebSocket ping every 60s, well under the 350s budget.
        This requires Devin's session client to support it; some versions
        do, some don't. Check version + enable if available.

    (B) [REAL FIX] Set up a PrivateLink (VPC interface endpoint) for
        Devin's services. Traffic stays inside AWS backbone, doesn't go
        through NAT Gateway, no idle timeout to worry about. Devin
        publishes the service name; customer creates the endpoint:
          aws ec2 create-vpc-endpoint \
            --vpc-id vpc-bigco-prod \
            --service-name com.amazonaws.vpce.us-east-1.<devin-service> \
            --subnet-ids subnet-private-a
        Coordinate with Devin support to get the exact service name.

    (C) [HEAVY] Replace NAT Gateway with NAT Instance with custom timeouts.
        Operationally costly; avoid unless other options are blocked.

  Customer expectation management:
    This is NOT a Devin platform bug. NAT Gateway's 350s timeout is
    documented AWS behavior. Devin's infra ack: 'we should send a
    keepalive ping at the protocol layer.' Reasonable; meanwhile the
    customer has the PrivateLink path which is the right enterprise
    architecture anyway.

  Validation (after PrivateLink):
    aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=*devin*
      → should now return the endpoint
    Sessions should run for hours without the periodic disconnect.

  Cross-domain:
    Same pattern in:
    - Long-poll APIs through NAT/firewall — set keepalive < firewall idle.
    - Database connection pools — set max idle time < firewall timeout.
    - K8s pod-to-pod through cloud LB — same NAT issue, same fix.

  Reference: pnpm harness playbook devin.fm.nat-gateway-idle-timeout-disconnects
             AWS docs: NAT Gateway idle timeout
             pnpm harness ask "websocket disconnect every 6 minutes nat gateway"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
