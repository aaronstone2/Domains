#!/usr/bin/env bash
# Scenario: A long-running process is leaking file descriptors. Eventually
#           it hits RLIMIT_NOFILE and accept()/open()/socket() returns
#           "Too many open files" (EMFILE). Memory + disk are fine.
# Symptom:  "accept: too many open files" / "open: too many open files"
#           in app logs. Service stops accepting connections.
# Suggested: ha "too many open files file descriptor leak"
# Restore:  kill the leaker

set -uo pipefail
DIR="/tmp/domains-practice/24-fd"
PIDFILE="$DIR/leaker.pid"

start() {
  command -v python3 >/dev/null 2>&1 || { echo "[24] needs python3"; exit 1; }
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[24] leaker already running"
  else
    # Open files as fast as possible without closing them. Sleep to keep
    # the FDs allocated. Will hit per-process RLIMIT_NOFILE quickly.
    setsid python3 -c "
import time, os
fds = []
for i in range(800):
    try:
        fd = os.open('/tmp', os.O_RDONLY)
        fds.append(fd)
    except OSError as e:
        # Will hit EMFILE around the rlimit
        break
print('opened', len(fds), 'fds; pid', os.getpid())
time.sleep(86400)
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 1
  fi

  cat <<EOF

Scenario:  Service is logging "accept: too many open files" / EMFILE.
           CPU + memory + disk all look fine. The process is up but no
           longer servicing requests.

           Find:
           1. Confirm it's an FD leak (current count vs limit)
           2. What KIND of FDs are leaking (sockets? files? pipes?)
           3. The systemic fix vs the immediate one

What's true: A python process (pid=$(cat "$PIDFILE")) opened ~800 file
             descriptors and didn't close them. Per-process RLIMIT_NOFILE
             on most distros is 1024 soft / 4096 hard (older) or much
             higher on modern systemd-managed sessions.

Try:       pnpm harness ask "too many open files file descriptor leak"

  # 1. Current FD count for the process
  ls /proc/$(cat "$PIDFILE")/fd/ | wc -l

  # 2. The applicable limit
  cat /proc/$(cat "$PIDFILE")/limits | grep 'open files'
  # Or with prlimit:
  prlimit --pid $(cat "$PIDFILE") --nofile

  # 3. What kind of FDs are open? (the smoking gun for what to fix)
  ls -l /proc/$(cat "$PIDFILE")/fd/ | head -20
  # types: socket: → sockets; pipe: → pipes; /tmp/foo → regular files

  # 4. Aggregate the FD types so you don't read 800 lines
  ls -l /proc/$(cat "$PIDFILE")/fd/ 2>/dev/null \\
    | awk 'NR>1 {print \$NF}' \\
    | sed -E 's|/[^/]+$|/PATH|; s/\\[.*\\]//' \\
    | sort | uniq -c | sort -rn | head

  # 5. lsof gives a richer view (FILE, TYPE, NAME, plus connection state for sockets)
  sudo lsof -p $(cat "$PIDFILE") 2>/dev/null | head -30
  sudo lsof -p $(cat "$PIDFILE") 2>/dev/null \\
    | awk '{print \$5}' | sort | uniq -c | sort -rn

  # 6. System-wide context (was it just this process, or the whole host?)
  cat /proc/sys/fs/file-nr   # allocated, free, max  (system-wide)
  ulimit -n                  # current shell's soft limit
  ulimit -Hn                 # current shell's hard limit

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    sleep 0.3
    kill -9 "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[24] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[24] still running. Run: $0 restore"
    return 1
  else
    echo "[24] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[24-fd-exhaustion] reveal:

  Failure mode id:    linux.fm.file-descriptor-leak-emfile
                      (the "too many open files" family — extremely common
                       in long-running services, especially HTTP servers
                       and apps that open files-per-request without close()
                       in error paths)
  Why it happens:     Each accept(), open(), socket(), pipe(), eventfd()
                      consumes a file descriptor. Each process has a
                      RLIMIT_NOFILE cap (default 1024 soft, often higher).
                      When app code forgets to close() FDs in error paths,
                      or when a connection-pool's idle close is broken,
                      FDs accumulate. Eventually any new fd-creating
                      syscall returns EMFILE.

  Diagnostic flow:
    1. ls /proc/<pid>/fd/ | wc -l          → current FD count
    2. cat /proc/<pid>/limits | grep 'open files' → soft + hard limit
       (or: prlimit --pid <pid> --nofile)
    3. ls -l /proc/<pid>/fd/                → what kind: socket / pipe / file
    4. aggregate FD types — awk pipeline above
       OR: lsof -p <pid> | awk '{print $5}' | sort | uniq -c | sort -rn
    5. /proc/sys/fs/file-nr                 → SYSTEM-WIDE FD usage
                                                  (allocated free max)
                                                  if approaching max → host-level
    6. ss -atnp | grep <pid>                → if leaks are SOCKETS, what state?
                                                  ESTABLISHED but never closed?
                                                  TIME_WAIT not draining?
                                                  CLOSE_WAIT (peer closed, you didn't)?

  CLOSE_WAIT specifically is the "we forgot to close" smoking gun:
    ss -atnp | grep <pid> | awk '{print $1}' | sort | uniq -c
    If CLOSE_WAIT count > 0 and growing: app closed its read side of a
    socket that the peer also closed, but you never close()'d.

  Fix paths:
    (A) IMMEDIATE — restart the leaking process. Buys time. FDs reclaimed.
    (B) RAISE THE LIMIT (mitigation, not fix):
          prlimit --pid <pid> --nofile=8192:8192
          Or persistently: edit /etc/security/limits.conf or systemd unit
          [Service] LimitNOFILE=65536
    (C) THE REAL FIX — find the leak in code:
          - Use try-finally / context-manager / RAII
          - Look for code paths that open() without close() in exception path
          - For HTTP clients: ensure connection pool's max-idle is bounded
          - For socket servers: ensure accept-then-error path closes the fd
        Use the FD type breakdown to narrow:
          - sockets leaking → networking code
          - regular files leaking → file I/O code
          - pipes leaking → subprocess management code

  Validation:         /proc/<pid>/fd/ count plateaus instead of growing;
                      no new EMFILE in app logs over 1 hour.

  Trade-off:          Raising LimitNOFILE is fine to do — modern kernels
                      support millions. But if it's a leak (rather than
                      legitimately needing more), raising the limit just
                      delays the symptom by hours. Always pair with:
                      "I raised the limit AND opened a ticket to find the
                      leak in code."

  Cross-domain:       k8s container has its own RLIMIT_NOFILE inherited
                      from runtime; set via securityContext or runtime
                      defaults. nginx famously needs 65k+ for high traffic.

  Reference: pnpm harness playbook linux.fm.file-descriptor-leak-emfile
             pnpm harness ask "too many open files"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
