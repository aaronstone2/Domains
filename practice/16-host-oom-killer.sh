#!/usr/bin/env bash
# Scenario: Host (not container) OOM-killer fired. dmesg shows it killed
#           a process. You need to: identify the victim, identify which
#           workload spike caused it, decide who to restart, find why
#           the OOM-killer chose this victim (oom_score_adj).
# Symptom:  "kernel: Out of memory: Killed process 12345 (java) total-vm:..."
#           in dmesg. Some process disappeared.
# Suggested: ha "kernel OOM killer fired"
# Restore:  kill the python balloons + remove dummy log

set -uo pipefail
DIR="/tmp/domains-practice/16-oomk"
P1FILE="$DIR/eater1.pid"
P2FILE="$DIR/eater2.pid"
LOGFILE="$DIR/fake-oom.log"

start() {
  command -v python3 >/dev/null 2>&1 || { echo "[16] needs python3"; exit 1; }
  mkdir -p "$DIR"

  # Don't actually trigger a real host OOM — that crashes WSL/dev env.
  # Instead: simulate the post-mortem. Allocate two memory-eaters that the
  # USER can investigate, AND inject a fake dmesg line into a log file the
  # user can grep (we can't actually write to dmesg without root + risk).

  if [[ -f "$P1FILE" ]] && kill -0 "$(cat "$P1FILE")" 2>/dev/null; then
    echo "[16] eaters already running"
  else
    setsid python3 -c "
import time, os
buf = bytearray(1 * 1024 * 1024 * 300)
print('eater1 pid', os.getpid(), flush=True)
time.sleep(86400)
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$P1FILE"

    setsid python3 -c "
import time, os
buf = bytearray(1 * 1024 * 1024 * 200)
print('eater2 pid', os.getpid(), flush=True)
time.sleep(86400)
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$P2FILE"
    sleep 0.5
  fi

  # Plant a "fake" dmesg-style log entry so the user can see what a real
  # host OOM kill looks like. Real dmesg contains lines like this verbatim.
  cat > "$LOGFILE" <<EOF
[$(date '+%a %b %d %H:%M:%S %Y')] Memory cgroup out of memory: Killed process $(cat $P1FILE) (python3) total-vm:307200kB, anon-rss:307140kB, file-rss:1024kB, shmem-rss:0kB
[$(date '+%a %b %d %H:%M:%S %Y')] oom_reaper: reaped process $(cat $P1FILE) (python3), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
[$(date '+%a %b %d %H:%M:%S %Y')] [pid] uid tgid total_vm rss pgtables_bytes swapents oom_score_adj name
[$(date '+%a %b %d %H:%M:%S %Y')] [$(cat $P1FILE)] 1000 $(cat $P1FILE) 76800 76785 798720 0 0 python3
[$(date '+%a %b %d %H:%M:%S %Y')] [$(cat $P2FILE)] 1000 $(cat $P2FILE) 51200 51185 532480 0 0 python3
EOF

  cat <<EOF

Scenario:  An alert says a python process disappeared. The simulated dmesg
           output is at $LOGFILE for you to investigate (in the real world
           you'd run \`sudo dmesg -T | tail -50\`). Two python processes are
           still running (pids in $P1FILE, $P2FILE) — this lets you practice
           the per-process oom_score / RSS investigation pattern.

           Find:
           1. Which process the kernel killed (from the dmesg-style log)
           2. Why the kernel chose that one (oom_score_adj, RSS, etc.)
           3. Which process(es) are NEXT to be killed if memory pressure
              continues — and how to reprioritize

What's true: Two python processes ($(cat $P1FILE) and $(cat $P2FILE)) are
             holding 300 MB and 200 MB respectively. The fake dmesg shows
             the larger one was "killed". Both are still actually running
             so you can do live investigation.

Try (in the real interview-day case, replace $LOGFILE with `sudo dmesg -T`):
  pnpm harness ask "kernel OOM killer fired"

  # 1. Read the kernel's account of what happened
  cat $LOGFILE
  # In the real world: sudo dmesg -T --level=err,crit,alert | grep -iE 'oom|killed'

  # 2. Per-process oom_score (current snapshot — who's NEXT)
  for pid in $(cat $P1FILE) $(cat $P2FILE); do
    cmd=\$(cat /proc/\$pid/comm 2>/dev/null)
    score=\$(cat /proc/\$pid/oom_score 2>/dev/null)
    adj=\$(cat /proc/\$pid/oom_score_adj 2>/dev/null)
    rss_kb=\$(awk '/VmRSS/{print \$2}' /proc/\$pid/status 2>/dev/null)
    printf "pid=%-6s comm=%-15s oom_score=%-5s oom_score_adj=%-5s rss=%s kB\n" \\
      "\$pid" "\$cmd" "\$score" "\$adj" "\$rss_kb"
  done

  # 3. System-wide ranking — the kernel's view of who'd be killed next
  ps -eo pid,user,rss,vsz,oom_score=OOMSCORE,oom_score_adj=OOMADJ,comm --sort=-rss | head -10

  # 4. Memory situation (was OOM justified?)
  free -h
  cat /proc/meminfo | head -10
  cat /proc/sys/vm/overcommit_memory   # 0=heuristic, 1=always, 2=strict

  # 5. Any cgroup-level memory state (container OOM vs host OOM is different)
  ls /sys/fs/cgroup/memory.events 2>/dev/null && \\
    cat /sys/fs/cgroup/memory.events
  # cgroup v2 — oom_kill counter at memory.events.local

Reveal:    $0 reveal
Restore:   $0 restore (kills both pythons + removes log)
Verify:    $0 verify
EOF
}

restore() {
  for f in "$P1FILE" "$P2FILE"; do
    if [[ -f "$f" ]]; then
      kill "$(cat "$f")" 2>/dev/null || true
      sleep 0.2
      kill -9 "$(cat "$f")" 2>/dev/null || true
      rm -f "$f"
    fi
  done
  rm -rf "$DIR"
  echo "[16] cleaned"
}

verify() {
  for f in "$P1FILE" "$P2FILE"; do
    if [[ -f "$f" ]] && kill -0 "$(cat "$f")" 2>/dev/null; then
      echo "[16] still running. Run: $0 restore"
      return 1
    fi
  done
  echo "[16] clean"
  return 0
}

reveal() {
  cat <<'EOF'
[16-host-oom-killer] reveal:

  Failure mode id:    linux.fm.host-oom-killer-fired
                      (vs cgroup OOM, which is fm.exit-137-oomkilled — DIFFERENT
                       mechanism: cgroup OOM only kills processes inside a
                       cgroup that exceeded its limit; host OOM kicks in when
                       the entire host runs out of memory)
  Why it happens:     Total host RSS approaches RAM + swap. Kernel needs to
                      free memory NOW. Picks a victim by oom_score, sends SIGKILL.
                      The killed process can be ANY userspace process — not
                      necessarily the one that "caused" the pressure.
  Distinguishing host vs cgroup OOM:
    HOST:   dmesg "Out of memory: Killed process ..." (no cgroup mention)
            free -h shows MemAvailable near 0
            /proc/sys/vm/overcommit_memory state matters
    CGROUP: dmesg "Memory cgroup out of memory: Killed process ..."
            container had memory limit, container State.OOMKilled=true
            host MemAvailable might be plenty
  oom_score breakdown (man 5 proc):
    Calculated from RSS, swap usage, runtime, oom_score_adj.
    Range: 0 (immune) to 1000 (kill first).
    Default for normal processes: 0
    Adjustable: echo -1000 > /proc/<pid>/oom_score_adj  (immune)
                echo  1000 > /proc/<pid>/oom_score_adj  (kill first)
  Diagnostic flow:
    1. dmesg | grep -iE 'oom|killed'        → which process, when, RSS
    2. /proc/<pid>/oom_score                → current ranking of survivors
    3. ps -eo ...,oom_score=,oom_score_adj=,rss --sort=-rss | head
                                              → who's next
    4. free -h + /proc/meminfo               → was the host actually under
                                                pressure, or was this an
                                                outlier kill?
    5. /proc/sys/vm/overcommit_memory        → check overcommit policy
    6. dmesg "page allocation failure"       → fragmentation OOM (different
                                                from RSS OOM — needs higher
                                                vm.min_free_kbytes)
  Fix paths:
    (A) Add memory: scale up the host or add swap (sudo swapon /path/to/file)
    (B) Reduce demand: kill or right-size the largest workload
    (C) Reprioritize: protect critical processes
          echo -500 > /proc/<critical-pid>/oom_score_adj
        Or for systemd units: OOMScoreAdjust= in the unit file
    (D) Per-cgroup limits: containerize memory-hungry workloads with
        explicit --memory limits so cgroup OOM hits THEM, not host OOM
    (E) Cgroup v2 oom.group: if any process in the cgroup is OOMed, kill
        ALL of them (avoids zombie state where one of N siblings dies)
  Validation:         New dmesg has no OOM events for >10 min;
                      free -h MemAvailable stays >10% of total
  Trade-off:          oom_score_adj=-1000 means "kill the kernel first
                      before this process". Use sparingly — overusing it
                      means OOM ends up killing important things by elimination.

  Reference: pnpm harness playbook linux.fm.host-oom-killer-fired
             pnpm harness ask "OOM kill investigation"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
