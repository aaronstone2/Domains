#!/usr/bin/env bash
# Scenario: Container is "slow" but `top` on the host shows low CPU. Looks
#           idle. The catch: cgroup CPU quota is being THROTTLED — the
#           workload IS working but only allowed to run X% of the time.
#           Classic Devin/DevBox failure mode.
# Symptom:  Latency spikes, request queue building, but `top` shows the box
#           has plenty of CPU available.
# Suggested: ha "container slow but cpu shows low"
# Restore:  docker rm -f the container

set -uo pipefail
NAME="domains-practice-throttled"

start() {
  command -v docker >/dev/null 2>&1 || { echo "[15] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[15] docker daemon unreachable"; exit 1; }
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # CPU-hungry workload constrained to 0.2 CPU. The workload tries to use
  # MORE — cgroup throttles it. Looks "slow" but isn't crashing.
  docker run -d --name "$NAME" \
    --cpus="0.2" \
    busybox sh -c '
i=0
while true; do
  # CPU-bound spin
  j=0
  while [ $j -lt 100000 ]; do
    j=$((j+1))
  done
  i=$((i+1))
  if [ $((i % 10)) -eq 0 ]; then
    echo "completed $i batches at $(date)"
  fi
done
' >/dev/null

  echo "[15] container started; workload is CPU-bound but quota-limited..."
  sleep 8

  cat <<EOF

Scenario:  Container "$NAME" is "slow" — operator says request latency went
           from 50ms to 800ms. \`top\` on the host shows the box at 12% CPU.
           Lots of headroom. So why is it slow?

           This is the classic "low CPU usage but throttled" pattern. The
           process IS running — at 100% of its allowed slice. But the cgroup
           CPU quota only lets it use a fraction of one core.

           Find:
           1. The cgroup CPU quota (config)
           2. Throttle event count + duration (current state)
           3. The right fix (raise quota, or rightsize the workload)

What's true: Container has --cpus="0.2" which sets cpu.max to 20000 100000
             (20 ms per 100 ms period = 20% of one core). Workload is
             CPU-bound bash; it gets throttled aggressively.

Try:       pnpm harness ask "container slow but cpu shows low"

  # 1. Confirm the cgroup CPU quota for the container
  docker inspect $NAME --format '{{.HostConfig.NanoCpus}} ns/period={{.HostConfig.CpuPeriod}} quota={{.HostConfig.CpuQuota}}'

  # 2. THE smoking gun: cpu.stat in the container's cgroup — nr_throttled
  CG=\$(docker inspect $NAME --format '{{.HostConfig.CgroupParent}}/{{.Id}}')
  # cgroup v2 path
  sudo cat /sys/fs/cgroup/system.slice/docker-$(docker inspect $NAME --format '{{.Id}}').scope/cpu.stat 2>/dev/null
  # cgroup v1 path (older)
  sudo cat /sys/fs/cgroup/cpu,cpuacct/docker/$(docker inspect $NAME --format '{{.Id}}')/cpu.stat 2>/dev/null

  # 3. docker stats real-time view (CPU% capped at the quota)
  docker stats --no-stream $NAME

  # 4. Cross-check: top -H -p <pid> shows the process pegged at 100% of
  #    its allowed slice (% of one core, capped by quota)
  PID=\$(docker inspect $NAME --format '{{.State.Pid}}')
  ps -p \$PID -o pid,pcpu,pmem,nlwp,cmd

  # 5. Look at the throttling delta over time (best signal)
  # Run twice 5s apart; nr_throttled and throttled_usec should be increasing
  # if the workload is being throttled NOW.

Key insight: the metric you want is throttled_usec / period_usec, NOT
             %CPU at the host level. Container CAN be slow while host CPU
             is idle — they're at DIFFERENT cgroup levels.

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "[15] cleaned"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[15] container $NAME still exists. Run: $0 restore"
    return 1
  else
    echo "[15] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[15-cpu-throttled] reveal:

  Failure mode id:    methodology.fm.cpu-utilization-misleading +
                      docker.fm.cpu-throttle-cgroup-quota
                      (the corollary to fm 14: not just multi-thread aggregation
                       hides things, cgroup-level CPU constraints DO too)
  Why it happens:     Linux cgroup CPU controller sets quota = ratio of
                      cpu.max / cpu.period. If a process tries to use more
                      than its slice, the kernel parks it (throttles) until
                      the next period. Process IS running — just sleeping
                      between work bursts. From outside it looks slow but
                      "uses no CPU".
  Diagnostic hierarchy:
    1. docker inspect HostConfig.CpuQuota / CpuPeriod / NanoCpus → the limit
    2. /sys/fs/cgroup/<scope>/cpu.stat → nr_throttled (count) +
                                           throttled_usec (cumulative time
                                           parked). If these grow over a 5s
                                           sample window, you're throttled NOW.
    3. docker stats CPU%             → caps at the quota (not host %)
    4. process %CPU at host top      → looks low because container is parked
                                          for chunks of each 100ms period
  Cgroup paths (matters which version):
    cgroup v2: /sys/fs/cgroup/system.slice/docker-<id>.scope/cpu.stat
    cgroup v1: /sys/fs/cgroup/cpu,cpuacct/docker/<id>/cpu.stat
    Check which is in use: stat -fc %T /sys/fs/cgroup
                           (cgroup2fs = v2, tmpfs = v1)
  Fix paths:
    (A) Raise the quota (immediate):
          docker update --cpus 1.0 <name>
        applies on next process schedule; no restart needed.
    (B) Right-size based on actual demand:
          measure usage with cAdvisor / prom over a representative window;
          set --cpus to peak * 1.3 headroom.
    (C) Architectural: if the workload is genuinely CPU-bound, scale out
          (more replicas with smaller quota) rather than scale up one big one.
  Validation:         /sys/fs/cgroup/.../cpu.stat shows nr_throttled stops
                      growing; latency recovers.
  Trade-off:          Raising --cpus uses more host capacity, can starve
                      neighbors. Better: pair with cpu.weight (cgroup v2)
                      so latency-sensitive workloads get priority on
                      contention without uncapped quota.
  Cross-domain:       Same in k8s — `resources.limits.cpu` becomes the cgroup
                      quota. Diagnose via `kubectl top pod` (only sees
                      USED, not throttle %); the truth is in the cgroup
                      cpu.stat file inside the node, not in metrics-server.
                      For Devin DevBox: each session may have its own cpu
                      quota; if your agent feels slow but DevBox shows low
                      load, this is THE first thing to check.

  Reference: pnpm harness playbook methodology.fm.cpu-utilization-misleading
             pnpm harness ask "container slow CPU low throttle"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
