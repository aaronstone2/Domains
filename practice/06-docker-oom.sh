#!/usr/bin/env bash
# Scenario: A container exits with code 137 (OOMKilled) every 30s.
# Symptom:  `docker ps -a` shows it Exited (137); `docker inspect` confirms OOMKilled=true.
# Suggested:`ha "OOMKilled in container"` or `ha "exit 137"`
# Restore:  docker rm -f the container

set -uo pipefail
NAME="domains-practice-oom"

start() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[06-docker-oom] needs docker — install Docker Desktop with WSL integration"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[06-docker-oom] docker daemon not reachable — start Docker Desktop"
    exit 1
  fi

  # Tear down any prior run
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # Allocate a 50MB-limited container that tries to allocate 200MB → OOM-killed.
  # Use --restart=on-failure:5 so it stays in a loop and you can observe it.
  docker run -d \
    --name "$NAME" \
    --memory 50m \
    --memory-swap 50m \
    --restart on-failure:5 \
    busybox sh -c 'tail -f /dev/zero | head -c 200000000 > /dev/null; sleep 5; exit 1' \
    >/dev/null

  cat <<EOF

Scenario:  A container named "$NAME" keeps dying with exit 137 (OOMKilled)
           every few seconds. Figure out:
           1. WHY it's exiting 137 (cheap diagnostic first)
           2. WHAT memory limit is set
           3. The right FIX (raise limit? fix the workload?)

Try:       \`pnpm harness ask "OOMKilled in container"\`  (most direct)
           \`docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}'\`
           \`docker inspect $NAME --format '{{.State.OOMKilled}} exit={{.State.ExitCode}}'\`
           \`docker inspect $NAME --format 'limit={{.HostConfig.Memory}}'\`
           \`dmesg -T 2>/dev/null | grep -i 'killed process' | tail\`
           \`docker stats --no-stream $NAME\`

Reveal:    $0 reveal
Restore:   $0 restore (docker rm -f)
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "[06-docker-oom] cleaned"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[06-docker-oom] container $NAME still exists. Run: $0 restore"
    return 1
  else
    echo "[06-docker-oom] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[06-docker-oom] reveal:

  Failure mode id:    docker.fm.exit-137-oomkilled  (also k8s.fm.oomkilled)
  Why it happens:     container's memory cgroup hit its limit; kernel SIGKILLed
                      the process; container exited with code 128+9=137
  Diagnostic:         docker inspect <name> --format '{{.State.OOMKilled}}'  → true
                      docker inspect <name> --format '{{.State.ExitCode}}'   → 137
                      docker inspect <name> --format '{{.HostConfig.Memory}}'→ bytes
                      dmesg -T | grep 'killed process'                       → kernel log
                      cat /sys/fs/cgroup/memory/docker/<id>/memory.events    → oom_kill counter
  Fix paths:
    (A) Raise the limit:  docker update --memory 200m --memory-swap 200m <name>
    (B) Fix the workload: identify leak/spike; cap heap; lower concurrency
    (C) For Java:         JAVA_TOOL_OPTIONS='-XX:MaxRAMPercentage=60.0 -XX:+UseContainerSupport'
  Validation:        docker logs <name> shows continued operation; OOMKilled stays false
                     docker stats <name> shows memory < limit
  Trade-off:         Raising limit hides a real leak; fixing the workload is harder
                     but correct. ALWAYS state both options to the interviewer.

  Reference: pnpm harness playbook docker.fm.exit-137-oomkilled
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
