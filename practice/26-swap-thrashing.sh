#!/usr/bin/env bash
# Scenario: System slowdown across the board. Memory shows almost-full
#           but not quite OOM. Swap is being heavily used. The kernel is
#           constantly paging in/out — "thrashing". Latency for every
#           process suffers.
# Symptom:  Everything slow. free -h shows swap heavily used. vmstat si/so
#           are high (continuous swap-in/swap-out). top %wa elevated.
# Suggested: ha "swap thrashing system slow"
# Restore:  kill the memory-pressure process(es)

set -uo pipefail
DIR="/tmp/domains-practice/26-swap"
PIDFILE="$DIR/balloon.pid"

start() {
  command -v python3 >/dev/null 2>&1 || { echo "[26] needs python3"; exit 1; }
  mkdir -p "$DIR"

  # Check swap is actually configured — WSL doesn't always have swap
  local swap_total
  swap_total="$(awk '/^SwapTotal/{print $2}' /proc/meminfo)"
  if [[ -z "$swap_total" || "$swap_total" -eq 0 ]]; then
    cat <<EOF
[26] WARNING: this system has no swap configured (SwapTotal=0).
     This scenario reads as a DOCS exercise on this box — there's no
     real swap to thrash. Read the diagnostic flow + reveal; the script
     still allocates a memory balloon you can investigate, but you
     won't see si/so activity.
EOF
  fi

  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[26] balloon already running"
  else
    # Allocate a ~600 MB balloon and access it in a loop so the kernel can't
    # just leave the pages cold (forces it to swap them back in). NOT enough
    # to OOM the system; enough to trigger swapping if swap exists.
    setsid python3 -c "
import time, os
buf = bytearray(600 * 1024 * 1024)  # 600 MB
print('balloon pid', os.getpid(), flush=True)
i = 0
while True:
    # Touch random pages — keeps pressure on the working set
    for j in range(0, len(buf), 4096):
        buf[j] = (i + j) & 0xff
    i += 1
    time.sleep(0.05)
" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 1
  fi

  cat <<EOF

Scenario:  Whole system feels sluggish. Multiple users complain. \`top\`
           doesn't show one runaway process at high CPU. \`free -h\`
           shows ~600 MB allocated to swap (or close to your swap total).
           Latency for everything is up — even ls.

           This is SWAP THRASHING. Memory pressure is forcing the kernel
           to page out cold pages to swap, but the active working set
           is bigger than RAM, so it has to page them back in immediately.
           Constant disk I/O for paging; no actual app progress.

           Find:
           1. Confirm it's swap thrashing (vs other slowdowns)
           2. Identify the process(es) responsible for the working set
           3. Decide: kill them? add RAM? tune swappiness?

What's true: A python balloon (pid=$(cat "$PIDFILE")) holds ~600 MB and
             accesses every page in a loop, forcing the kernel to either
             page it back in (if swapped) or block other allocs.

Try:       pnpm harness ask "swap thrashing system slow"

  # 1. Confirm swap is being used
  free -h
  cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Cached|Buffers'

  # 2. Confirm THRASHING — sustained si/so activity (not just one-time swap-out)
  vmstat 2 5
  # si = swap-in (kB/s);  so = swap-out (kB/s)
  # If both are non-zero across multiple samples → thrashing
  # If only so > 0 once and then stops → harmless; cold pages got paged out
  # If si > 0 sustained → working set > RAM (THE problem)

  # 3. Per-process swap usage — who's consuming the swap?
  for pid in /proc/[0-9]*; do
    p=\$(basename \$pid)
    swap_kb=\$(awk '/^VmSwap/{print \$2}' \$pid/status 2>/dev/null)
    [ -z "\$swap_kb" ] || [ "\$swap_kb" -eq 0 ] && continue
    cmd=\$(cat \$pid/comm 2>/dev/null)
    printf "%6s %12s %s\n" "\$p" "\$swap_kb" "\$cmd"
  done | sort -k2 -rn | head -10

  # 4. PSI (Pressure Stall Information) — modern kernel signal
  cat /proc/pressure/memory 2>/dev/null
  # 'some' line: any task waiting on memory; 'full' line: all tasks waiting
  # avg10 / avg60 / avg300 percentages over those windows

  # 5. Vmstat 'wa' column should also show high iowait during thrashing
  top -bn1 | head -3 | grep Cpu

  # 6. If using cgroup v2: per-cgroup memory pressure
  for cg in /sys/fs/cgroup/*/memory.pressure; do
    [ -r "\$cg" ] && echo "=== \$cg ===" && cat "\$cg"
  done 2>/dev/null | head -30

Reveal:    $0 reveal
Restore:   $0 restore (kills the balloon)
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
  echo "[26] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[26] still running. Run: $0 restore"
    return 1
  else
    echo "[26] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[26-swap-thrashing] reveal:

  Failure mode id:    linux.fm.swap-thrashing-working-set-exceeds-ram
                      (a less common but distinctive failure: NO process is
                       at 100% CPU, NO crash, but everything is slow because
                       the kernel is spending its time paging not running)
  Why it happens:     Active working set > available RAM. Kernel must keep
                      pages from many processes resident; with swap enabled,
                      it pages cold pages out to disk to make room. If the
                      "cold" pages turn out to be needed (as in our balloon
                      that touches every page), kernel pages them back in
                      → page out a different one → repeat. This is THRASHING.
                      Throughput collapses; no app gets meaningful CPU.

  Distinguishing thrashing from other slowdowns:
    Thrashing:  vmstat shows sustained si AND so > 0
                free -h shows swap heavily used
                /proc/pressure/memory 'some' avg10 > 50%
                disk i/o for the swap device is high
    OOM-bound:  free -h shows MemAvailable approaching 0 but no swap activity
                (might OOM-kill soon)
    iowait-bound: %wa high but si/so are 0 — different scenario (see fm 25)
    CPU-bound:  %us high; si/so are 0

  Diagnostic flow:
    1. free -h                          → confirm swap usage
    2. vmstat 2 5                       → si/so columns CONFIRM thrashing
    3. /proc/pressure/memory            → PSI metric (modern, accurate)
    4. /proc/<pid>/status VmSwap field  → per-process swap usage (find offender)
    5. /proc/<pid>/status VmRSS         → per-process RSS (find biggest)
    6. ps -eo pid,rss,vsz,comm --sort=-rss | head → biggest by RSS

  Fix paths:
    (A) IMMEDIATE — kill the largest unnecessary process to reclaim RAM:
          # find biggest non-critical
          ps -eo pid,rss,comm --sort=-rss | head
          kill <pid>
        Pages get freed; thrashing stops; system recovers in seconds.
    (B) Add swap (if you don't have any):
          sudo fallocate -l 4G /swapfile
          sudo chmod 600 /swapfile
          sudo mkswap /swapfile
          sudo swapon /swapfile
        BUT: more swap doesn't help thrashing if working set genuinely
        exceeds RAM. It just delays OOM. Real fix is more RAM or smaller WS.
    (C) Tune swappiness (controls eagerness to swap):
          # 0 = swap only when OOM imminent
          # 60 = default — moderately eager
          # 100 = swap aggressively
          echo 10 | sudo tee /proc/sys/vm/swappiness   # less eager
        Lower swappiness REDUCES preemptive swap-out, which can prevent
        thrashing in marginal cases. But if working set actually > RAM,
        you'll just OOM sooner.
    (D) Cgroup-level memory limits with `memory.swap.max=0`:
          per-container swap disable so one container can't drag the host
          into thrashing on behalf of everyone
    (E) Architectural: scale up the host (more RAM) or scale out (split
        the workload across N hosts). Real fix when working set is genuinely
        > what a single host can hold.

  Validation:         vmstat si/so return to 0; /proc/pressure/memory
                      'some' avg10 drops below 10%; latency recovers.

  Trade-off:          "Just turn off swap" (`swapoff -a`) is sometimes
                      proposed — DON'T. Without swap, the kernel can't
                      page out anonymous memory at all and OOM-killer
                      fires sooner / more aggressively. Swap is a
                      pressure-relief valve. Better: set swappiness=10,
                      keep swap small (1-2 GB), monitor PSI.

  Cross-domain:       k8s nodes traditionally had swap DISABLED entirely
                      because kubelet didn't account for it correctly. As
                      of k8s 1.22+ swap support is alpha/beta — you can
                      now enable it with --fail-swap-on=false. Read the
                      RELEASE NOTES for your version before enabling.

                      Container with no --memory limit on a thrashing host:
                      it WILL contribute to thrashing without being OOMed
                      itself. ALWAYS set memory limits.

  Reference: pnpm harness playbook linux.fm.swap-thrashing-working-set-exceeds-ram
             pnpm harness ask "swap thrashing"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
