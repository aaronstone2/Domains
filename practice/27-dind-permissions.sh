#!/usr/bin/env bash
# Scenario: User wants to run docker commands FROM INSIDE a container
#           (Docker-in-Docker pattern). Common in CI runners, build agents,
#           and Devin sessions that need to test their own Docker workloads.
#           Common failures: permission denied on /var/run/docker.sock,
#           or "Cannot connect to the Docker daemon" because docker isn't
#           shared correctly.
# Symptom:  "permission denied while trying to connect to the Docker daemon
#            socket at unix:///var/run/docker.sock" inside the container.
# Suggested: ha "docker in docker permission denied"
# Restore:  docker rm -f the test container

set -uo pipefail
NAME="domains-practice-dind"

start() {
  command -v docker >/dev/null 2>&1 || { echo "[27] needs docker"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "[27] docker daemon unreachable"; exit 1; }
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # Run a container with the docker socket bind-mounted, but NOT as root.
  # The non-root user inside the container won't have access to the socket
  # because the socket is owned by uid 0 (or by GID 'docker' on the host,
  # which doesn't exist in the container's /etc/group).
  docker run -d --name "$NAME" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --user 1000:1000 \
    docker:cli sh -c 'while true; do sleep 60; done' >/dev/null

  cat <<EOF

Scenario:  A user is running CI/build steps inside a container. The
           Dockerfile installs the docker CLI; the run-time bind-mounts
           /var/run/docker.sock so the container can talk to the host
           daemon. Inside the container, \`docker ps\` returns:

             permission denied while trying to connect to the Docker
             daemon socket at unix:///var/run/docker.sock

           Find:
           1. What permissions are on the socket inside the container
           2. Why the in-container user can't access it
           3. The fix(es) — there are several, with very different
              security implications

What's true: Container "$NAME" runs as user 1000:1000. /var/run/docker.sock
             is bind-mounted from the host. The socket is owned by root
             on the host (group 'docker', GID often 999 or similar). The
             container's user 1000 has no group membership matching the
             host's 'docker' group, so syscall returns EACCES.

Try:       pnpm harness ask "docker in docker permission denied socket"

  # 1. Reproduce the error
  docker exec $NAME docker ps 2>&1

  # 2. Inspect socket perms inside the container
  docker exec $NAME ls -la /var/run/docker.sock
  # owner uid/gid + mode

  # 3. The user inside the container
  docker exec $NAME id

  # 4. Cross-check on the HOST
  ls -la /var/run/docker.sock
  getent group docker

  # 5. Why does this matter? Even if the socket is mounted, the kernel
  #    enforces uid/gid permissions on every read/write. Container's user
  #    1000 != host's root and != host's docker group → EACCES.

Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "[27] cleaned"
}

verify() {
  if docker inspect "$NAME" >/dev/null 2>&1; then
    echo "[27] container $NAME still exists. Run: $0 restore"
    return 1
  else
    echo "[27] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[27-dind-permissions] reveal:

  Failure mode id:    docker.fm.dind-socket-permission-denied
                      (the family of "Docker-in-Docker pattern fails to
                       connect to the daemon socket from inside the
                       container" — common in CI/CD, Devin DevBox builds,
                       and test runners)

  Why it happens:     The `-v /var/run/docker.sock:/var/run/docker.sock`
                      bind-mount shares the SOCKET file. But Linux file
                      perms are enforced at the kernel level: only uids/gids
                      that have read+write on the socket can talk to it.
                      The host's socket is typically:
                        srw-rw---- 1 root docker 0 ... /var/run/docker.sock
                      So either: (a) you ARE root inside, or (b) you're
                      in the 'docker' group with the right GID. Inside a
                      container, the host's GID 'docker' is meaningless
                      unless the container has a matching group.

  Diagnostic flow:
    1. docker exec <name> docker ps      → reproduce EACCES
    2. docker exec <name> ls -la /var/run/docker.sock → see owner uid/gid + mode
    3. docker exec <name> id             → confirm container's uid + groups
    4. ls -la /var/run/docker.sock (on host) → host owner uid + GID of 'docker'
    5. getent group docker (on host)     → numeric GID

  The mismatch: container uid 1000 with no group matching host's docker
  GID (e.g. 999) cannot access a srw-rw---- root:docker socket.

  Fix paths (in order of security badness — best first):

  (A) [BEST] Use Docker's "rootless" mode if the workload supports it:
      No daemon-socket sharing needed; every user can have their own
      docker daemon in user namespace. https://docs.docker.com/engine/security/rootless/

  (B) [GOOD] Add a matching group to the container at build time:
      In Dockerfile:
          RUN groupadd -g 999 docker && usermod -aG docker myuser
      Where 999 matches the HOST's docker GID. Container's myuser now
      has the right group; socket access works.
      Trade-off: GID is host-specific; portability suffers.

  (C) [GOOD-IF-CONTAINED] Pass the host's GID at run time:
      docker run --group-add $(getent group docker | cut -d: -f3) ...
      Container user adopts the host's docker GID without modifying the
      image. More portable than (B).

  (D) [WORKS BUT LESS SECURE] Run the container as root:
      docker run --user root ...   (or omit --user; default is root)
      Root has access to the socket regardless of group membership.
      Trade-off: container's process is full root; if the workload is
      compromised, attacker has docker socket = full host root.

  (E) [WORST] chmod the host socket to 666:
      sudo chmod 666 /var/run/docker.sock
      Now ANY user on the host can talk to docker = any user can root the
      host. Don't ever do this on a shared box.

  (F) [DIFFERENT PATTERN] Use Docker-in-Docker (real DinD) — run a
      separate dockerd inside the container:
        docker run --privileged docker:dind
      The container has its OWN daemon (not the host's). Trade-off:
      requires --privileged (gives the container CAP_SYS_ADMIN); slower;
      builds aren't shared with the host. But isolation is much better.

  Validation:         docker exec <name> docker ps  succeeds (returns the
                      list of containers visible to the host daemon).

  Security note (Devin context):
    Sharing /var/run/docker.sock with a container is equivalent to giving
    the container ROOT on the host. ANY container talking to the daemon
    can: docker run --privileged --pid=host -v /:/hostroot ubuntu — and
    instantly own the host. For Devin DevBox: assume the platform team
    has thought about this — never bind-mount the socket without checking
    org policy. Use rootless or BuildKit-without-daemon as alternatives.

  Cross-domain:       k8s pods that need to build/run containers have
                      similar issues. Solutions: kaniko (no daemon, builds
                      in unprivileged container); BuildKit with
                      rootless executor; Buildah; img. Avoid mounting
                      the host's docker socket into a pod whenever
                      possible.

  Reference: pnpm harness playbook docker.fm.dind-socket-permission-denied
             pnpm harness ask "docker in docker permission"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
