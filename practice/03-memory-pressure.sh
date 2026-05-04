#!/usr/bin/env bash
# Scenario: A python process is gradually allocating large amounts of memory.
# Symptom:  `free -h` shows shrinking available memory; eventually OOM-killer fires.
# Suggested:`ha "process eating memory"` or `ha "OOMKilled investigation"`
# Restore:  kill the python balloon process

set -uo pipefail
DIR="/tmp/domains-practice/03-mem"
PIDFILE="$DIR/balloon.pid"

start() {
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[03-memory-pressure] already running (pid=$(cat "$PIDFILE"))"
  else
    if ! command -v python3 >/dev/null 2>&1; then
      echo "[03-memory-pressure] needs python3 — install it or skip this scenario"
      exit 1
    fi
    # 500 MB balloon. setsid (not nohup) so bash $! captures the python pid,
    # not nohup's pid. Stdout discarded; we write the pid explicitly.
    setsid python3 -c "
import time, os
buf = bytearray(1 * 1024 * 1024 * 500)   # 500 MB
print('balloon allocated, pid', os.getpid(), flush=True)
time.sleep(86400)
" > /dev/null 2>&1 < /dev/null &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    sleep 0.5
  fi
  cat <<EOF

Scenario:  Memory available on this box is dropping. \`free -h\` shows ~500 MB
           less than usual. Identify the offending process and stop it.

What's true: A python3 process is holding a 500 MB bytearray. Find it.

Try:       \`pnpm harness ask "process eating memory"\`
           \`free -h\`                                       # confirm pressure
           \`ps -eo pid,user,rss,vsz,cmd --sort=-rss | head\` # by RSS
           \`top\`  (then 'M' to sort by memory)
           \`cat /proc/<pid>/status | grep -E 'Vm|Rss'\`
           \`cat /proc/<pid>/cmdline | tr '\0' ' '\`        # what it is

Reveal:    $0 reveal
Restore:   $0 restore (kills the python process)
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$PIDFILE" ]]; then
    local pid; pid="$(cat "$PIDFILE")"
    kill "$pid" 2>/dev/null || true
    sleep 0.2
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[03-memory-pressure] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[03-memory-pressure] still running (pid=$(cat "$PIDFILE")). Run: $0 restore"
    return 1
  else
    echo "[03-memory-pressure] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[03-memory-pressure] reveal:

  Failure mode id:    linux.fm.process-memory-leak (or oom-killer family)
  Why it happens:     python bytearray(500_MB) held in process memory + sleep
  Diagnostic:         free -h                               (system view)
                      ps -eo pid,user,rss,vsz,cmd --sort=-rss | head -10  (per-proc)
                      cat /proc/<pid>/status | grep VmRSS   (precise per-pid)
                      smem -t -k                            (better grouping if installed)
                      cat /proc/<pid>/maps                  (where the memory is)
  Fix:                kill <pid>                            (graceful)
                      kill -9 <pid>                         (force)
                      Real fix: app-level — set process memory limit, fix leak
  Validation:         free -h shows recovered memory; pid no longer in ps
  Container note:     in a cgroup, hitting memory.max triggers OOM-killer (SIGKILL,
                      exit 137). On the host, it's the kernel OOM-killer with
                      different selection heuristics. Both end the same way.

  Reference: pnpm harness ask "process memory leak" or "OOMKilled"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
