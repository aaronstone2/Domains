#!/usr/bin/env bash
# Scenario: A new process can't fork(). EAGAIN / "Resource temporarily
#           unavailable". Memory and disk are fine. The catch: per-uid
#           process limit (RLIMIT_NPROC) or system pid_max is exhausted.
# Symptom:  "fork: Resource temporarily unavailable" in app logs. shell
#           commands fail with the same. Looks like memory pressure but
#           free shows lots of RAM.
# Suggested: ha "fork resource temporarily unavailable"
# Restore:  kill the spawned children

set -uo pipefail
DIR="/tmp/domains-practice/17-pid"
PIDFILE="$DIR/spawner.pid"
TARGET_CHILDREN=600   # safe ceiling for a WSL session; doesn't approach pid_max

start() {
  command -v python3 >/dev/null 2>&1 || { echo "[17] needs python3"; exit 1; }
  mkdir -p "$DIR"

  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[17] spawner already running"
  else
    # Spawn TARGET_CHILDREN sleeping children. Each is a real process. Doesn't
    # fork-bomb to crash the host — bounded count. Children sleep so they
    # stay in the process table.
    setsid python3 -c "
import os, time, sys
TARGET = $TARGET_CHILDREN
for i in range(TARGET):
    pid = os.fork()
    if pid == 0:
        # child: sleep forever
        time.sleep(86400)
        os._exit(0)
# parent stays alive too so we can kill the whole tree
print(f'spawned {TARGET} children, parent pid={os.getpid()}', flush=True)
time.sleep(86400)
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 1.5  # let the children get into the process table
  fi

  cat <<EOF

Scenario:  Your app reports it can't fork() — "Resource temporarily
           unavailable" / EAGAIN. fork() doesn't usually fail on memory
           in modern kernels (overcommit handles that). What's left?
           Per-uid process count limit, or system-wide pid_max.

           Find:
           1. Current process count for your uid
           2. The applicable RLIMIT_NPROC for your shell / the failing process
           3. System-wide pid_max + currently used PIDs
           4. The fix (raise limit OR identify the runaway forker)

What's true: A python process spawned $TARGET_CHILDREN sleeping children
             under your uid. Total uid process count is now ~$((TARGET_CHILDREN+30))
             (your shell, this script, the python parent, $TARGET_CHILDREN sleepers).
             Not enough to actually exhaust pid_max on a real Linux box, but
             enough to investigate the diagnostic flow.

Try:       pnpm harness ask "fork resource temporarily unavailable"

  # 1. Count processes for your uid
  ps -u \$USER --no-headers | wc -l

  # 2. Find heavy spawners (who has lots of children?)
  ps -eo ppid --no-headers | sort -n | uniq -c | sort -rn | head -5
  # parent_pid_with_most_children: investigate
  PARENT=\$(ps -eo ppid --no-headers | sort -n | uniq -c | sort -rn | awk 'NR==1{print \$2}')
  ps -p \$PARENT -o pid,user,cmd 2>/dev/null

  # 3. RLIMIT_NPROC for your shell
  ulimit -u                                   # soft limit (interactive shell)
  cat /proc/\$\$/limits | grep processes      # actual rlimit for this shell

  # 4. RLIMIT_NPROC for an arbitrary process (e.g. the spawner's parent)
  cat /proc/$(cat "$PIDFILE")/limits | grep processes

  # 5. System-wide pid_max + current usage
  cat /proc/sys/kernel/pid_max
  ls /proc/[0-9]* | wc -l                     # total live PIDs across system

  # 6. Per-uid breakdown (who's using the most PIDs?)
  ps -eo user --no-headers | sort | uniq -c | sort -rn | head -5

  # 7. systemd cgroup pids.max (if running under systemd; cgroup v2)
  cat /sys/fs/cgroup/user.slice/user-\$(id -u).slice/pids.max 2>/dev/null
  cat /sys/fs/cgroup/user.slice/user-\$(id -u).slice/pids.current 2>/dev/null

Reveal:    $0 reveal
Restore:   $0 restore (kills the spawner + all $TARGET_CHILDREN children)
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$PIDFILE" ]]; then
    local parent; parent="$(cat "$PIDFILE")"
    # Kill the whole process group (setsid started it as a session leader)
    kill -- "-$parent" 2>/dev/null || true
    sleep 0.5
    kill -9 -- "-$parent" 2>/dev/null || true
    # Belt and suspenders: pkill any leftover children of the spawner
    pkill -9 -P "$parent" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[17] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    local n; n="$(pgrep -P "$(cat "$PIDFILE")" 2>/dev/null | wc -l)"
    echo "[17] spawner still running with $n children. Run: $0 restore"
    return 1
  else
    echo "[17] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[17-pid-limit] reveal:

  Failure mode id:    linux.fm.fork-eagain-pid-limit
                      (vs fork failing on memory — different EAGAIN cause;
                       memory ENOMEM is a different errno)
  Why it happens:     fork() returns -1 EAGAIN when one of:
                      (a) RLIMIT_NPROC: per-uid process count exceeds limit
                          (ulimit -u shows soft limit)
                      (b) /proc/sys/kernel/pid_max: system-wide PID space
                          exhausted (rare on 64-bit modern kernels)
                      (c) cgroup pids.max: cgroup-level cap (k8s, systemd
                          user-slice, container with --pids-limit)
                      (d) cgroups don't have enough memory for new task_struct
                          (rare; presents as EAGAIN too)
  Diagnostic flow:
    1. ps -u $USER | wc -l            → current uid process count
    2. ulimit -u   /  cat /proc/$$/limits | grep processes
                                       → the RLIMIT_NPROC ceiling
    3. /proc/sys/kernel/pid_max       → system-wide ceiling
    4. ls /proc/[0-9]* | wc -l        → system-wide live PIDs (vs pid_max)
    5. ps -eo user | sort | uniq -c | sort -rn
                                       → which uid is the heavy user
    6. ps -eo ppid | sort | uniq -c | sort -rn | head
                                       → which PARENT has the most children
                                          (catches runaway spawners)
    7. /sys/fs/cgroup/.../pids.{max,current}
                                       → cgroup-level limits (matters for
                                          containers with --pids-limit and
                                          systemd user-slice)
  Fix paths:
    (A) Raise the limit (immediate):
          ulimit -u 8192                         (current shell only, soft)
          sudo prlimit --pid <pid> --nproc=8192  (live process)
          edit /etc/security/limits.conf for persistent change
    (B) Identify the runaway forker (the right answer):
          ps -eo ppid | sort | uniq -c | sort -rn | head
        → The PID with hundreds of children is your bug. kill that parent
          and the kernel reaps the children.
    (C) For containers: docker run --pids-limit=512 caps fork bombs at the
        container level so they can't hurt the host
    (D) systemd: TasksMax= in unit file (default 80% of pids_max)
  Validation:         ps -u $USER | wc -l drops below the limit;
                      fork() in a fresh shell succeeds.
  Trade-off:          Raising pid_max system-wide costs nothing on 64-bit
                      kernels. Raising RLIMIT_NPROC for a runaway uid HIDES
                      the bug. Always pair "raise limit" with "find why this
                      uid is using so many processes" — the limit is a safety
                      net, not a config knob to keep widening.

  Reference: pnpm harness playbook linux.fm.fork-eagain-pid-limit
             pnpm harness ask "fork EAGAIN process limit"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
