#!/usr/bin/env bash
# Scenario: One systemd unit failed; multiple downstream units that depend
#           on it are now also failing. Operator sees "5 units in failed
#           state" and panics. Find the ROOT failure (not the symptoms),
#           then walk the dependency graph to confirm the others recover
#           when root is fixed.
# Symptom:  systemctl --failed shows N failed units; user thinks it's
#           "everything", but it's actually 1 root + N-1 downstream.
# Suggested: ha "multiple systemd units failed cascading"
# Restore:  remove all the staged units

set -uo pipefail
DIR="/tmp/domains-practice/21-cascade"
DB_UNIT="domains-practice-fakedb.service"
API_UNIT="domains-practice-fakeapi.service"
WORKER_UNIT="domains-practice-fakeworker.service"
UNIT_DIR="$HOME/.config/systemd/user"

start() {
  command -v systemctl >/dev/null 2>&1 || { echo "[21] needs systemctl"; exit 1; }
  systemctl --user --no-pager status >/dev/null 2>&1 || {
    echo "[21] systemd --user not running. On WSL try: sudo loginctl enable-linger \$USER then re-login"
    echo "[21] continuing — units installed but won't start cleanly until --user is up"
  }

  mkdir -p "$DIR" "$UNIT_DIR"

  # Root unit: "fakedb" — designed to FAIL (binary doesn't exist).
  cat > "$UNIT_DIR/$DB_UNIT" <<EOF
[Unit]
Description=Practice: fake DB (will fail; root cause)

[Service]
Type=simple
ExecStart=/usr/local/bin/totally-not-a-real-db --serve
Restart=no

[Install]
WantedBy=default.target
EOF

  # Mid unit: "fakeapi" — depends on DB. Will fail to start because db failed.
  cat > "$UNIT_DIR/$API_UNIT" <<EOF
[Unit]
Description=Practice: fake API (depends on db; will cascade-fail)
Requires=$DB_UNIT
After=$DB_UNIT

[Service]
Type=simple
ExecStart=/bin/sh -c 'sleep 86400'
Restart=no

[Install]
WantedBy=default.target
EOF

  # Leaf unit: "fakeworker" — depends on api. Cascades again.
  cat > "$UNIT_DIR/$WORKER_UNIT" <<EOF
[Unit]
Description=Practice: fake worker (depends on api; cascades from db)
Requires=$API_UNIT
After=$API_UNIT

[Service]
Type=simple
ExecStart=/bin/sh -c 'sleep 86400'
Restart=no

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload 2>/dev/null || true
  # Try to start the leaf — pulls in everything via Requires chain
  systemctl --user start "$WORKER_UNIT" 2>/dev/null || true
  sleep 1

  cat <<EOF

Scenario:  3 systemd --user units are in trouble. \`systemctl --user --failed\`
           shows multiple failures. The operator says "everything is broken".

           Don't assume it's all broken — N-1 of those failures are
           DOWNSTREAM CASCADES from a single root failure. Walk the
           dependency graph backward to find the root.

What's true: $DB_UNIT has ExecStart pointing at a binary that doesn't exist
             ("/usr/local/bin/totally-not-a-real-db"). $API_UNIT Requires=db,
             $WORKER_UNIT Requires=api. So db's failure cascades through
             both. ROOT = db; SYMPTOMS = api + worker.

Try (graph walk, not whack-a-mole):
  pnpm harness ask "multiple systemd units failed cascading"

  # 1. List failed units
  systemctl --user --failed --no-pager
  systemctl --user list-units --state=failed --no-pager

  # 2. For each failed unit, what does it require?
  for u in $DB_UNIT $API_UNIT $WORKER_UNIT; do
    echo "=== \$u ==="
    systemctl --user show \$u -p Requires,After,WantedBy --no-pager
  done

  # 3. Walk the dependency tree from the LEAF backward
  systemctl --user list-dependencies $WORKER_UNIT --no-pager

  # 4. Find the ROOT: the unit that failed and is NOT downstream of another
  #    failed unit. Look at "(start request repeated)" in journal vs
  #    "Failed with result 'dependency'" — the latter is a CASCADE.
  for u in $DB_UNIT $API_UNIT $WORKER_UNIT; do
    echo "=== \$u ==="
    journalctl --user -u \$u -n 5 --no-pager 2>/dev/null \\
      | grep -iE 'failed|exec|dependency|repeated'
  done

  # 5. Once you've identified the root, confirm fix order:
  # The cascade resolves once the root recovers. systemd will retry
  # downstream automatically if Restart= or BindsTo= is set; otherwise
  # you restart them after the root.

Reveal:    $0 reveal
Restore:   $0 restore (stops + removes all 3 units)
Verify:    $0 verify
EOF
}

restore() {
  for u in "$WORKER_UNIT" "$API_UNIT" "$DB_UNIT"; do
    systemctl --user stop "$u" 2>/dev/null || true
    systemctl --user disable "$u" 2>/dev/null || true
    rm -f "$UNIT_DIR/$u"
  done
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user reset-failed 2>/dev/null || true
  rm -rf "$DIR"
  echo "[21] cleaned"
}

verify() {
  if [[ -f "$UNIT_DIR/$DB_UNIT" || -f "$UNIT_DIR/$API_UNIT" || -f "$UNIT_DIR/$WORKER_UNIT" ]]; then
    echo "[21] units still installed under $UNIT_DIR. Run: $0 restore"
    return 1
  else
    echo "[21] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[21-systemd-cascade] reveal:

  Failure mode id:    linux.fm.systemd-dependency-cascade-failure
                      (sibling of linux.fm.systemd-unit-restart-loop, but
                       the diagnostic skill is DIFFERENT — here it's "find
                       the root in a graph of N broken things", not "fix
                       this one broken thing")
  Why it happens:     systemd resolves Requires= / Wants= / BindsTo= when
                      starting a unit. If a required dependency fails, the
                      requester's start is reported as "Failed with result
                      'dependency'". Multiple downstream units can fail with
                      the SAME root cause; the operator sees N failures and
                      may try to fix N units when they only need to fix 1.
  Diagnostic flow:
    1. systemctl --failed                → list of all failed units
    2. systemctl list-dependencies <leaf>
       systemctl list-dependencies --reverse <root>
                                          → graph view either direction
    3. journalctl -u <unit>              → look for the failure REASON
                                          STRING, not just "failed":
       - "Failed to start"               → ExecStart failed (could be ROOT)
       - "Failed with result 'exit-code'"→ ExecStart exited non-zero (ROOT)
       - "Failed with result 'dependency'"→ CASCADE — not the root
       - "Job ... canceled"              → CASCADE — depends on something
                                            else that failed
    4. systemctl status <unit> -l        → shows the immediate trigger
    5. systemctl show <unit> -p Requires,Wants,BindsTo,Conflicts
                                          → declared deps to walk
  Pattern to identify root vs cascade:
    A unit is the ROOT if EITHER:
      - journal shows ExecStart actually executed and failed, OR
      - status shows "Failed to find executable" / actual error
    A unit is a CASCADE if:
      - journal says "Failed with result 'dependency'", OR
      - "Job xxx/start was canceled" (because something it depends on died)
  Fix order:
    1. Fix the ROOT unit (whatever caused ExecStart to fail).
    2. systemctl reset-failed             (clear failed state of cascades)
    3. systemctl start <root>             (cascades restart automatically
                                             if they have Restart= set, or
                                             you restart them manually)
  Validation:         systemctl --failed returns empty;
                      systemctl is-active <each unit> = active.
  Trade-off:          Requires= vs Wants= vs BindsTo=:
                      - Requires: hard dep; if root fails, requester is canceled
                      - Wants: soft dep; root failure doesn't cancel requester
                      - BindsTo: hard dep AND tracks state — if root stops
                                  later, requester stops too
                      Common bug: people use Requires when Wants is correct,
                      causing unnecessary cascades. Use Wants when the
                      relationship is "would be nice if it's there" not
                      "I literally cannot run without it".
  Cross-domain:       Same skill applies in k8s — pod CrashLoopBackOff can
                      cascade through readinessProbe → service endpoint →
                      downstream service. Walk the graph; fix the root.

  Reference: pnpm harness playbook linux.fm.systemd-dependency-cascade-failure
             pnpm harness ask "systemd cascading failure"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
