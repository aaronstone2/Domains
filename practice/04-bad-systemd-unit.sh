#!/usr/bin/env bash
# Scenario: A systemd --user unit fails to start. journalctl shows a cryptic message.
# Symptom:  `systemctl --user status broken-app` reports failed.
# Suggested:`ha "systemd unit won't start"` or `ha "unit restart loop"`
# Restore:  stop unit + remove unit file

set -uo pipefail
DIR="/tmp/domains-practice/04-systemd"
UNIT_NAME="domains-practice-broken-app.service"
UNIT_FILE="$HOME/.config/systemd/user/$UNIT_NAME"

start() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[04-bad-systemd-unit] systemctl not available — skip this scenario on non-systemd boxes"
    exit 1
  fi
  if ! systemctl --user --no-pager status >/dev/null 2>&1; then
    echo "[04-bad-systemd-unit] systemd --user not running. On WSL try: 'sudo loginctl enable-linger \$USER' then re-login"
    echo "[04-bad-systemd-unit] continuing anyway — the unit file will be installed but won't start cleanly"
  fi

  mkdir -p "$DIR" "$(dirname "$UNIT_FILE")"

  # Bad unit: ExecStart points at a binary that doesn't exist.
  # Plus Type=oneshot + Restart=on-failure → restart loop classic.
  cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Practice scenario — bad unit on purpose
After=default.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/totally-not-a-real-binary --serve
Restart=on-failure
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user start "$UNIT_NAME" 2>/dev/null || true

  cat <<EOF

Scenario:  A teammate added a new systemd --user service that fails to start.
           The unit name is "$UNIT_NAME". Find why and decide between:
           (a) fix the unit so it can run, OR
           (b) tell them what to fix in the unit file.

What's true: The unit file is at $UNIT_FILE.
             The ExecStart binary path is wrong (it doesn't exist).

Try:       \`pnpm harness ask "systemd unit failed to start"\`
           \`systemctl --user status $UNIT_NAME\`
           \`systemctl --user list-units --failed\`
           \`journalctl --user -u $UNIT_NAME -n 20 --no-pager\`
           \`systemd-analyze --user verify $UNIT_FILE\`

Reveal:    $0 reveal
Restore:   $0 restore (stops + removes the unit)
Verify:    $0 verify
EOF
}

restore() {
  systemctl --user stop "$UNIT_NAME" 2>/dev/null || true
  systemctl --user disable "$UNIT_NAME" 2>/dev/null || true
  rm -f "$UNIT_FILE"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user reset-failed "$UNIT_NAME" 2>/dev/null || true
  rm -rf "$DIR"
  echo "[04-bad-systemd-unit] cleaned"
}

verify() {
  if [[ -f "$UNIT_FILE" ]]; then
    echo "[04-bad-systemd-unit] still installed at $UNIT_FILE. Run: $0 restore"
    return 1
  else
    echo "[04-bad-systemd-unit] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[04-bad-systemd-unit] reveal:

  Failure mode id:    linux.fm.systemd-unit-restart-loop
                      linux.fm.systemd-exec-binary-not-found
  Why it happens:     ExecStart= path doesn't exist + Restart=on-failure → loop
  Diagnostic:         systemctl --user status <unit>           (exit code + last log)
                      journalctl --user -u <unit> -n 20        (full error)
                      systemd-analyze --user verify <unit-file>(syntax + path check)
                      file $(awk '/ExecStart=/{print $1}' <unit>) (does binary exist?)
  Fix:                stop the loop:        systemctl --user stop <unit>
                      clear failed counter: systemctl --user reset-failed <unit>
                      fix the path in unit file
                      reload + restart:     systemctl --user daemon-reload && start
  Trade-off:          Restart=on-failure is good for genuine crashes but
                      catastrophic for "binary missing" — every 3s a new failure.
                      Consider RestartSec=30s + StartLimitBurst=5 to avoid hammering.

  Reference: pnpm harness ask "systemd unit restart loop"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
