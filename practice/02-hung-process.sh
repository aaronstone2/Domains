#!/usr/bin/env bash
# Scenario: A process is hung waiting on a named pipe that never gets data.
# Symptom:  `ps` shows the process; `kill <pid>` doesn't seem to do anything visible.
# Suggested:`ha "process stuck won't respond"` or `ha "kill -9 doesn't work"`
# Restore:  remove the fifo + signal the cat process

set -uo pipefail
DIR="/tmp/domains-practice/02-hung"
FIFO="$DIR/blocking.fifo"
PIDFILE="$DIR/cat.pid"

start() {
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[02-hung-process] already running (pid=$(cat "$PIDFILE"))"
  else
    [[ -p "$FIFO" ]] || mkfifo "$FIFO"
    # Background cat blocks reading from the empty fifo (no writer ever opens).
    cat "$FIFO" > /dev/null &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    sleep 0.3
  fi
  cat <<EOF

Scenario:  A "long-running cat" process appeared in your process list and
           won't respond to Ctrl+C. ps shows it as state S (interruptible
           sleep). Find what it's waiting on and kill it cleanly.

What's true: The process is reading from $FIFO (a named pipe) that no one is
             writing to. cat blocks on the open() syscall.

Try:       \`pnpm harness ask "process hung on pipe"\`
           \`ps auxf | grep cat\`        # find pid + parent
           \`cat /proc/<pid>/wchan\`     # what the kernel says it's waiting on
           \`ls -l /proc/<pid>/fd/\`     # what file descriptors are open
           \`lsof -p <pid>\`             # cleaner version of the same

Reveal:    $0 reveal
Restore:   $0 restore (kills cat, removes fifo)
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$PIDFILE" ]]; then
    local pid; pid="$(cat "$PIDFILE")"
    kill "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[02-hung-process] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[02-hung-process] still running (pid=$(cat "$PIDFILE")). Run: $0 restore"
    return 1
  else
    echo "[02-hung-process] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[02-hung-process] reveal:

  Failure mode id:    linux.fm.process-stuck-blocked-on-fd
                      (closely related to: linux.fm.process-stuck-d-state — the
                       D-state version is uninterruptible, this one is S-state
                       blocked on file I/O which IS interruptible)
  Why it happens:     reader without writer on a named pipe → open() blocks
                      forever (POSIX semantics: read-side waits for write-side)
  Diagnostic:         cat /proc/<pid>/stack  (kernel stack trace if accessible)
                      cat /proc/<pid>/wchan  (waiting channel)
                      ls -l /proc/<pid>/fd/  (what fds it has open)
                      lsof -p <pid>          (cleaner)
  Fix:                kill -TERM <pid> succeeds (S-state IS interruptible)
                      OR: the proper fix — open the writer side: `echo x > fifo`
                          which unblocks the cat naturally
  Validation:         ps aux | grep cat       returns nothing
  Trade-off note:     S-state vs D-state: SIGKILL works on S; D requires the
                      blocking syscall to complete. Always check ps state first.

  Reference: pnpm harness ask "process stuck blocked"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
