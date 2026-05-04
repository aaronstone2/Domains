#!/usr/bin/env bash
# Template for practice scenarios. Copy + customize the four functions below.
# Header convention: 1-line scenario name, then a paragraph the user reads
# at `start` time describing what the box looks like.
#
# Scenario:    Brief description for the table-of-contents.
# Symptom:     What the user sees / would describe.
# Suggested:   `pnpm harness ask "<phrasing>"` that should land the right fm.
# Restore:     What `restore` does to undo.

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/_template"

start() {
  echo "[practice _template] starting scenario..."
  mkdir -p "$SCENARIO_DIR"
  # ... break something ...
  echo
  echo "Scenario:   <one-line user-facing description>"
  echo
  echo "Try:        pnpm harness ask \"<your phrasing of the symptom>\""
  echo "Restore:    $0 restore"
}

restore() {
  echo "[practice _template] restoring..."
  rm -rf "$SCENARIO_DIR"
  # ... undo any other changes ...
  echo "[practice _template] done"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[practice _template] still in broken state (try $0 restore)"
    return 1
  else
    echo "[practice _template] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[practice _template] reveal:

  Failure mode id:   <fm-id>
  Why it happens:    <one-line cause>
  Diagnostic command:<the one cheap probe>
  Fix command:       <the one fix>

  Reference: pnpm harness playbook <fm-id>
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
