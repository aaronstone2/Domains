#!/usr/bin/env bash
# Scenario: A workload's TLS handshake or JWT validation suddenly fails.
#           Cert / token APPEAR valid by inspection. The catch: system
#           clock is off (drifted, never synced, NTP broken). cert.notBefore
#           is "in the future" or token "expired" because clock is wrong.
# Symptom:  "x509: certificate has expired or is not yet valid"
#           "JWT exp claim has expired" / "iat is in the future"
#           kerberos: "Clock skew too great"
#           even though the cert/token actually IS valid by wall-clock time.
# Suggested: ha "JWT expired but token is fresh"
# Restore:  no destructive system changes; nothing to undo

set -uo pipefail
DIR="/tmp/domains-practice/22-clock"

start() {
  command -v openssl >/dev/null 2>&1 || { echo "[22] needs openssl"; exit 1; }
  mkdir -p "$DIR"

  # Generate a cert that's only valid for the next 60 SECONDS.
  # Client/server with skewed clocks would see this as not-yet-valid or expired.
  openssl req -x509 -newkey rsa:2048 -keyout "$DIR/short.key" -out "$DIR/short.crt" \
    -nodes -days 1 -subj "/CN=clockskew.example" \
    -addext "subjectAltName=DNS:clockskew.example" 2>/dev/null

  cat <<EOF

Scenario:  This one is forensic — there's no live broken process to debug.
           You're investigating an INCIDENT REPORT: yesterday at 02:00 UTC,
           a fleet of agents started failing JWT validation with "exp has
           passed" even though the JWTs were freshly issued. Same time,
           TLS to internal services started erroring with "certificate has
           expired or is not yet valid".

           Your task: identify CLOCK SKEW as the cause, find the diagnostic
           commands that would have proven it at 02:00, and write the
           preventive control.

           This is the ONE scenario that's pure runbook + reasoning — there's
           no live broken state on this box. Talk through diagnosis as if
           you're at the operator's terminal at 02:00.

What's true: $DIR/short.crt is a real cert valid from "now-ish" to "1 day
             from now". You can use it as a prop to demonstrate the
             diagnostic commands you'd run on the affected box.

Diagnostic flow (the interview-relevant skill is REASONING that "expired"
errors with valid-looking creds = clock check first):

  pnpm harness ask "JWT expired but token is fresh OR clock skew"

  # 1. The first check that should catch this in under 30 seconds:
  date -u                          # what does this box think the time is?
  timedatectl status               # systemd's view: synced? source?
  chronyc tracking 2>/dev/null     # if chronyd: drift, last sync, stratum
  ntpq -p 2>/dev/null              # if ntpd: peers, offset

  # 2. Cross-check against external truth (in real outage):
  curl -sI http://google.com | grep -i ^date
  curl -sI https://time.cloudflare.com | grep -i ^date
  # Compare to local 'date -u'. Difference > 30s explains the symptoms.

  # 3. For the cert specifically: see notBefore / notAfter in the cert
  openssl x509 -in $DIR/short.crt -noout -dates -subject
  # If 'date -u' is BEFORE notBefore → "not yet valid"
  # If 'date -u' is AFTER notAfter → "has expired"

  # 4. For JWT: decode + check exp/iat/nbf vs current time
  # JWT body is base64-encoded JSON; decode it:
  echo 'eyJhbGciOi...' | cut -d. -f2 | base64 -d 2>/dev/null | jq .
  # exp = expiration unix ts, iat = issued-at, nbf = not-before
  # date -u +%s gives current. Compare.

  # 5. Why did NTP fail? (root cause):
  systemctl status systemd-timesyncd 2>/dev/null
  systemctl status chronyd 2>/dev/null
  systemctl status ntpd 2>/dev/null
  journalctl -u systemd-timesyncd -n 30 --no-pager 2>/dev/null
  journalctl -u chronyd -n 30 --no-pager 2>/dev/null
  # Common: blocked outbound 123/udp; misconfigured server pool; drift exceeded
  # the daemon's panic threshold and it stopped trying

  # 6. Container case: the container inherits clock from the host kernel
  # (one shared clock per kernel). So if the HOST is off, every container
  # is off. If only ONE container reports clock issues but host is fine,
  # the issue is the container's TZ/locale (which doesn't affect cert
  # validation — those use UTC), not actual clock skew.

Reveal:    $0 reveal
Restore:   $0 restore (just removes \$DIR; no system changes were made)
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$DIR"
  echo "[22] cleaned"
}

verify() {
  if [[ -d "$DIR" ]]; then
    echo "[22] $DIR still present. Run: $0 restore"
    return 1
  else
    echo "[22] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[22-clock-skew] reveal:

  Failure mode id:    linux.fm.clock-skew-cert-jwt-validation-fails
                      (an under-appreciated SE category — the SYMPTOMS look
                       like cert/token expired but the ROOT is the box's
                       clock, not the credential. Misdiagnosed often: people
                       reissue tokens / certs and the problem persists.)

  Why it happens:     TLS cert validation, JWT validation, Kerberos tickets,
                      OAuth tokens, AWS Sigv4, OTP/TOTP — ALL depend on
                      "what time is it now" being approximately correct on
                      the validating side. Skew of 30s+ starts breaking
                      strict validators (default Kerberos tolerance is 5min,
                      most JWT libraries are 30-60s, AWS Sigv4 is 15min).
                      When NTP/chronyd/timesyncd fails to sync (network
                      block, daemon stopped, drift exceeded panic threshold,
                      VM paused/resumed), the box drifts and credentials
                      START failing even though they're valid by wall-clock.

  Symptoms that should make you check the clock FIRST:
    - "x509: certificate has expired or is not yet valid"
      (especially when the cert genuinely IS valid right now)
    - JWT/OIDC: exp/nbf/iat-related errors with fresh tokens
    - Kerberos: "Clock skew too great" (KRB5KRB_AP_ERR_SKEW)
    - AWS Sigv4: "Signature expired" / "Request expired" with current sig
    - HMAC-based OTP fails on first try
    - SAML assertions: "NotOnOrAfter has passed"
    - TLS 1.3 handshake failure with valid cert (rare)

  Diagnostic order (this is the SE-grade flow):
    1. date -u                        → what THIS box thinks
    2. timedatectl status             → sync source + status
    3. curl -sI http://google.com | grep ^date  → independent ground truth
    4. compare → if delta > 30s, you've found it
    5. drill into NTP/chrony state for ROOT cause
    6. fix: restart timesync daemon; force re-sync; check 123/udp egress

  Fix paths:
    (A) Force immediate re-sync (immediate):
          sudo chronyc -a makestep      (chrony)
          sudo systemctl restart systemd-timesyncd
          sudo timedatectl set-ntp true
          sudo ntpdate -s pool.ntp.org  (only if no ntpd/chronyd running)
    (B) Check egress: outbound 123/udp must reach the time server pool
          ss -tunlp | grep 123 ; iptables -L OUTPUT | grep 123
    (C) For VMs that pause-resume (laptop suspend, snapshotted VMs): install
          host-guest time sync (qemu-guest-agent, vmware-tools, hyperv-daemons)
          so the guest re-syncs on resume.
    (D) Architectural: monitor clock skew as a first-class metric. e.g.
          node_timex_offset_seconds in Prometheus. Alert on |skew| > 5s.

  Validation:         date -u matches external source within 1s; chronyc
                      tracking shows recent successful sync; failing
                      JWT/cert validation now succeeds.

  Why this matters for Devin:
    Devin sessions are long-running VMs. They CAN drift, especially after
    snapshot-restore (snapshot is taken at T0, restored at T0+hours, clock
    is wrong by hours). If a Devin task suddenly can't talk to GitHub OAuth
    or AWS, BEFORE you reissue tokens, run `date -u` on the DevBox.

  Reference: pnpm harness playbook linux.fm.clock-skew-cert-jwt-validation-fails
             pnpm harness ask "clock skew"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
