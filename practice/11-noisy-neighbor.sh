#!/usr/bin/env bash
# Scenario: 6 containers running. Disk usage on /var/lib/docker climbing fast.
#           ONE container is responsible (logs blowing up). Find it via
#           per-container disk/log aggregation, not "rm -rf everything".
# Symptom:  Operator: "/var/lib/docker grew 2 GB in 5 min, going to fill the host"
# Suggested: ha "container filling disk find which"
# Restore:  docker rm -f all domains-practice-noisy-*

set -uo pipefail
PREFIX="domains-practice-noisy"
N_QUIET=5

start() {
  command -v docker >/dev/null 2>&1 || { echo "[11] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[11] docker daemon unreachable"; exit 1; }

  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done

  echo "[11] spinning up $((N_QUIET+1)) containers, ONE is a noisy neighbor..."
  # Quiet neighbors: idle, write nothing
  for i in $(seq 0 "$((N_QUIET-1))"); do
    docker run -d --name "${PREFIX}-quiet-${i}" \
      --label tier=worker \
      busybox sh -c 'while true; do sleep 60; done' \
      >/dev/null
  done

  # Noisy one: logs as fast as it can
  docker run -d --name "${PREFIX}-noisy" \
    --label tier=worker \
    busybox sh -c 'i=0; while true; do echo "$(date) [worker] verbose request log entry id=$i payload=$(printf x%.0s {1..200})"; i=$((i+1)); done' \
    >/dev/null

  echo "[11] letting noisy log accumulate ~10s..."
  sleep 10

  cat <<EOF

Scenario:  /var/lib/docker is filling fast. Operator paged: "we'll be at
           90% disk in 30 min". You have 6 worker containers running with
           prefix "${PREFIX}-". ALL look "Up Xm" in docker ps; all are
           tagged tier=worker. ONE is dumping a stupid amount of log to
           stdout, which docker captures as JSON log files.

           Don't 'docker rm -f' everything. Find the offender SPECIFICALLY
           by aggregating per-container log size on disk.

What's true: 5 are quiet (no output). 1 is logging an ID + 200-byte payload
             as fast as it can. Its on-disk JSON log file is huge and growing.

Try (aggregation across the fleet):
  pnpm harness ask "container filling disk via logs"

  # 1. List per-container log file size (the smoking gun)
  for c in \$(docker ps -aq --filter "label=tier=worker"); do
    name=\$(docker inspect "\$c" --format '{{.Name}}')
    logf=\$(docker inspect "\$c" --format '{{.LogPath}}')
    sz=\$(sudo du -h "\$logf" 2>/dev/null | cut -f1)
    echo "\$sz \$name"
  done | sort -h | tail -3

  # 2. Per-container log line rate (last 5s)
  for c in \$(docker ps -aq --filter "label=tier=worker"); do
    name=\$(docker inspect "\$c" --format '{{.Name}}')
    n=\$(docker logs --since 5s "\$c" 2>&1 | wc -l)
    echo "\$n \$name"
  done | sort -rn | head -3

  # 3. Total docker overlay/storage usage (the big-picture context)
  docker system df -v | head -30

  # 4. /var/lib/docker breakdown (host-side view)
  sudo du -sh /var/lib/docker/* 2>/dev/null | sort -h | tail
  sudo du -sh /var/lib/docker/containers/* 2>/dev/null | sort -h | tail

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  echo "[11] cleaned"
}

verify() {
  local n; n="$(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null | wc -l)"
  if [[ "$n" -gt 0 ]]; then
    echo "[11] $n container(s) still present. Run: $0 restore"
    return 1
  else
    echo "[11] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[11-noisy-neighbor] reveal:

  Failure mode id:    docker.fm.disk-full-overlay2-leaked +
                      docker.fm.unbounded-log-driver-default
                      (the host-disk-pressure family)
  Why it happens:     default `json-file` log driver has no size cap. ONE
                      verbose container can fill the host disk while siblings
                      stay tiny. Multiplies fast in container fleets where
                      one app's log verbosity got cranked up by mistake.
  Signal hierarchy:
    1. /var/lib/docker/containers/<id>/<id>-json.log per-container file size
       — the offender's file is orders of magnitude larger than peers
    2. Per-container log line rate (docker logs --since 5s | wc -l)
       — direct measure of who's noisy NOW
    3. docker system df -v        — system-level breakdown by container
    4. /var/lib/docker/overlay2 size — only relevant if writes-into-FS
                                       (vs just stdout logs)
  Aggregation patterns:
    # File sizes (most accurate for log-driver issue):
    for c in $(docker ps -aq); do
      name=$(docker inspect "$c" --format '{{.Name}}')
      sz=$(sudo du -B1 "$(docker inspect "$c" --format '{{.LogPath}}')" 2>/dev/null | cut -f1)
      printf "%15s %s\n" "$sz" "$name"
    done | sort -rn | head

    # Log rate (catches it live):
    for c in $(docker ps -aq); do
      n=$(docker logs --since 10s "$c" 2>&1 | wc -l)
      printf "%5d %s\n" "$n" "$(docker inspect $c --format '{{.Name}}')"
    done | sort -rn | head
  Fix paths:
    (A) Truncate the runaway log NOW (frees disk):
          sudo truncate -s 0 $(docker inspect <name> --format '{{.LogPath}}')
        OR docker rm -f + recreate (loses ALL its history including good).
    (B) Per-container cap so it can't recur:
          --log-opt max-size=10m --log-opt max-file=3
    (C) Daemon-wide default in /etc/docker/daemon.json:
          {"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}
        Then sudo systemctl restart docker (existing containers keep old config
        until recreated).
    (D) For real fleets: switch to a centralized log driver (journald, fluentd,
        awslogs) so logs don't accumulate on the local disk at all.
  Validation:         File size of the offender stops growing; df -h on
                      /var/lib/docker stabilizes.
  Trade-off:          Truncating loses log history (might lose evidence the
                      app team needs). Always prefer the cap + recreate
                      approach when you have time. Truncate is for "we're
                      about to fill the disk in 5 min" emergencies.

  Reference: pnpm harness ask "container filling disk"
             pnpm harness playbook docker.fm.disk-full-overlay2-leaked
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
