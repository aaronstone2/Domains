#!/usr/bin/env bash
# Scenario: 8 "agent" containers running. Some restart occasionally (transient),
#           ONE has a deterministic crash loop. Find the persistently-broken
#           one without confusing it for the noisy-but-recovering ones.
# Symptom:  Operator dashboard shows elevated restart rate across the fleet.
#           You need to know: is it cluster-wide instability, or one bad agent?
# Suggested: ha "agent restarting repeatedly find which"
# Restore:  docker rm -f all domains-practice-agents-*

set -uo pipefail
PREFIX="domains-practice-agents"
N_NOISY=7

start() {
  command -v docker >/dev/null 2>&1 || { echo "[10] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[10] docker daemon unreachable"; exit 1; }

  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done

  echo "[10] spinning up $((N_NOISY+1)) agent containers..."
  for i in $(seq 0 "$N_NOISY"); do
    if [[ "$i" -eq 0 ]]; then
      # Agent #0: deterministic crash loop. Always exits 1 after 4s.
      docker run -d --name "${PREFIX}-${i}" \
        --label agent.role=worker \
        --label agent.cohort=alpha \
        --restart always \
        busybox sh -c 'echo "agent-${i} starting"; sleep 4; echo "FATAL: cannot acquire lease"; exit 1' \
        >/dev/null
    else
      # Agent #1..7: occasionally exit cleanly on a random schedule (recovers).
      # Most of the time: just sleep. Some restart from short sleep.
      sleep_for=$(( 60 + RANDOM % 120 ))
      docker run -d --name "${PREFIX}-${i}" \
        --label agent.role=worker \
        --label agent.cohort=alpha \
        --restart unless-stopped \
        busybox sh -c "echo agent-$i starting; sleep $sleep_for; exit 0" \
        >/dev/null
    fi
  done

  # Let the bad one rack up restart count
  sleep 18

  cat <<EOF

Scenario:  Operator dashboard shows the agent fleet has elevated restart rate
           in the last 5 min. Some agents look fine; others have restarted
           1-2 times. ONE agent appears to be in a constant crash loop.

           You need to: (a) identify the persistently broken agent,
                        (b) distinguish it from agents that legitimately
                            restarted once or twice,
                        (c) characterize its failure mode (crash exit code,
                            log signature).

           DON'T just 'docker logs' each one — the fleet could be much bigger
           in real life. Use aggregation.

What's true: 1 of 8 has a deterministic crash (exits with FATAL log every 4s).
             The other 7 sleep for 60-180s then exit 0 once (clean restart,
             not a crash). The bad one's RestartCount climbs MUCH faster.

Try (aggregation-first):
  pnpm harness ask "agent restarting repeatedly find which"

  # 1. RestartCount distribution (the outlier reveals itself)
  docker inspect \$(docker ps -aq --filter "label=agent.role=worker") \\
    --format '{{.RestartCount}} {{.Name}} {{.State.ExitCode}}' \\
    | sort -rn | head -5

  # 2. Recent docker events (per-container restart pattern)
  docker events --since 60s --until 0s \\
    --filter event=die --filter event=start \\
    --format '{{.Time}} {{.Action}} {{.Actor.Attributes.name}}' \\
    | sort | uniq -c | sort -rn | head -10

  # 3. Per-agent log tail aggregated by exit signature
  for c in \$(docker ps -aq --filter "label=agent.role=worker"); do
    name=\$(docker inspect "\$c" --format '{{.Name}}')
    last=\$(docker logs --tail 1 "\$c" 2>&1)
    echo "\$name|\$last"
  done | sort -u

  # 4. Once you've identified the offender, drill into its log
  docker logs --tail 20 ${PREFIX}-<NN>

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  for c in $(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null); do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  echo "[10] cleaned"
}

verify() {
  local n; n="$(docker ps -aq -f "name=^${PREFIX}-" 2>/dev/null | wc -l)"
  if [[ "$n" -gt 0 ]]; then
    echo "[10] $n container(s) still present. Run: $0 restore"
    return 1
  else
    echo "[10] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[10-agents-flapping] reveal:

  Failure mode id:    docker.fm.crashloop-deterministic (composite of
                      docker.fm.restart-loop-on-failure + the methodology
                      pattern of "isolate one bad pod from cohort noise")
  Why it happens:     deployment included a config defect that affects only
                      one agent (e.g. wrong KMS key, malformed lease config,
                      stale pod-bound credential)
  Signal hierarchy:
    1. RestartCount    — climbs much faster on the bad one (10s of vs 0-2)
    2. docker events   — restart frequency over a window distinguishes
                          deterministic crash (every 4-10s) vs transient
                          (once per 60-180s)
    3. Last log line   — exit signature (FATAL: cannot acquire lease) is
                          consistent on the bad one, varied on the others
    4. Exit codes      — usually 1 for a crash, 0 for clean stop+restart
  Aggregation patterns:
    # Find which agents restarted MOST in a window (events-based):
    docker events --since 60s --filter event=die \
      --format '{{.Actor.Attributes.name}}' | sort | uniq -c | sort -rn

    # Find common log signatures (collapse identical errors):
    for c in $(docker ps -aq --filter "label=agent.role=worker"); do
      docker logs --tail 1 "$c" 2>&1
    done | sort | uniq -c | sort -rn
  Fix:                Stop the agent — `docker rm -f <bad>`. Then root-cause
                      its config diff vs the healthy ones (env, image tag,
                      mount, secret). Push corrected config; re-deploy.
  Validation:         RestartCount stays at 0 for 5 min after redeploy;
                      docker events --since 5m shows no new die for that name.
  Trade-off:          Auto-restart with `--restart always` masks deterministic
                      crashes — you find them only via RestartCount delta.
                      Production: emit a metric (StatsD/Prom) per-restart
                      so the alert fires on rate, not just presence.
  Cross-domain:       This is the same pattern as k8s.fm.crashloopbackoff —
                      the SAME aggregation skill (kubectl get pods sorted by
                      restartCount) applies.

  Reference: pnpm harness ask "crashloop find offender"
             pnpm harness playbook k8s.fm.crashloopbackoff (k8s analog)
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
