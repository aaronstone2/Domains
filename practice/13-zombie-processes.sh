#!/usr/bin/env bash
# Scenario: A container's process table is filling with <defunct> entries.
#           PID 1 inside the container is a Python app that forks children
#           but never wait()s for them — so they stay as zombies indefinitely.
# Symptom:  `ps -ef` shows dozens of <defunct> processes; `top` shows
#           "task: NN total, ZZ zombie" growing; eventually fork() fails
#           with "Resource temporarily unavailable" when the per-uid PID
#           limit is hit.
# Suggested: ha "zombie processes accumulating in container"
# Restore:  docker rm -f the container

set -uo pipefail
NAME="domains-practice-zombies"

start() {
  command -v docker >/dev/null 2>&1 || { echo "[13] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[13] docker daemon unreachable"; exit 1; }
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # Run a container WITHOUT --init. PID 1 is python which forks but doesn't
  # wait() — the classic "no-reaper PID 1" zombie scenario. Forks every 0.5s
  # so after 20s you have ~40 zombies.
  # Debian-based image so the documented `ps -eo state,...` works as written
  # (busybox ps lacks -o state). Adds ~30s pull on first run; cached after.
  docker run -d --name "$NAME" \
    python:3.11-slim bash -c '
python3 -c "
import os, time
while True:
    pid = os.fork()
    if pid == 0:
        os._exit(0)
    # Parent never calls os.waitpid → child becomes zombie, stays in process table
    time.sleep(0.5)
"
' >/dev/null

  echo "[13] container started; letting zombies accumulate ~12s..."
  sleep 12

  cat <<EOF

Scenario:  Container "$NAME" is leaking <defunct> processes. ps -ef inside
           the container shows ~25+ entries with [defunct] in the cmd column,
           and the count grows over time. Eventually it'll hit the per-uid
           process limit and fork() will start failing — even though the
           individual zombies use almost no memory each.

           Find:
           1. Which PID(s) inside the container are zombies
           2. Their PPID (the parent that's failing to reap)
           3. The fix (it's NOT just 'kill the zombies' — they don't respond)

What's true: PID 1 in the container is a python process that fork()s child
             processes which immediately exit, but never calls os.waitpid().
             Each child becomes a zombie. There's no init/tini to reap.

Try:       pnpm harness ask "zombie processes accumulating in container"

  # 1. Confirm zombies exist + count them
  docker exec $NAME ps -ef | head -5
  docker exec $NAME ps -eo state,pid,ppid,cmd | awk '\$1=="Z"'
  docker exec $NAME ps -eo state | sort | uniq -c

  # 2. Verify zombie state via /proc (the kernel's view)
  docker exec $NAME sh -c 'for p in /proc/[0-9]*/status; do
    grep -lE "^State:.+Z" \$p 2>/dev/null
  done | head -10'

  # 3. Find the parent that's not reaping
  docker exec $NAME ps -eo state,pid,ppid,cmd | awk '\$1=="Z"{print \$3}' | sort -u

  # 4. Why does PID 1 matter? Confirm what's running as PID 1 in the container
  docker exec $NAME ps -p 1 -o pid,cmd

  # 5. Compare: what would --init give you?
  docker inspect $NAME --format '{{.HostConfig.Init}}'   # null/false (no --init)
  # If true, docker injects /sbin/docker-init (tini) as PID 1 which reaps.

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "[13] cleaned"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[13] container $NAME still exists. Run: $0 restore"
    return 1
  else
    echo "[13] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[13-zombie-processes] reveal:

  Failure mode id:    docker.fm.zombie-processes-leaking
                      (the canonical "PID 1 not reaping children" pattern)
  Why it happens:     A zombie is a process that has exit()ed but whose parent
                      hasn't called wait()/waitpid() to read the exit status
                      yet. The kernel keeps a stub process entry around so the
                      parent CAN still read the status. When PID 1 is a normal
                      app (not init/tini/dumb-init), and that app fork()s
                      children without wait()ing, the zombies pile up.

                      Why PID 1 specifically? When a non-PID-1 parent dies,
                      its orphan children are re-parented to PID 1. PID 1 is
                      EXPECTED to reap them. If PID 1 is your app (not an
                      init), no one reaps. Zombies forever.

  Diagnostic flow:
    1. ps -eo state,pid,ppid,cmd | awk '$1=="Z"'   → list zombies + their PPIDs
    2. cat /proc/<pid>/status | grep ^State        → 'Z (zombie)' confirms
    3. ps -p <PPID> -o pid,cmd                      → who SHOULD be reaping
    4. ps -p 1 -o pid,cmd                           → confirm PID 1 inside
                                                       container is the app,
                                                       not /sbin/docker-init
    5. cat /proc/sys/kernel/pid_max + ulimit -u     → context for "when it
                                                       starts breaking"

  Why kill -9 doesn't work:
    Zombies are ALREADY DEAD. They have no process to signal. The kernel
    just hasn't released the entry. Sending SIGKILL is a no-op.

  Fix paths (in order of cleanliness):
    (A) Add --init to docker run (the right answer):
          docker rm -f <name>
          docker run --init ... <image>
        --init injects tini as PID 1, which forwards signals AND reaps.
    (B) For docker-compose:
          init: true     in the service block
    (C) Burn-down without restart: kill the parent that's not reaping.
        Children get re-parented to PID 1 (the app), but if PID 1 is the
        same app, doesn't help. Only works if the parent is a sub-process,
        not PID 1.
    (D) Application-level: have the parent install a SIGCHLD handler that
        wait()s. Permanent fix in the app layer, but not always feasible
        if the app is third-party.

  Validation:         After --init: ps -eo state | grep -c '^Z' returns 0
                      and stays at 0 over time.
  Trade-off:          --init adds tini as PID 1. tini forwards SIGTERM/SIGINT
                      to your app correctly, so signal-handling improves AS
                      WELL as zombie reaping. There's almost no downside —
                      docker projects should default to --init.

  Cross-domain:       Same problem in k8s — pods running multi-process apps
                      should set spec.shareProcessNamespace=true OR each
                      container's PID 1 should be a proper init (tini, dumb-init,
                      catatonit).

  Reference: pnpm harness playbook docker.fm.zombie-processes-leaking
             pnpm harness ask "zombie processes container"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
