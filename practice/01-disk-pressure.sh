#!/usr/bin/env bash
# Scenario: An app keeps writing huge logs to /tmp; you're approaching disk-full.
# Symptom:  `df` shows a partition near 100%; user reports app crashes on write.
# Suggested:`ha "disk almost full investigation"` or `ha "what's eating disk space"`
# Restore:  rm the staged files

set -uo pipefail
DIR="/tmp/domains-practice/01-disk"
BIG="$DIR/app.log"
BIG2="$DIR/cache.bin"

start() {
  mkdir -p "$DIR"
  # Create a 500MB log file (only growing portion of /tmp; safe on WSL with TBs)
  echo "[01-disk-pressure] generating ~500 MB of fake log + 300 MB cache..."
  yes "$(date +%s) ERROR something happened that we'll grep for later" \
    | head -c 500M > "$BIG" 2>/dev/null
  dd if=/dev/zero of="$BIG2" bs=1M count=300 status=none 2>/dev/null
  cat <<EOF

Scenario:  Your app's writes are slowing down. Some users see "no space left
           on device" briefly. /tmp is the suspected hot spot. Find the
           offender and free space SAFELY (don't rm anything mission-critical).

What's true: There are 2 large files under /tmp/domains-practice/01-disk/.
             The app.log is 500 MB; the cache.bin is 300 MB.
             You should be able to identify them with standard tools.

Try:       \`pnpm harness ask "disk pressure investigation"\` or
           \`du -sh /tmp/* 2>/dev/null | sort -h | tail\`
           \`df -h\` shows partition usage; \`du -sh DIR\` finds offenders.
Reveal:    $0 reveal
Restore:   $0 restore (frees ~800 MB)
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$DIR"
  echo "[01-disk-pressure] cleaned. \$DIR removed."
}

verify() {
  if [[ -d "$DIR" ]]; then
    local sz; sz="$(du -sh "$DIR" 2>/dev/null | cut -f1)"
    echo "[01-disk-pressure] still in broken state ($sz under $DIR). Run: $0 restore"
    return 1
  else
    echo "[01-disk-pressure] clean."
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[01-disk-pressure] reveal:

  Failure mode id:    linux.fm.disk-full-tmpfs / docker.fm.disk-full-overlay2-leaked
  Why it happens:     uncapped log writes; missing logrotate; app cache without TTL
  Cheapest probe:     df -h && du -sh /tmp/* 2>/dev/null | sort -h | tail
  Better probe:       sudo du -h --max-depth=2 / 2>/dev/null | sort -h | tail -20
  Fix:                identify largest dir with du; rm specific files (NOT rm -rf /tmp blanket)
  Validation:         df -h shows partition < 80%; app writes resume

  Reference: pnpm harness playbook linux.fm.disk-full-tmpfs (if present),
             else: pnpm harness ask "disk pressure"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
