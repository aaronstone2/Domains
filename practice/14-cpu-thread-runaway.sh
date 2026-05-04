#!/usr/bin/env bash
# Scenario: One process is at 100% CPU. `top` shows the process but the user
#           wants to know WHICH thread inside it (and ideally which function).
#           Multi-threaded apps need per-thread investigation, not per-process.
# Symptom:  Service degrades; one process pegged at 100% CPU; "what's it doing?"
# Suggested: ha "process at 100% CPU find which thread"
# Restore:  kill the python process

set -uo pipefail
DIR="/tmp/domains-practice/14-cpu"
PIDFILE="$DIR/spinner.pid"

start() {
  command -v python3 >/dev/null 2>&1 || { echo "[14] needs python3"; exit 1; }
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[14] already running (pid=$(cat "$PIDFILE"))"
  else
    # Multi-threaded python: 4 idle threads + 1 spinning thread.
    # The spinner is named so it's identifiable in /proc/<pid>/task/<tid>/comm
    setsid python3 -c "
import threading, time, os, sys

def idle():
    while True:
        time.sleep(60)

def runaway():
    # CPU-bound spin. Named so /proc/<pid>/task/<tid>/comm shows it.
    import ctypes
    libc = ctypes.CDLL(None, use_errno=True)
    PR_SET_NAME = 15
    libc.prctl(PR_SET_NAME, b'spin-loop', 0, 0, 0)
    while True:
        x = 0
        for i in range(10_000_000):
            x = (x * 31 + i) & 0xffffffff

# 4 idle threads
for _ in range(4):
    threading.Thread(target=idle, daemon=True).start()
# 1 runaway thread
threading.Thread(target=runaway, daemon=True).start()

# Main thread also idle
while True:
    time.sleep(60)
" >/dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 0.5
  fi

  cat <<EOF

Scenario:  A python process is consuming 100% of one CPU core. \`top\`
           shows ONE PID at high CPU. But python apps multiplex N threads
           inside one process — you need to know which THREAD is the
           offender, and ideally which function it's executing. Single-
           threaded view is not enough.

What's true: One python process (pid=$(cat "$PIDFILE")) has 6 threads:
             4 idle (sleep), 1 runaway (CPU-bound spin loop, prctl-named
             "spin-loop"), 1 main idle. Only the spin-loop thread is hot.

Try (escalate from per-process to per-thread to per-function):
  pnpm harness ask "process pegged at 100 percent cpu find thread"

  # 1. Per-process view (you already have this from top)
  ps -p $(cat "$PIDFILE") -o pid,pcpu,pmem,nlwp,cmd

  # 2. Per-thread view (this is the leap most miss)
  top -H -p $(cat "$PIDFILE")          # then look at %CPU per TID
  ps -L -p $(cat "$PIDFILE") -o pid,tid,pcpu,stat,comm

  # 3. Even better: per-thread CPU over a short window (sysstat)
  pidstat -t -p $(cat "$PIDFILE") 1 3   # sample 3x at 1s intervals

  # 4. /proc directly (no extra tools)
  for tid in /proc/$(cat "$PIDFILE")/task/*; do
    tname=\$(cat "\$tid/comm" 2>/dev/null)
    tutime=\$(awk '{print \$14+\$15}' "\$tid/stat" 2>/dev/null)
    echo "\$(basename "\$tid")  utime=\$tutime  comm=\$tname"
  done | sort -k2 -nr | head -10

  # 5. Once you have the TID, see what it's doing right now
  cat /proc/$(cat "$PIDFILE")/task/<TID>/stack 2>/dev/null   # kernel stack (root)
  cat /proc/$(cat "$PIDFILE")/task/<TID>/wchan               # what it's waiting on
  py-spy dump --pid $(cat "$PIDFILE") 2>/dev/null            # python stack (if installed)

  # 6. With perf: which kernel/userspace functions
  sudo perf top -p $(cat "$PIDFILE")                          # interactive
  sudo perf record -F 99 -p $(cat "$PIDFILE") -g -- sleep 5   # capture
  sudo perf report --stdio | head -30

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
  echo "[14] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[14] still running (pid=$(cat "$PIDFILE")). Run: $0 restore"
    return 1
  else
    echo "[14] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[14-cpu-thread-runaway] reveal:

  Failure mode id:    methodology.fm.cpu-utilization-misleading
                      (the meta-skill: process-level metrics hide thread-level
                       reality. Always check -H/-L/per-thread when investigating
                       CPU.)
  Why it happens:     Multi-threaded apps multiplex N threads in one process.
                      `top` and `ps` aggregate to the process by default. A
                      single runaway thread can show as "100% CPU" on the
                      process even when the other N-1 threads are idle —
                      misleading you about the workload.
  Diagnostic hierarchy:
    1. ps -L / top -H            → identify hot TID(s) within the process
    2. /proc/<pid>/task/<tid>/comm → friendly name of the hot thread (if app
                                      sets it via prctl(PR_SET_NAME))
    3. /proc/<pid>/task/<tid>/stack → kernel stack (what syscall it's in)
    4. py-spy / pyflame / async-profiler / jstack → userspace call graph
       (language-specific; not always installed)
    5. perf top -p / perf record -p → kernel + userspace function-level
                                        flame data (gold standard, needs
                                        perf_event_paranoid permission)
  Aggregation pattern (no extra tools):
    for tid in /proc/<pid>/task/*; do
      utime=$(awk '{print $14+$15}' "$tid/stat")
      comm=$(cat "$tid/comm")
      printf "%10s  %s  %s\n" "$utime" "$(basename $tid)" "$comm"
    done | sort -k1 -rn | head
  Fix paths:
    (A) If runaway is the WORKLOAD (not a bug): scale horizontally, add
        a CPU limit, or move to async/IO-bound design.
    (B) If runaway is a BUG (infinite loop, deadlock with spinlock):
        identify the function via py-spy/perf, fix the code.
    (C) Quick mitigation: kill the process; auto-restart will run on the
        next request without the corrupted in-memory state.
  Validation:         pidstat -t shows the previously-hot TID drops to ~0%;
                      response latency recovers.
  Trade-off:          per-thread metrics need permission (perf needs
                      perf_event_paranoid <=2 or sudo). top -H always works.
                      Document the named-thread approach for your apps —
                      "I called prctl(PR_SET_NAME)" cuts diagnostic time
                      enormously when the symptom hits production.

  Reference: pnpm harness playbook methodology.fm.cpu-utilization-misleading
             pnpm harness ask "thread runaway investigation"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
