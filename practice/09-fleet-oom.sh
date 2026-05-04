#!/usr/bin/env bash
# Scenario: 10 containers running. ONE is OOMKilling repeatedly. Find it
#           WITHOUT inspecting each container 1-by-1. The skill: aggregation.
# Symptom:  fleet alerts say "memory pressure"; you don't know which container.
# Suggested: ha "find which container is OOMing in a fleet"
# Restore:  docker rm -f all domains-practice-fleet-*

set -uo pipefail
PREFIX="domains-practice-fleet-oom"
N_HEALTHY=9
BAD_INDEX=$(( RANDOM % (N_HEALTHY + 1) ))   # randomize which one is the offender

start() {
  command -v docker >/dev/null 2>&1 || { echo "[09] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[09] docker daemon unreachable"; exit 1; }

  # Tear down any prior run
  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done

  # Spin up N_HEALTHY+1 = 10 containers. All look identical from outside.
  # ONE has a tight memory limit + memory bomb → exits 137 every ~5s.
  echo "[09] spinning up $((N_HEALTHY+1)) containers, one of them is the offender..."
  for i in $(seq 0 "$N_HEALTHY"); do
    if [[ "$i" -eq "$BAD_INDEX" ]]; then
      docker run -d --name "${PREFIX}-svc-${i}" \
        --memory 40m --memory-swap 40m \
        --restart on-failure:20 \
        busybox sh -c 'tail -f /dev/zero | head -c 200000000 > /dev/null; sleep 3; exit 1' \
        >/dev/null
    else
      docker run -d --name "${PREFIX}-svc-${i}" \
        --memory 256m --memory-swap 256m \
        busybox sh -c 'while true; do sleep 60; done' \
        >/dev/null
    fi
  done

  # Let the offender cycle a few times so RestartCount is non-zero
  sleep 8

  cat <<EOF

Scenario:  Your alerting just paged: "high memory churn in the fleet". You
           have 10 service containers running with prefix "${PREFIX}-svc-".
           ONE of them is the culprit — it's OOMKilling every few seconds.
           The other 9 are fine.

           Don't inspect each container by hand. Aggregate.

What's true: 1 of 10 has --memory 40m + an allocator bomb. The other 9 have
             --memory 256m and just sleep. The bad one is restarting every
             ~5s. RestartCount is climbing.

Try (escalate from cheap aggregation to detailed per-container inspection):
  pnpm harness ask "find which container is OOMing in a fleet"

  # 1. Aggregate restart counts (cheapest signal)
  docker ps -a --filter "name=^${PREFIX}" \\
    --format '{{.Names}}\t{{.Status}}\t{{.RunningFor}}' | column -t

  # 2. Bulk inspect for OOMKilled flag
  docker inspect \$(docker ps -aq --filter "name=^${PREFIX}") \\
    --format '{{.Name}}\t{{.RestartCount}}\t{{.State.OOMKilled}}\t{{.State.ExitCode}}\t{{.HostConfig.Memory}}'

  # 3. Sort by RestartCount; the offender pops out
  docker inspect \$(docker ps -aq --filter "name=^${PREFIX}") \\
    --format '{{.RestartCount}}\t{{.Name}}\t{{.State.OOMKilled}}' | sort -rn | head -3

  # 4. Realtime view: docker stats (all at once, refresh)
  docker stats --no-stream --format 'table {{.Name}}\t{{.MemPerc}}\t{{.MemUsage}}'

  # 5. Kernel side aggregation
  dmesg -T | grep -i 'killed process' | tail -10

Expected aggregation reveals: ONE name in the prefix has RestartCount > 0,
OOMKilled=true, and Memory limit way smaller than its peers. That's the bug.

Reveal:    $0 reveal
Restore:   $0 restore (docker rm -f all 10)
Verify:    $0 verify
EOF
}

restore() {
  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  echo "[09] cleaned"
}

verify() {
  local n; n="$(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null | wc -l)"
  if [[ "$n" -gt 0 ]]; then
    echo "[09] $n container(s) still present. Run: $0 restore"
    return 1
  else
    echo "[09] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[09-fleet-oom] reveal:

  Failure mode id:    docker.fm.exit-137-oomkilled (single-container) +
                      methodology.fm.use-method-saturation-pass
                      (the meta-skill: find the outlier in a fleet)
  Why it happens:     1 of N containers has a much tighter memory limit than
                      its peers + a workload that exceeds the limit
  Signal hierarchy (from cheapest aggregation to most-targeted):
    1. RestartCount   — offender stands out (others are 0, it's 5+)
    2. OOMKilled flag — only true for the offender
    3. HostConfig.Memory — the tight limit is the smoking gun config diff
    4. docker stats   — realtime memory % gives you the live picture
    5. dmesg          — kernel-side OOM kill log with PID + RSS
  Aggregation pattern (the differentiator vs single-container debug):
    docker inspect $(docker ps -aq --filter "name=^prefix") \
      --format '{{.RestartCount}} {{.Name}} {{.State.OOMKilled}} {{.HostConfig.Memory}}' \
      | sort -rn | head -5
  Fix:                docker update --memory 256m <bad-container>
                      OR docker rm -f + docker run with proper limits
                      OR (production) fix the deploy template that set 40m
  Validation:         RestartCount stops climbing; OOMKilled→false next cycle
  Trade-off:          docker update doesn't restart — change applies on next
                      restart. For immediate effect: docker rm -f + recreate.
                      Don't bump limits without understanding why ONE container
                      has a different limit (could be intentional resource
                      partitioning).

  Reference: pnpm harness ask "OOMKilled in a fleet"
             pnpm harness playbook docker.fm.exit-137-oomkilled
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
