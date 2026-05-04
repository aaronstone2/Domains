#!/usr/bin/env bash
# Scenario: App is slow. CPU shows low. Disk fills aren't a problem (df is
#           fine). But disk I/O is saturated — process is iowait-bound.
#           Find the offending process + what it's doing.
# Symptom:  Latency spikes; top shows %wa (iowait) elevated; %us is low.
# Suggested: ha "process slow disk iowait"
# Restore:  kill the writer

set -uo pipefail
DIR="/tmp/domains-practice/25-iowait"
PIDFILE="$DIR/writer.pid"

start() {
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[25] writer already running"
  else
    # Write 200MB chunks repeatedly with fsync. Floods disk I/O without
    # filling the disk (we delete after each write).
    setsid bash -c '
while true; do
  dd if=/dev/zero of=/tmp/domains-practice/25-iowait/blob bs=1M count=200 conv=fsync 2>/dev/null
  sync
  rm -f /tmp/domains-practice/25-iowait/blob
done
' > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 2
  fi

  cat <<EOF

Scenario:  App latency spiked from 50ms p99 to 800ms. \`top\` shows the
           app's process at low %CPU. But \`top\` shows %wa (iowait) at
           30%+ — meaning processes are blocking on disk I/O. Disk isn't
           full (\`df -h\` is fine). What's flooding the disk?

           Find:
           1. Confirm iowait is the bottleneck (vs CPU vs memory)
           2. Identify the offending process (writer or reader?)
           3. Quantify the I/O rate per process
           4. Decide the fix (rate-limit, scheduling class, hardware)

What's true: A bash loop is dd-ing 200MB chunks of /dev/zero with fsync,
             over and over, into /tmp. The actual app's I/O gets queued
             behind it. Pid: $(cat "$PIDFILE").

Try:       pnpm harness ask "process slow disk iowait"

  # 1. Confirm iowait is HIGH (vs us/sy/id)
  vmstat 1 5            # 'wa' column = iowait %; 'b' column = blocked procs
  top -bn1 | head -3    # Cpu(s) line shows %us %sy %id %wa

  # 2. Per-disk I/O — which device is saturated?
  iostat -xz 1 3        # %util near 100% = saturated; await = ms per IO
  # OR if iostat not installed:
  cat /proc/diskstats | head

  # 3. Per-PROCESS I/O — find the offender
  sudo iotop -b -n 1 -o     # only processes doing I/O; needs sudo
  # OR pidstat:
  pidstat -d 1 3           # disk I/O per pid; rkB/s wkB/s

  # 4. /proc-only fallback (no extra tools)
  for pid in /proc/[0-9]*; do
    p=\$(basename \$pid)
    [ -r \$pid/io ] || continue
    rb=\$(awk '/^read_bytes/{print \$2}' \$pid/io 2>/dev/null)
    wb=\$(awk '/^write_bytes/{print \$2}' \$pid/io 2>/dev/null)
    [ -z "\$rb" ] && continue
    cmd=\$(cat \$pid/comm 2>/dev/null)
    printf "%6s %12s %12s %s\n" "\$p" "\$rb" "\$wb" "\$cmd"
  done | sort -k3 -rn | head -10

  # 5. What FILES is the offender writing? (lsof + /proc/<pid>/fd)
  sudo lsof -p $(cat "$PIDFILE") 2>/dev/null | head
  ls -l /proc/$(cat "$PIDFILE")/fd/ | head

  # 6. Filesystem-level: is it sync-heavy? (the killer for SSD wear + latency)
  # strace shows fsync/fdatasync calls
  sudo strace -p $(cat "$PIDFILE") -e trace=fsync,fdatasync,sync,write -c &
  sleep 3
  sudo pkill -INT strace 2>/dev/null   # SIGINT prints summary

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
    pkill -P "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[25] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[25] still running. Run: $0 restore"
    return 1
  else
    echo "[25] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[25-slow-disk-io] reveal:

  Failure mode id:    linux.fm.iowait-saturation +
                      linux.fm.disk-io-noisy-neighbor
                      (the corollary to "container slow CPU low" but at the
                       BLOCK layer instead of cgroup-CPU layer)
  Why it happens:     Disk has finite IOPS + bandwidth. One process
                      generating sustained writes (especially with fsync
                      forcing flushes) saturates the device. Other processes'
                      I/O queues behind it; their syscalls block, contributing
                      to %iowait. CPU may be 0% busy because everyone is
                      WAITING for disk.

  USE method on disk (this is the canonical interview answer):
    Utilization: %util from `iostat -xz 1`            → near 100% = saturated
    Saturation:  await (ms/IO) and aqu-sz from iostat → high = queue building
    Errors:      `dmesg | grep -i 'I/O error'`        → hardware issue

  Diagnostic flow:
    1. vmstat 1                       → confirm wa% is high (vs us/sy)
                                          confirm 'b' (blocked) > 0
    2. iostat -xz 1                   → per-device %util + await + r/w rate
    3. iotop -b -n 1 -o               → per-process I/O — the offender
       (or: pidstat -d 1 3)
    4. /proc/<pid>/io                 → r/w bytes for any pid (no extra tool)
    5. lsof -p <pid> + /proc/<pid>/fd → what FILES the offender is writing
    6. strace -e trace=fsync,sync,write -c -p <pid>
                                       → syscall histogram. Lots of fsync
                                          = sync-heavy workload. Lots of
                                          O_DIRECT writes = bypassing cache.

  Common causes:
    - Database doing checkpoints / log flushes (legitimate; rate-limit)
    - log-rotate compressing huge log files
    - backup/snapshot job (cron, AWS Backup, restic) running mid-day
    - app code that fsync()s on every operation (over-cautious)
    - Docker pull writing image layers
    - VM live-migration page-write-back

  Fix paths:
    (A) Rate-limit the offender:
          ionice -c 3 -p <pid>           # idle I/O class — yields to others
          ionice -c 2 -n 7 -p <pid>      # best-effort, lowest priority
          For containers: --device-write-bps=/dev/sda:10mb
    (B) Architectural — move the workload to its own disk:
          symlink the heavy workload's data dir to a different mount
          (e.g. backup goes to a separate volume)
    (C) Reduce sync frequency (if app code is over-syncing):
          fsync per-batch instead of per-write
          O_DSYNC instead of O_SYNC (writes data, not metadata)
          Use writeback cache mode if durability allows
    (D) Hardware — upgrade to NVMe / add more spindles / add SSD cache layer
    (E) For databases: tune commit_interval, wal_segment_size, etc.

  Validation:         iostat %util drops below 80%; app latency p99 recovers
                      to baseline; vmstat 'wa' returns to normal (<5%).

  Trade-off:          ionice only works on CFQ I/O scheduler (or BFQ).
                      Modern kernels often use noop/deadline/none on SSDs
                      where ionice is a no-op. Check `cat /sys/block/<dev>/queue/scheduler`.
                      Container --device-write-bps DOES work regardless,
                      via cgroup blkio controller.

  Cross-domain:       k8s pods can have spec.containers[].resources.limits
                      for ephemeral-storage but NOT for I/O bandwidth in
                      vanilla k8s. Use a runtimeClass or the io-aware
                      scheduling extender for that. Devin DevBoxes share
                      a host disk — heavy I/O in one session affects others
                      unless cgroup blkio limits are applied.

  Reference: pnpm harness playbook linux.fm.iowait-saturation
             pnpm harness ask "process slow disk iowait"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
