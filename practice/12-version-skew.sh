#!/usr/bin/env bash
# Scenario: 6 containers running. They look identical — same name prefix, same
#           role, all "Up". But ONE is running an outdated image (pinned to a
#           buggy old tag). Users see intermittent failures from "1 in 6"
#           requests. Find the misversioned outlier via inspect aggregation.
# Symptom:  ~16% of API calls return 500. Pattern looks like "stuck in load
#           balancer rotation talking to one bad backend".
# Suggested: ha "find container with wrong image version"
# Restore:  docker rm -f all domains-practice-skew-*

set -uo pipefail
PREFIX="domains-practice-skew"

start() {
  command -v docker >/dev/null 2>&1 || { echo "[12] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[12] docker daemon unreachable"; exit 1; }

  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done

  # Pull both image versions if not cached
  echo "[12] pulling images (busybox:latest + busybox:1.31)..."
  docker pull -q busybox:latest >/dev/null
  docker pull -q busybox:1.31 >/dev/null

  echo "[12] spinning up 6 backend containers..."
  # Containers 0..4: latest. Container 5: pinned old version (the bug).
  for i in 0 1 2 3 4; do
    docker run -d --name "${PREFIX}-backend-${i}" \
      --label app.role=backend \
      --label app.tier=prod \
      busybox:latest sh -c 'while true; do sleep 60; done' \
      >/dev/null
  done
  docker run -d --name "${PREFIX}-backend-5" \
    --label app.role=backend \
    --label app.tier=prod \
    busybox:1.31 sh -c 'while true; do sleep 60; done' \
    >/dev/null

  cat <<EOF

Scenario:  Users report 1-in-6 API requests fail with HTTP 500. The
           load balancer fronts 6 backend containers. None of them is
           "down" — docker ps shows all 6 Up. So which one is busted?

           This is the classic "version skew in the fleet" — somebody
           deployed an older image to one slot during a bad rollout.

           Find the misversioned container WITHOUT 'docker exec'-ing into
           each one to ask its version.

What's true: 5 of 6 backends run busybox:latest. 1 of 6 runs busybox:1.31
             (pinned old version). Same name prefix, same labels, same
             role. The image tag is the only difference.

Try (the right tool here is docker inspect with template/jq aggregation):
  pnpm harness ask "find container with wrong image version"

  # 1. Quick aggregation: image per container in the fleet
  docker inspect \$(docker ps -aq --filter "label=app.role=backend") \\
    --format '{{.Name}}\t{{.Config.Image}}' | column -t

  # 2. Group by image tag (the outlier reveals itself)
  docker inspect \$(docker ps -aq --filter "label=app.role=backend") \\
    --format '{{.Config.Image}}' | sort | uniq -c | sort -rn

  # 3. With image digests (catches "same tag, different digest" — pull-time skew)
  docker inspect \$(docker ps -aq --filter "label=app.role=backend") \\
    --format '{{.Config.Image}}\t{{.Image}}\t{{.Name}}' \\
    | sort | uniq -c | head

  # 4. With JSON for richer querying:
  docker inspect \$(docker ps -aq --filter "label=app.role=backend") \\
    | jq -r '.[] | "\(.Config.Image)\t\(.Name)"' | sort -k1

  # 5. Compare against the "correct" image (what the deploy SHOULD have set):
  EXPECTED=busybox:latest
  docker inspect \$(docker ps -aq --filter "label=app.role=backend") \\
    --format '{{.Name}}\t{{.Config.Image}}' \\
    | awk -v exp="\$EXPECTED" '\$2 != exp {print "DRIFT:", \$0}'

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  echo "[12] cleaned"
}

verify() {
  local n; n="$(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null | wc -l)"
  if [[ "$n" -gt 0 ]]; then
    echo "[12] $n container(s) still present. Run: $0 restore"
    return 1
  else
    echo "[12] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[12-version-skew] reveal:

  Failure mode id:    docker.fm.deploy-version-skew (the
                      "intermittent failure on 1-in-N requests" pattern is
                      almost always: load-balanced rotation hitting one
                      bad replica)
  Why it happens:     a deploy partially succeeded — N-1 instances rolled
                      to the new image, 1 instance got skipped (or the
                      orchestrator crashed mid-rollout). The bad replica
                      has the old behavior. From outside it's "Up".
  Signal hierarchy (cheapest first):
    1. docker inspect --format Config.Image           — text diff per container
    2. group by image with sort | uniq -c             — outlier count is 1
    3. docker inspect --format .Image (digest)        — catches 'same tag,
                                                         different sha' which
                                                         tag-only diff misses
    4. compare against EXPECTED tag with awk          — explicit drift detect
  Aggregation patterns:
    # The "find what's different in this fleet" Swiss Army knife:
    docker inspect $(docker ps -aq --filter "label=...") \
      --format '{{.Config.Image}} {{.Name}}' | sort | uniq -c

    # For deeper drift (env vars, mounts, labels):
    docker inspect $(docker ps -aq --filter "label=...") \
      | jq -r '.[] | [.Name, .Config.Image, (.Config.Env|join(",")), (.Mounts|map(.Source)|join(","))] | @tsv' \
      | sort -u
    # Any column that has 1 unique value vs N-1 = the drifted instance.
  Fix:                docker rm -f <bad-instance>; docker run with the
                      correct image tag (or trigger the orchestrator to
                      replace it).
  Validation:         All 6 (or N) containers report the same image+digest;
                      error rate drops from 1/N to 0.
  Trade-off:          Image-tag drift is rarely caught by health checks
                      (the bad container is "alive"). The right production
                      defense: deploy gates that verify all replicas hit
                      the same digest BEFORE marking the deploy successful.
                      For interview: name this as the systemic fix even
                      while you're applying the immediate one.
  Cross-domain:       Same skill applies in k8s — `kubectl get pods -o
                      custom-columns=NAME:.metadata.name,IMG:.spec.containers[*].image`
                      and grep for the outlier. ECS: describe-tasks with
                      --query 'tasks[].containers[].image'.

  Reference: pnpm harness ask "deploy version skew"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
