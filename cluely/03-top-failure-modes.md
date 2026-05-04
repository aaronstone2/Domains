# 03 — Top failure modes (50 highest-confidence, full diag/fix inline)

> When you've identified an fm-id from [02](02-symptom-to-fm.md) but the harness isn't to hand, the runbook is here.
>
> Auto-generated. Re-run `pnpm cluely` after corpus changes.

Each entry: symptom, root cause, 3+ diagnostic steps, 2+ fix steps. Cross-reference command details in [04-diagnostic-commands.md](04-diagnostic-commands.md).


---

## `docker.fm.exit-137-oomkilled` (conf 0.98)

**Symptom:** Container exited with code 137; `docker inspect` shows OOMKilled=true

**Class:** resource-limit

**Error patterns:** `Exit code 137` \| `OOMKilled: true` \| `killed: true`


### Diagnose
1. **Confirm OOM kill**
   ```
   docker inspect <container> --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
   ```
   _expect:_ true 137
2. **Check kernel OOM log**
   ```
   dmesg -T | grep -i 'killed process'
   ```
   _expect:_ line naming the killed process
3. **Inspect memory limit set**
   ```
   docker inspect <container> --format '{{.HostConfig.Memory}}'
   ```
   _expect:_ in bytes (0 = unlimited)
4. **Read cgroup memory.events**
   ```
   cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.events
   ```
   _expect:_ oom_kill > 0

### Fix
1. **Raise --memory limit**
   ```
   docker run --memory=2G ...
   ```
   _validate:_ container survives previous workload
   _rollback:_ revert to previous limit
2. **Profile actual usage**
   ```
   docker stats <container>
   ```
   _validate:_ see real RSS pattern

---

## `devin.fm.build-failed-blueprint-error` (conf 0.95)

**Symptom:** Snapshot build failed; build log shows YAML parse error or unsupported directive

**Class:** blueprint

**Error patterns:** `YAML parse error` \| `unknown directive` \| `blueprint validation failed`


### Diagnose
1. **Read the build log for the exact error line**
   ```
   # settings → blueprints → build log → look for line number
   ```
   _expect:_ YAML parser names the line + column
2. **Validate YAML syntax locally**
   ```
   # yamllint environment.yaml   OR python -c 'import yaml; yaml.safe_load(open("environment.yaml"))'
   ```
   _expect:_ identifies syntax errors
3. **Check for unsupported directives (vs current schema)**
   ```
   # compare environment.yaml against the latest schema in docs/onboard/environment-yaml
   ```
   _expect:_ any directive not in docs = unsupported

### Fix
1. **Fix YAML syntax (most common: quoting, indentation, mixed tabs/spaces)**
   ```
   # normalize to 2-space indent; quote anything ambiguous (e.g. timeout: "30" vs timeout: 30)
   ```
   _validate:_ yamllint clean; build succeeds
   _rollback:_ git checkout prior version
2. **Replace unsupported directives with documented equivalents**
   ```
   # check schema; e.g. if 'pre_install:' isn't supported, use 'setup:' instead
   ```
   _validate:_ directive accepted
   _rollback:_ prior directive
3. **Test blueprint changes incrementally (one section at a time)**
   ```
   # bisect: revert to last known-good, add changes one section at a time, build after each
   ```
   _validate:_ identifies the problematic change
   _rollback:_ git revert

---

## `devin.fm.repo-clone-failed` (conf 0.95)

**Symptom:** Build fails: git clone error

**Class:** vcs-auth

**Error patterns:** `clone failed` \| `fatal: could not read` \| `permission denied (publickey)`


### Diagnose
1. **Read the exact git error**
   ```
   # build log → git clone line + error
   ```
   _expect:_ 'permission denied (publickey)' = SSH key issue; 'could not read Username for https' = HTTPS missing creds; 'Repository not found' = wrong URL or no access
2. **Check Devin GitHub app installation on the repo**
   ```
   # https://github.com/settings/installations → Devin → Repository access
   ```
   _expect:_ target repo listed
3. **Test from a session terminal**
   ```
   # inside DevBox: git ls-remote <repo-url>
   ```
   _expect:_ reproduces error or works

### Fix
1. **For 'Repository not found': install Devin GitHub app on the repo**
   ```
   # org settings → GitHub apps → Devin → Add repos
   ```
   _validate:_ repo accessible
   _rollback:_ remove repo
2. **For HTTPS missing creds: use the github-app-managed clone (Devin handles auth)**
   ```
   # don't clone manually in setup; let Devin's repo-setup do it
   ```
   _validate:_ clone succeeds via Devin's git wrapper
3. **For SSH: attach deploy key as secret**
   ```
   # environment.yaml: secrets: [{name: SSH_KEY, target: /root/.ssh/id_rsa}]\n# setup: chmod 600 /root/.ssh/id_rsa
   ```
   _validate:_ git clone via ssh succeeds
   _rollback:_ remove key

---

## `docker.fm.apparmor-profile-not-loaded` (conf 0.95)

**Symptom:** `docker run --security-opt apparmor=docker-custom` fails 'apparmor profile not loaded'

**Class:** security

**Error patterns:** `apparmor profile` \| `not loaded` \| `--security-opt`


### Diagnose
1. **List loaded profiles**
   ```
   sudo apparmor_parser --list   # OR  sudo aa-status
   ```
   _expect:_ docker-custom present
2. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.
3. **Read the docker daemon log around the failure time**
   ```
   sudo journalctl -u docker -n 200 --no-pager | tail -80
   ```
   _expect:_ Daemon-side reason for the action: image-pull errors, OCI runtime errors, network plugin failures, storage driver issues.

### Fix
1. **Load profile from file**
   ```
   sudo apparmor_parser -r /etc/apparmor.d/docker-custom
   ```
   _validate:_ aa-status now lists docker-custom
   _rollback:_ sudo apparmor_parser -R /etc/apparmor.d/docker-custom
2. **Run container referencing it**
   ```
   docker run --security-opt apparmor=docker-custom ...
   ```
   _validate:_ no startup error
   _rollback:_ --security-opt apparmor=docker-default

---

## `docker.fm.bind-mount-source-missing` (conf 0.95)

**Symptom:** `docker run -v /host/path:/container/path` 'succeeds' even though /host/path doesn't exist; container sees an empty directory

**Class:** volume-misconfig

**Error patterns:** `mount source missing` \| `empty volume` \| `unexpected empty dir`


### Diagnose
1. **Confirm the source path exists on the host**
   ```
   ls -la /host/path
   ```
   _expect:_ if 'No such file or directory', docker silently created an empty dir as the mount source
2. **Inspect the container's mount config**
   ```
   docker inspect <c> --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}} (RW={{.RW}}){{println}}{{end}}'
   ```
   _expect:_ shows the source path exactly as you typed; if the source is auto-created, it's empty
3. **Check if you meant a named volume instead**
   ```
   docker volume ls | grep <name>
   ```
   _expect:_ if you meant 'mydata:/path' (named volume) but typed '/mydata:/path' (absolute path), docker treats them very differently

### Fix
1. **Use --mount instead of -v (it errors if source missing, instead of silently creating)**
   ```
   docker run --mount type=bind,source=/host/path,target=/container/path,bind-propagation=rprivate <image>
   ```
   _validate:_ errors immediately if /host/path doesn't exist; never silently empty
   _rollback:_ go back to -v
2. **For Compose, use the long form which has the same strictness**
   ```
   # services:\n#   app:\n#     volumes:\n#       - type: bind\n#         source: /host/path\n#         target: /container/path
   ```
   _validate:_ compose up errors if source missing
   _rollback:_ short form '/host/path:/container/path'
3. **Or just create the host path before running**
   ```
   mkdir -p /host/path && docker run -v /host/path:/container/path ...
   ```
   _validate:_ explicit pre-creation; matches user intent

---

## `docker.fm.bind-mount-windows-line-ending` (conf 0.95)

**Symptom:** Bind-mounted shell script fails 'no such file' or '/bin/sh^M: bad interpreter' on Linux container

**Class:** volume

**Error patterns:** `^M` \| `bad interpreter` \| `no such file`


### Diagnose
1. **Inspect line endings**
   ```
   file ./script.sh
   ```
   _expect:_ if 'with CRLF line terminators' → confirmed; if 'ASCII text' → not the issue
2. **Or, look for ^M in the shebang**
   ```
   head -1 ./script.sh | od -c | head
   ```
   _expect:_ \\r before \\n at end of shebang line
3. **Check git's autocrlf setting (root cause is often git on Windows)**
   ```
   git config core.autocrlf
   ```
   _expect:_ if 'true' on Windows, git rewrites .sh files to CRLF on checkout

### Fix
1. **Convert to LF**
   ```
   dos2unix ./script.sh   # OR: sed -i 's/\\r$//' script.sh
   ```
   _validate:_ file ./script.sh shows ASCII (no CRLF); container runs script
   _rollback:_ unix2dos ./script.sh
2. **Configure git to keep LF for shell scripts permanently**
   ```
   # .gitattributes:\n# *.sh text eol=lf\n# *.bash text eol=lf\ngit add --renormalize .
   ```
   _validate:_ future clones get LF for scripts
   _rollback:_ remove .gitattributes line
3. **For Windows users globally: tell git not to munge line endings**
   ```
   git config --global core.autocrlf input   # commit as LF, checkout as LF
   ```
   _validate:_ new repos don't get CRLF on .sh
   _rollback:_ git config --global core.autocrlf true

---

## `docker.fm.buildkit-output-no-load` (conf 0.95)

**Symptom:** `docker buildx build -t app .` succeeds but `docker images` doesn't list `app`

**Class:** build-output

**Error patterns:** `images empty` \| `not found` \| `--load`


### Diagnose
1. **Check builder driver**
   ```
   docker buildx ls
   ```
   _expect:_ docker-container or kubernetes (these don't auto-load into the daemon image store)
2. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.
3. **Read the docker daemon log around the failure time**
   ```
   sudo journalctl -u docker -n 200 --no-pager | tail -80
   ```
   _expect:_ Daemon-side reason for the action: image-pull errors, OCI runtime errors, network plugin failures, storage driver issues.

### Fix
1. **Add --load to push the image into local docker daemon**
   ```
   docker buildx build -t app --load .
   ```
   _validate:_ docker images shows app
   _rollback:_ omit --load (image stays in builder cache only)
2. **For multi-arch, --load is incompatible; use --push to a registry**
   ```
   docker buildx build -t myreg/app:tag --platform linux/amd64,linux/arm64 --push .
   ```
   _validate:_ manifest list visible at registry

---

## `docker.fm.buildkit-secret-leaked` (conf 0.95)

**Symptom:** Secret accidentally baked into image (visible in `docker history`)

**Class:** build-security

**Error patterns:** `secret in image` \| `credentials in layer`


### Diagnose
1. **Inspect image history**
   ```
   docker history <image> --no-trunc
   ```
   _expect:_ see ENV / RUN with secret value
2. **Search filesystem**
   ```
   docker run --rm <image> grep -r 'secret-pattern' /
   ```
   _expect:_ matches = leaked
3. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.

### Fix
1. **Use BuildKit --mount=type=secret**
   ```
   # RUN --mount=type=secret,id=foo cat /run/secrets/foo
   ```
   _validate:_ docker build --secret id=foo,src=./secret; image history shows no secret
   _rollback:_ revert Dockerfile
2. **Rotate the leaked secret**
   ```
   # rotate at source (AWS, vault, etc.); push new image
   ```
   _validate:_ old secret invalid

---

## `docker.fm.cannot-connect-daemon` (conf 0.95)

**Symptom:** `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`

**Class:** daemon-unavailable

**Error patterns:** `Cannot connect to the Docker daemon` \| `Is the docker daemon running?` \| `permission denied while trying to connect`


### Diagnose
1. **Verify daemon process running**
   ```
   systemctl status docker
   ```
   _expect:_ active (running)
2. **Check socket file exists + permissions**
   ```
   ls -l /var/run/docker.sock
   ```
   _expect:_ srw-rw---- root:docker
3. **Check user is in docker group**
   ```
   id $USER
   ```
   _expect:_ groups=...,docker
4. **Check DOCKER_HOST env**
   ```
   echo $DOCKER_HOST
   ```
   _expect:_ empty (Unix socket) OR valid tcp://...

### Fix
1. **If daemon stopped: start**
   ```
   sudo systemctl start docker
   ```
   _validate:_ systemctl status docker shows active
   _rollback:_ sudo systemctl stop docker
2. **If user not in docker group**
   ```
   sudo usermod -aG docker $USER && newgrp docker
   ```
   _validate:_ id shows docker group
   _rollback:_ sudo gpasswd -d $USER docker
3. **If wrong DOCKER_HOST**
   ```
   unset DOCKER_HOST
   ```
   _validate:_ docker ps works
   _rollback:_ export DOCKER_HOST=...

---

## `docker.fm.cap-not-actually-dropped` (conf 0.95)

**Symptom:** `docker run --cap-drop=NET_ADMIN` and yet container can still configure network interfaces

**Class:** security

**Error patterns:** `NET_ADMIN` \| `cap-drop` \| `capability`


### Diagnose
1. **Inspect effective caps inside container**
   ```
   docker exec <c> cat /proc/1/status | grep ^Cap
   ```
   _expect:_ CapBnd missing the dropped cap; if cap is still set, drop didn't take effect
2. **Decode the capability bitmap**
   ```
   docker exec <c> grep ^CapBnd /proc/1/status | awk '{print $2}' | xargs -I{} capsh --decode={}
   ```
   _expect:_ human-readable list; NET_ADMIN should not appear
3. **Check for --privileged or extra --cap-add (these override your drop)**
   ```
   docker inspect <c> --format '{{.HostConfig.Privileged}} {{.HostConfig.CapAdd}}'
   ```
   _expect:_ Privileged=false; CapAdd does not re-add NET_ADMIN

### Fix
1. **Use cap-drop=ALL then add back only what's needed**
   ```
   docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE ...
   ```
   _validate:_ CapBnd shows minimal caps; container still works
   _rollback:_ --cap-drop omitted
2. **For Compose:**
   ```
   # services:\n#   app:\n#     cap_drop: [ALL]\n#     cap_add: [NET_BIND_SERVICE]
   ```
   _validate:_ compose up applies caps
   _rollback:_ remove cap_drop/cap_add
3. **Verify in CI / on every deploy that caps are dropped**
   ```
   # kubectl-equivalent: spec.containers[].securityContext.capabilities.drop\n# add an automated test that checks /proc/1/status CapBnd
   ```
   _validate:_ caps stay dropped across releases

---

## `docker.fm.compose-build-args-not-passed-to-stage` (conf 0.95)

**Symptom:** Multi-stage Dockerfile: ARG declared at top but value undefined inside a later FROM stage

**Class:** image-build

**Error patterns:** `ARG` \| `undefined` \| `build arg`


### Diagnose
1. **Check ARG scoping rules**
   ```
   # ARG before any FROM is global; ARG inside a stage is scoped to that stage only
   ```
   _expect:_ yes
2. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.
3. **Read the docker daemon log around the failure time**
   ```
   sudo journalctl -u docker -n 200 --no-pager | tail -80
   ```
   _expect:_ Daemon-side reason for the action: image-pull errors, OCI runtime errors, network plugin failures, storage driver issues.

### Fix
1. **Declare ARG inside each stage that consumes it**
   ```
   # FROM base AS s1\nARG VERSION\nRUN echo $VERSION
   ```
   _validate:_ each stage sees value
   _rollback:_ omit ARG in stage
2. **Or inherit ARG and assign to ENV**
   ```
   # at top: ARG VERSION  \n# in stage: ARG VERSION\nENV VERSION=$VERSION
   ```
   _validate:_ persists into image

---

## `docker.fm.compose-depends-on-wrong` (conf 0.95)

**Symptom:** Service starts before dependency is actually ready (e.g. app errors connecting to DB despite depends_on)

**Class:** orchestration

**Error patterns:** `Connection refused` \| `could not connect to server` \| `ECONNREFUSED`


### Diagnose
1. **Check the depends_on form being used**
   ```
   docker compose config | grep -A3 depends_on
   ```
   _expect:_ if just 'depends_on: [db]' (short form) → only waits for container to START, not be ready
2. **Check if the dependency has a healthcheck**
   ```
   docker compose config | grep -A5 healthcheck
   ```
   _expect:_ if no healthcheck on db, condition: service_healthy can't work
3. **Confirm timing: how fast does the dep actually become ready?**
   ```
   docker compose up -d <db>; while ! docker exec <db-container> pg_isready; do sleep 1; done
   ```
   _expect:_ if takes >5s, app starting too soon

### Fix
1. **Use long-form depends_on with condition: service_healthy**
   ```
   # services:\n#   app:\n#     depends_on:\n#       db:\n#         condition: service_healthy
   ```
   _validate:_ app waits until db's healthcheck passes
   _rollback:_ depends_on: [db]
2. **Add a real healthcheck to the dependency**
   ```
   # services:\n#   db:\n#     healthcheck:\n#       test: ['CMD-SHELL', 'pg_isready -U postgres']\n#       interval: 5s\n#       timeout: 3s\n#       retries: 10\n#       start_period: 10s
   ```
   _validate:_ docker inspect <db> --format '{{.State.Health.Status}}' shows 'healthy'
   _rollback:_ remove healthcheck
3. **App-side: implement retry-on-startup for first ~30s**
   ```
   # Even with healthcheck, transient failures happen; app should retry connect with exponential backoff
   ```
   _validate:_ app survives brief dep restarts

---

## `docker.fm.compose-profile-not-applied` (conf 0.95)

**Symptom:** `docker compose up` doesn't start a service that has `profiles: [debug]` even with `--profile debug`

**Class:** compose-config

**Error patterns:** `profile` \| `not started` \| `skipped`


### Diagnose
1. **Show effective config with profile flag**
   ```
   docker compose --profile debug config
   ```
   _expect:_ the profiled service appears in services
2. **Check COMPOSE_PROFILES env**
   ```
   echo $COMPOSE_PROFILES
   ```
   _expect:_ comma-separated profiles
3. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.

### Fix
1. **Pass --profile or set COMPOSE_PROFILES**
   ```
   docker compose --profile debug up   # OR  COMPOSE_PROFILES=debug docker compose up
   ```
   _validate:_ service starts
2. **Verify dependent services get implicitly enabled**
   ```
   # Profile-less services that another profiled service depends_on are still enabled
   ```

---

## `docker.fm.copy-from-stage-not-found` (conf 0.95)

**Symptom:** `COPY --from=builder /out/app /app` fails: 'invalid from flag value builder: stage not found'

**Class:** image-build

**Error patterns:** `stage not found` \| `invalid from flag` \| `--from`


### Diagnose
1. **Verify named stage exists**
   ```
   grep -nE '^FROM .* AS ' Dockerfile
   ```
   _expect:_ line 'FROM <image> AS builder' upstream of the COPY
2. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.
3. **Read the docker daemon log around the failure time**
   ```
   sudo journalctl -u docker -n 200 --no-pager | tail -80
   ```
   _expect:_ Daemon-side reason for the action: image-pull errors, OCI runtime errors, network plugin failures, storage driver issues.

### Fix
1. **Add the AS-name to the upstream FROM**
   ```
   # FROM golang:1.22 AS builder
   ```
   _validate:_ docker buildx build proceeds past COPY
   _rollback:_ remove AS
2. **For COPY from external image, name the image directly**
   ```
   COPY --from=alpine:3.20 /etc/passwd /tmp/
   ```
   _validate:_ COPY succeeds without stage definition

---

## `docker.fm.docker-stop-hangs-10s` (conf 0.95)

**Symptom:** `docker stop` takes 10 seconds before container exits (then SIGKILL)

**Class:** signal-handling

**Error patterns:** `timeout exceeded` \| `killing container after grace period` \| `10 seconds`


### Diagnose
1. **Confirm the container is taking the full grace period (default 10s)**
   ```
   time docker stop <c>
   ```
   _expect:_ ~10.0s — confirms container ignored SIGTERM
2. **Check whether the entrypoint is a real init or just bash/your-app as PID 1**
   ```
   docker inspect <c> --format '{{.Config.Entrypoint}} {{.Config.Cmd}}' && docker exec <c> cat /proc/1/comm
   ```
   _expect:_ PID 1 = your app or shell, NOT tini / dumb-init / docker-init
3. **Verify the app actually handles SIGTERM (vs ignoring it)**
   ```
   docker exec <c> kill -TERM 1 && sleep 1 && docker ps --filter id=<c>
   ```
   _expect:_ if container is still running 2s later, the app is silently dropping SIGTERM

### Fix
1. **Run with --init (docker injects tini as PID 1, which forwards signals)**
   ```
   docker run --init <image>
   ```
   _validate:_ docker stop now takes <2s; docker exec cat /proc/1/comm shows 'docker-init'
   _rollback:_ omit --init
2. **Or, fix the app to install a SIGTERM handler**
   ```
   # Node: process.on('SIGTERM', () => { server.close(() => process.exit(0)) })\n# Python: signal.signal(signal.SIGTERM, lambda s,f: sys.exit(0))\n# Go: signal.Notify(c, syscall.SIGTERM); <-c; gracefulShutdown()
   ```
   _validate:_ app exits cleanly on SIGTERM; docker stop fast
   _rollback:_ remove handler
3. **For shells/wrappers: use 'exec' to replace the shell with the app (so app actually receives signals)**
   ```
   # entrypoint.sh:\n# exec /usr/local/bin/myapp "$@"   (NOT just `/usr/local/bin/myapp "$@"` — without exec, shell stays as PID 1 and absorbs signals)
   ```
   _validate:_ PID 1 is the app, not the shell
   _rollback:_ remove exec

---

## `docker.fm.dockerd-tls-cert-expired` (conf 0.95)

**Symptom:** `docker -H tcp://host:2376 ps` fails 'x509: certificate has expired'

**Class:** security

**Error patterns:** `x509` \| `certificate has expired` \| `TLS`


### Diagnose
1. **Inspect server cert expiry**
   ```
   openssl s_client -connect host:2376 -servername host < /dev/null 2>/dev/null | openssl x509 -noout -dates
   ```
   _expect:_ notAfter in the past
2. **Check the on-disk cert (server-side)**
   ```
   sudo openssl x509 -in /etc/docker/server-cert.pem -noout -dates -subject
   ```
   _expect:_ matches what server is presenting
3. **Verify the CA that issued the cert is itself still valid**
   ```
   openssl x509 -in /etc/docker/ca.pem -noout -dates
   ```
   _expect:_ CA notAfter in the future

### Fix
1. **Issue new server cert from your CA**
   ```
   # regenerate via your CA tool (e.g. cfssl, step-ca, vault, openssl req)\n# place new cert at /etc/docker/server-cert.pem and key at /etc/docker/server-key.pem
   ```
   _validate:_ openssl x509 -in /etc/docker/server-cert.pem -dates shows new notAfter
   _rollback:_ restore prior certs
2. **Reload docker daemon (no need to restart)**
   ```
   sudo systemctl reload docker
   ```
   _validate:_ openssl s_client shows new dates
   _rollback:_ copy back old cert + reload
3. **Add a cert-expiry check to your monitoring**
   ```
   # Prometheus: blackbox_exporter ssl_expire_in_days{instance='host:2376'} < 14
   ```
   _validate:_ alert fires 14 days before next expiry
   _rollback:_ remove alert

---

## `docker.fm.exec-tty-no-input` (conf 0.95)

**Symptom:** `docker exec -it <c> bash` works but typed keys don't reach shell

**Class:** exec

**Error patterns:** `tty` \| `stdin` \| `interactive`


### Diagnose
1. **Confirm both -i and -t supplied**
   ```
   # -i keeps STDIN open; -t allocates TTY; both required for shell
   ```
   _expect:_ present
2. **Run with separate flags to isolate**
   ```
   docker exec -i <c> sh -c 'cat'
   ```
   _expect:_ if -i alone sees input but -it doesn't, terminal driver issue
3. **Inspect the affected container/image/network state**
   ```
   docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .
   ```
   _expect:_ State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.

### Fix
1. **Re-launch with both flags**
   ```
   docker exec -it <c> bash
   ```
   _validate:_ input reaches shell
2. **If running through CI without TTY, drop -t**
   ```
   docker exec -i <c> bash -c 'commands'
   ```
   _validate:_ non-interactive command runs
   _rollback:_ add -t for interactive shell

---

## `docker.fm.image-pull-private-registry-auth` (conf 0.95)

**Symptom:** `docker pull` from private registry fails 'unauthorized: incorrect username or password' OR 'denied: requested access to the resource is denied' OR 'pull access denied for X, repository does not exist or may require docker login'

**Class:** registry-auth

**Error patterns:** `unauthorized` \| `denied: requested access` \| `pull access denied`


### Diagnose
1. **Identify what wording the error uses (narrows the cause)**
   ```
   docker pull <image> 2>&1 | tail -3
   ```
   _expect:_ 'pull access denied' = no/bad creds; 'toomanyrequests' = rate limit (different fm); 'denied' alone = repo policy
2. **Check what credentials docker has**
   ```
   cat ~/.docker/config.json 2>/dev/null | jq '.auths | keys'
   ```
   _expect:_ list of registry hostnames you've logged into; if missing your registry, no creds at all
3. **Test auth directly against the registry's v2 API**
   ```
   curl -u "$USER:$PASS" -I https://<registry>/v2/<org>/<repo>/manifests/latest
   ```
   _expect:_ 200=auth+repo OK; 401=auth bad; 404=auth OK but repo/tag wrong
4. **For ECR specifically, check token age (12-hour expiry)**
   ```
   aws sts get-caller-identity && aws ecr get-login-password --region <region> | head -c 20
   ```
   _expect:_ sts works → IAM ok; if get-login-password fails, IAM perms issue not token age

### Fix
1. **For Docker Hub / GHCR / Harbor: re-login**
   ```
   docker login <registry>
   ```
   _validate:_ docker pull succeeds
   _rollback:_ docker logout <registry>
2. **For ECR: refresh the 12-hour token now AND wire into CI to refresh per-job**
   ```
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
   ```
   _validate:_ ~/.docker/config.json has fresh auth entry
   _rollback:_ docker logout <ecr-host>
3. **For GitHub Actions / shared CI: use the official login action so it refreshes per-job**
   ```
   # .github/workflows/x.yml: - uses: aws-actions/amazon-ecr-login@v2  # or docker/login-action@v3
   ```
   _validate:_ subsequent steps inherit auth; no stale token
   _rollback:_ remove the action step
4. **For cluster pulls (EKS/ECS): switch from imagePullSecrets to IRSA / task IAM role so pulls use the assumed role's automatically-refreshed token**
   ```
   # EKS: annotate ServiceAccount with eks.amazonaws.com/role-arn=<arn> that has AmazonEC2ContainerRegistryReadOnly
   ```
   _validate:_ kubelet can pull without imagePullSecret
   _rollback:_ recreate imagePullSecret

---

## `docker.fm.iptables-docker-chain-flushed` (conf 0.95)

**Symptom:** After running `iptables -F`, all docker port publishing breaks until daemon restart

**Class:** networking

**Error patterns:** `iptables -F` \| `flushed` \| `port not published`


### Diagnose
1. **Confirm DOCKER chain is missing**
   ```
   sudo iptables -t nat -L DOCKER -n 2>&1 | head
   ```
   _expect:_ 'No chain/target/match by that name' = chain was flushed
2. **Confirm published ports stop working**
   ```
   # from a test container with -p 8080:80, curl http://localhost:8080
   ```
   _expect:_ connection refused or timeout — port-publish DNAT is gone
3. **Check what wrote the offending iptables-flush (ansible? CI? someone's runbook?)**
   ```
   # audit shell history / configuration management runs in last 24h
   ```
   _expect:_ identifies the cause to prevent recurrence

### Fix
1. **Restart docker daemon — repopulates the chains**
   ```
   sudo systemctl restart docker
   ```
   _validate:_ sudo iptables -t nat -L DOCKER -n shows DNAT rules per published port
2. **For ongoing custom rules, use DOCKER-USER chain (docker preserves it across flushes by design)**
   ```
   sudo iptables -I DOCKER-USER -i eth0 -j ACCEPT  # your rule goes here
   ```
   _validate:_ docker daemon won't overwrite DOCKER-USER on next restart
   _rollback:_ sudo iptables -D DOCKER-USER -i eth0 -j ACCEPT
3. **Make rule changes via iptables-restore script that includes DOCKER-USER but doesn't touch DOCKER**
   ```
   # script writes only DOCKER-USER + filter/forward rules; never -F
   ```
   _validate:_ future configmgmt runs preserve docker chains
   _rollback:_ prior script

---

## `docker.fm.ipv6-not-enabled` (conf 0.95)

**Symptom:** `docker run` on IPv6-only network fails to assign address; container has no IPv6 connectivity

**Class:** networking

**Error patterns:** `IPv6` \| `no v6 address` \| `::`


### Diagnose
1. **Check daemon IPv6 setting**
   ```
   docker info | grep -i 'ipv6\|fixed-cidr'
   ```
   _expect:_ IPv6: true; fixed-cidr-v6 set
2. **Check daemon.json**
   ```
   sudo cat /etc/docker/daemon.json | jq '.ipv6, ."fixed-cidr-v6"'
   ```
   _expect:_ both set; otherwise IPv6 not enabled
3. **Confirm host has IPv6 itself**
   ```
   ip -6 addr show && sysctl net.ipv6.conf.all.disable_ipv6
   ```
   _expect:_ host has v6 addresses; disable_ipv6=0

### Fix
1. **Enable IPv6 in daemon.json with fixed-cidr-v6**
   ```
   # /etc/docker/daemon.json: {\n#   "ipv6": true,\n#   "fixed-cidr-v6": "fd00::/64",\n#   "experimental": true,  // for ip6tables on older docker\n#   "ip6tables": true\n# }
   ```
   _validate:_ docker info shows IPv6: true
   _rollback:_ remove fields
2. **Restart daemon**
   ```
   sudo systemctl restart docker
   ```
   _validate:_ new networks accept v6; container gets v6 addr
3. **For dual-stack on existing networks, recreate them**
   ```
   docker network rm <net>; docker network create --ipv6 --subnet fd00::/64 <net>
   ```
   _validate:_ containers on new network get v6
   _rollback:_ recreate without --ipv6

---

## `docker.fm.runc-exit-128-plus-signum` (conf 0.95)

**Symptom:** `docker inspect` shows exit code like 137, 139, 143; user wonders what they mean

**Class:** signal-semantics

**Error patterns:** `exit code 137` \| `exit code 139` \| `exit code 143`


### Diagnose
1. **Subtract 128 from the exit code → POSIX signal number**
   ```
   # 137 - 128 = 9 (SIGKILL — usually OOM)\n# 139 - 128 = 11 (SIGSEGV — segfault)\n# 143 - 128 = 15 (SIGTERM — graceful stop)\n# 130 - 128 = 2 (SIGINT — Ctrl+C)\n# 134 - 128 = 6 (SIGABRT — abort/assertion)
   ```
   _expect:_ signal name identifies the kill mechanism
2. **For 137: confirm it was OOM (vs external kill)**
   ```
   docker inspect <c> --format '{{.State.OOMKilled}} {{.State.ExitCode}}' && dmesg -T | grep -i 'killed process' | tail
   ```
   _expect:_ OOMKilled=true → cgroup memory limit; OOMKilled=false → external `kill -9` or systemd / orchestrator killed it
3. **For 139: capture a core dump for debugging**
   ```
   # echo '/tmp/core.%p' | sudo tee /proc/sys/kernel/core_pattern  # set core path on host\ndocker run --ulimit core=-1 ...   # allow cores in container
   ```
   _expect:_ next crash leaves core file

### Fix
1. **Map the signal to its likely fix**
   ```
   # 137 (SIGKILL): see docker.fm.exit-137-oomkilled — raise --memory or fix leak\n# 139 (SIGSEGV): app bug; debug with gdb on the core dump\n# 143 (SIGTERM): normal stop; if user expected 0, app didn't handle SIGTERM (see docker.fm.docker-stop-hangs-10s)\n# 134 (SIGABRT): assertion in app code or stdlib; reproduce with debug build
   ```
   _validate:_ each signal has a known runbook
2. **For SIGSEGV with core: open in gdb on the host**
   ```
   gdb /path/to/binary /tmp/core.<pid>\n(gdb) bt   # backtrace
   ```
   _validate:_ frame names point at the bug location

---

## `docker.fm.runc-rootless-newuidmap-missing` (conf 0.95)

**Symptom:** `docker run` (rootless) fails: 'newuidmap: command not found' or 'unable to set up uid mapping'

**Class:** rootless-setup

**Error patterns:** `newuidmap` \| `newgidmap` \| `uid mapping`


### Diagnose
1. **Check binaries are installed and SUID-root**
   ```
   ls -l $(which newuidmap 2>/dev/null) $(which newgidmap 2>/dev/null)
   ```
   _expect:_ -rwsr-xr-x (the 's' = SUID); root:root ownership
2. **Check subuid/subgid entries for the user**
   ```
   grep ^$USER /etc/subuid /etc/subgid
   ```
   _expect:_ line per file with 65536+ contiguous IDs allocated
3. **Check the rootless dockerd logs**
   ```
   systemctl --user status docker || journalctl --user -u docker.service -e
   ```
   _expect:_ explicit error pointing at uidmap or subuid issue

### Fix
1. **Install uidmap package**
   ```
   sudo apt install -y uidmap   # OR: sudo dnf install -y shadow-utils
   ```
   _validate:_ newuidmap --help works
   _rollback:_ sudo apt remove uidmap
2. **Add subuid/subgid entries (need 65536 IDs minimum)**
   ```
   sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
   ```
   _validate:_ /etc/subuid and /etc/subgid contain new ranges
   _rollback:_ sudo usermod --del-subuids ... --del-subgids ... $USER
3. **Restart user-level dockerd**
   ```
   systemctl --user restart docker; docker info | grep -i rootless
   ```
   _validate:_ docker info shows 'rootless' security option; docker run works
   _rollback:_ systemctl --user stop docker

---

## `docker.fm.zombie-processes-leaking` (conf 0.95)

**Symptom:** Defunct/zombie processes accumulating inside container; `ps` shows multiple <defunct> entries

**Class:** signal-handling

**Error patterns:** `<defunct>` \| `Z stat in ps` \| `zombie process`


### Diagnose
1. **Confirm zombies are accumulating (and growing)**
   ```
   docker exec <c> sh -c 'ps axo pid,ppid,stat,comm | grep -E "Z|<defunct>"'
   ```
   _expect:_ non-zero count; if growing over time = real leak
2. **Identify what's PID 1**
   ```
   docker exec <c> cat /proc/1/comm
   ```
   _expect:_ if it's your app or 'sh' (not tini / docker-init), it's not designed to reap
3. **Find the parent of the zombies (whose children aren't being reaped)**
   ```
   docker exec <c> ps axo pid,ppid,stat,comm | awk '$3 ~ /^Z/ {print $2}' | sort -u
   ```
   _expect:_ all zombies have PPID = 1 → PID 1 isn't reaping; or PPID = some app → that app isn't reaping

### Fix
1. **Run container with --init (tini handles SIGCHLD reaping)**
   ```
   docker run --init <image>
   ```
   _validate:_ PID 1 = docker-init; zombies disappear; new ones don't accumulate
   _rollback:_ omit --init
2. **For apps that fork children, install a SIGCHLD handler**
   ```
   # C: signal(SIGCHLD, sigchld_handler) where handler does waitpid(-1, &st, WNOHANG) in loop\n# Python: signal.signal(signal.SIGCHLD, ...) or use subprocess.Popen properly with .wait()
   ```
   _validate:_ no zombies accumulate
   _rollback:_ remove handler
3. **For Compose: use init: true at the service level**
   ```
   # services:\n#   myapp:\n#     init: true   # equivalent to --init
   ```
   _validate:_ compose up creates containers with docker-init as PID 1
   _rollback:_ init: false

---

## `ecs.agent.fm.awslogs-missing-log-group` (conf 0.95)

**Symptom:** Task fails ResourceInitializationError 'failed to create container: failed to initialize logging driver: awslogs: log group does not exist'. awslogs-create-group not set + group doesn't exist.

**Class:** awslogs-create-group-not-set

**Error patterns:** `log group does not exist` \| `ResourceNotFoundException` \| `awslogs`


### Diagnose
1. **Check log options**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.containerDefinitions[].logConfiguration'
   ```
   _expect:_ options.awslogs-create-group=true OR group pre-created
2. **Inspect the ECS agent log on the container instance**
   ```
   sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log
   ```
   _expect:_ Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.
3. **Query the agent's introspection endpoint for current task state**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'
   ```
   _expect:_ Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.

### Fix
1. **Pre-create the log group (recommended)**
   ```
   aws logs create-log-group --log-group-name <group>; aws logs put-retention-policy --log-group-name <group> --retention-in-days 30
   ```
   _validate:_ Tasks launch
   _rollback:_ Delete group
2. **Or set awslogs-create-group=true in log options + grant logs:CreateLogGroup to executionRole**
   ```
   Update task def options.awslogs-create-group=true; add IAM perm
   ```
   _validate:_ Auto-created on first task
   _rollback:_ Set to false; pre-create groups

---

## `ecs.agent.fm.ephemeral-storage-exhausted-fargate` (conf 0.95)

**Symptom:** Fargate task fills its scratch disk; container crashes with 'no space left on device'. Default ephemeralStorage is 20 GiB; bigger images / scratch usage exceeds.

**Class:** ephemeral-storage-too-small

**Error patterns:** `no space left on device` \| `ENOSPC` \| `disk full`


### Diagnose
1. **Check current ephemeralStorage**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.ephemeralStorage'
   ```
   _expect:_ sizeInGiB ≥ image-size + scratch-budget + buffer
2. **Inspect the ECS agent log on the container instance**
   ```
   sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log
   ```
   _expect:_ Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.
3. **Query the agent's introspection endpoint for current task state**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'
   ```
   _expect:_ Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.

### Fix
1. **Raise ephemeralStorage (Fargate platform 1.4.0+, range 21-200)**
   ```
   Update task-def: ephemeralStorage.sizeInGiB=50; register new revision
   ```
   _validate:_ Tasks no longer hit ENOSPC
   _rollback:_ Restore prior size
2. **For larger needs, attach EBS volume (configuredAtLaunch, Fargate platform 1.4+)**
   ```
   Add task-def volume with configuredAtLaunch=true; provide volume config at run-task time
   ```
   _validate:_ 200+ GiB available

---

## `ecs.agent.fm.fargate-restricted-syscall-or-cap` (conf 0.95)

**Symptom:** Fargate task fails to launch: 'unsupported parameter: privileged' or 'sysctl X not allowed'. Fargate restricts privileged + many sysctls + capabilities.

**Class:** fargate-restriction

**Error patterns:** `unsupported parameter` \| `not supported on Fargate` \| `privileged`


### Diagnose
1. **Check task-def for restricted features**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.containerDefinitions[].{priv:privileged,caps:linuxParameters.capabilities,sysctls:systemControls,pidMode:pidMode}'
   ```
   _expect:_ None of the Fargate-forbidden features set
2. **Inspect the ECS agent log on the container instance**
   ```
   sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log
   ```
   _expect:_ Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.
3. **Query the agent's introspection endpoint for current task state**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'
   ```
   _expect:_ Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.

### Fix
1. **Remove the restricted parameter OR migrate to EC2 launch type**
   ```
   Update task-def to drop privileged/restricted sysctl/capability; OR change launchType=EC2
   ```
   _validate:_ Task launches
   _rollback:_ Revert
2. **Restart the ECS agent and confirm re-registration with the cluster**
   ```
   sudo systemctl restart ecs && sleep 5 && curl -s http://localhost:51678/v1/metadata | jq .
   ```
   _validate:_ /v1/metadata returns Cluster + ContainerInstanceArn; ECS console shows the instance as ACTIVE again.
   _rollback:_ If restart causes worse state, check /var/log/ecs/ecs-init.log; downgrade agent via 'sudo yum downgrade ecs-init-<version>' or replace the AMI.

---

## `ecs.agent.fm.spot-interruption-no-draining` (conf 0.95)

**Symptom:** Spot-backed instance terminated mid-task. Tasks were running but no draining happened; service has to scramble to replace them. Disrupts in-flight work.

**Class:** ecs-enable-spot-instance-draining-not-set

**Error patterns:** `Spot instance interrupted` \| `instance terminated unexpectedly`


### Diagnose
1. **Check current setting**
   ```
   docker inspect ecs-agent --format '{{json .Config.Env}}' | grep SPOT
   ```
   _expect:_ ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
2. **Inspect the ECS agent log on the container instance**
   ```
   sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log
   ```
   _expect:_ Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.
3. **Query the agent's introspection endpoint for current task state**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'
   ```
   _expect:_ Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.

### Fix
1. **Enable spot draining**
   ```
   echo 'ECS_ENABLE_SPOT_INSTANCE_DRAINING=true' | sudo tee -a /etc/ecs/ecs.config; sudo systemctl restart ecs
   ```
   _validate:_ Future spot interruptions trigger DRAINING; tasks gracefully replaced
   _rollback:_ Set to false
2. **Bake into all AMI images (CloudInit/user-data)**
   ```
   Add line to user-data so newly launched instances always have it
   ```
   _validate:_ Cluster-wide consistent behavior

---

## `ecs.agent.fm.task-def-volume-name-collision` (conf 0.95)

**Symptom:** Task fails to start: 'volume name X already exists'. Two task-def volumes with the same name; OR mountPoint references a volume name that doesn't exist in volumes[].

**Class:** task-def-volume-misconfig

**Error patterns:** `volume name` \| `duplicate volume` \| `sourceVolume not found`


### Diagnose
1. **Inspect task def volumes + mountPoints**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.{volumes:volumes,mounts:containerDefinitions[].mountPoints}'
   ```
   _expect:_ Volume names unique; every mountPoint.sourceVolume matches a volume name
2. **Inspect the ECS agent log on the container instance**
   ```
   sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log
   ```
   _expect:_ Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.
3. **Query the agent's introspection endpoint for current task state**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'
   ```
   _expect:_ Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.

### Fix
1. **Rename duplicates / fix mountPoint.sourceVolume references**
   ```
   Update task-def JSON; register new revision
   ```
   _validate:_ Tasks launch
   _rollback:_ Revert revision
2. **Restart the ECS agent and confirm re-registration with the cluster**
   ```
   sudo systemctl restart ecs && sleep 5 && curl -s http://localhost:51678/v1/metadata | jq .
   ```
   _validate:_ /v1/metadata returns Cluster + ContainerInstanceArn; ECS console shows the instance as ACTIVE again.
   _rollback:_ If restart causes worse state, check /var/log/ecs/ecs-init.log; downgrade agent via 'sudo yum downgrade ecs-init-<version>' or replace the AMI.

---

## `ecs.networking.fm.host-mode-port-conflict` (conf 0.95)

**Symptom:** Second task in host network mode fails to start: 'port already allocated'. Two tasks on same instance try to bind same containerPort.

**Class:** host-network-port-conflict

**Error patterns:** `port already allocated` \| `bind: address already in use` \| `RESOURCE:PORTS`


### Diagnose
1. **Check task-def network mode + port mappings**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.{nm:networkMode,ports:containerDefinitions[].portMappings}'
   ```
   _expect:_ networkMode=host with fixed containerPort = collision risk
2. **Inspect the ENI / bridge state on the container instance for the failing task**
   ```
   ip -br link show; ip -br addr show; aws ec2 describe-network-interfaces --filters Name=description,Values='*ECS*' --query 'NetworkInterfaces[].{eni:NetworkInterfaceId,status:Status,subnet:SubnetId,sg:Groups[].GroupId}' --output table
   ```
   _expect:_ ENI is attached and Available; subnet matches task subnet; security groups allow expected egress.
3. **Verify the agent's network mode + Service Connect / VPC Lattice config matches the task definition**
   ```
   curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, networkMode:.NetworkMode, attachments:.Attachments}'
   ```
   _expect:_ networkMode is awsvpc / bridge / host as declared; attachments include the attached ENI for awsvpc tasks.

### Fix
1. **Switch to awsvpc mode (each task gets own IP, ports don't collide)**
   ```
   Update networkMode=awsvpc; networkConfiguration with subnets+SGs
   ```
   _validate:_ Multiple tasks on one instance
   _rollback:_ Revert to host
2. **Or use bridge mode with hostPort=0 (ephemeral)**
   ```
   Update task-def to networkMode=bridge, portMappings.hostPort=0; ALB target group uses dynamic port discovery
   ```
   _validate:_ Multiple tasks coexist via different ephemeral host ports

---

## `ecs.networking.fm.security-group-blocks-task-traffic` (conf 0.95)

**Symptom:** Task ENI security group denies egress (or ingress). App can't reach RDS, can't be reached by ALB targets, etc.

**Class:** security-group-misconfig

**Error patterns:** `connection refused` \| `connection timed out` \| `no route to host`


### Diagnose
1. **Identify task ENI**
   ```
   aws ecs describe-tasks --cluster <c> --tasks <arn> --query 'tasks[].attachments[].details'
   ```
   _expect:_ eni:eni-... and subnet/networkInterfaceId
2. **Inspect SG rules**
   ```
   aws ec2 describe-security-groups --group-ids <task-sg>
   ```
   _expect:_ Egress rules include the destination; ingress includes the expected source SG/IPs
3. **Use VPC Reachability Analyzer for E2E path**
   ```
   aws ec2 create-network-insights-path --source <task-eni> --destination <rds-eni> --protocol TCP --destination-port 5432; analyze
   ```
   _expect:_ Path REACHABLE

### Fix
1. **Add the missing rule to the task SG**
   ```
   aws ec2 authorize-security-group-egress --group-id <task-sg> --protocol tcp --port 5432 --cidr <rds-cidr>
   ```
   _validate:_ Connection succeeds
   _rollback:_ Revoke
2. **Update the security group / route table / task definition so the task can reach the target**
   ```
   aws ec2 authorize-security-group-egress --group-id <sg> --protocol tcp --port <port> --cidr <cidr>  # OR change subnet route, OR update task def 'awsvpcConfiguration.assignPublicIp'
   ```
   _validate:_ Re-run the connectivity test from inside the container; nslookup + curl now succeed.
   _rollback:_ aws ec2 revoke-security-group-egress with the same params; revert task def to prior revision.

---

## `ecs.task-defs.fm.cannot-pull-container-error-rate-limited` (conf 0.95)

**Symptom:** stoppedReason 'CannotPullContainerError: toomanyrequests: You have reached your pull rate limit. You may increase the limit by authenticating'.  Anonymous Docker Hub pull rate limit hit.

**Class:** registry-rate-limit

**Error patterns:** `toomanyrequests` \| `pull rate limit` \| `Docker Hub`


### Diagnose
1. **Confirm image is from docker.io anonymously**
   ```
   echo <image> | grep -E '^(docker.io/|[^/]+/[^/]+:)' (no registry prefix = docker.io)
   ```
   _expect:_ Docker Hub image
2. **Read the active task definition and the failing task's stoppedReason**
   ```
   aws ecs describe-task-definition --task-definition <family>:<revision> --query 'taskDefinition' --output json > /tmp/taskdef.json; aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].{stoppedReason,containers:containers[].{name,lastStatus,reason,exitCode}}'
   ```
   _expect:_ stoppedReason names the trigger (essential container exited, image-pull failure, ulimit etc.); container exitCode disambiguates app crash vs ECS stop.
3. **Validate the task definition against ECS task-def constraints**
   ```
   jq '{cpu, memory, networkMode, executionRoleArn, taskRoleArn, requiresCompatibilities, containerDefinitions:[.containerDefinitions[]|{name,image,essential,memoryReservation,memory,cpu,environment,secrets,logConfiguration}]}' /tmp/taskdef.json
   ```
   _expect:_ All container definitions have a logConfiguration; essential=true on at least one; executionRoleArn set if pulling from ECR/Secrets-Manager.

### Fix
1. **Mirror image to ECR (recommended for production)**
   ```
   aws ecr create-repository --repository-name mirror/<image>; docker pull <image>; docker tag ... ; docker push <ECR-URI>; update task def to use ECR URI
   ```
   _validate:_ Pulls from ECR; no Docker Hub rate limit
   _rollback:_ Revert task-def image
2. **Or authenticate to Docker Hub (raises rate limit)**
   ```
   Set ECS_ENGINE_AUTH_DATA on instance OR use repositoryCredentials with Secrets Manager
   ```
   _validate:_ Authenticated pulls have higher quota

---

## `ecs.task-defs.fm.essential-container-exited-app-crash` (conf 0.95)

**Symptom:** Task stops with stoppedReason 'Essential container in task exited' and container exitCode != 0. App crashed; ECS terminated the whole task.

**Class:** app-crash

**Error patterns:** `Essential container in task exited` \| `exitCode`


### Diagnose
1. **Check container exitCode**
   ```
   aws ecs describe-tasks --cluster <c> --tasks <arn> --query 'tasks[0].containers[].{name:name,exitCode:exitCode,reason:reason}'
   ```
   _expect:_ exitCode + reason for the essential container
2. **Read container logs**
   ```
   aws logs filter-log-events --log-group-name <group> --filter-pattern '' --start-time <ms-since-task-start>
   ```
   _expect:_ Stack trace / error message
3. **Read the active task definition and the failing task's stoppedReason**
   ```
   aws ecs describe-task-definition --task-definition <family>:<revision> --query 'taskDefinition' --output json > /tmp/taskdef.json; aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].{stoppedReason,containers:containers[].{name,lastStatus,reason,exitCode}}'
   ```
   _expect:_ stoppedReason names the trigger (essential container exited, image-pull failure, ulimit etc.); container exitCode disambiguates app crash vs ECS stop.

### Fix
1. **Fix the app and deploy a new task-def revision**
   ```
   Build → push → register-task-def → update-service
   ```
   _validate:_ App stays up
   _rollback:_ Roll back to previous revision via update-service --task-definition <family>:<old-revision>
2. **If crash is transient/non-deterministic, set deploymentCircuitBreaker.enable+rollback to auto-rollback failed deployments**
   ```
   Update service deploymentConfiguration
   ```
   _validate:_ Bad deployments auto-revert

---

## `ecs.task-defs.fm.placement-failure-resource-cpu-memory` (conf 0.95)

**Symptom:** RunTask fails synchronously with failures[].reason 'RESOURCE:CPU' or 'RESOURCE:MEMORY' — no instance has enough free capacity.

**Class:** cluster-capacity-exhausted

**Error patterns:** `RESOURCE:CPU` \| `RESOURCE:MEMORY` \| `no container instances were found`


### Diagnose
1. **Inspect cluster capacity**
   ```
   aws ecs describe-container-instances --cluster <c> --container-instances $(aws ecs list-container-instances --cluster <c> --query 'containerInstanceArns' --output text) --query 'containerInstances[].remainingResources'
   ```
   _expect:_ Sum of CPU/MEMORY across instances should fit the task
2. **Check task-def resource requests**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.{cpu:cpu,memory:memory}'
   ```
   _expect:_ Should fit on at least one instance
3. **Read the active task definition and the failing task's stoppedReason**
   ```
   aws ecs describe-task-definition --task-definition <family>:<revision> --query 'taskDefinition' --output json > /tmp/taskdef.json; aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].{stoppedReason,containers:containers[].{name,lastStatus,reason,exitCode}}'
   ```
   _expect:_ stoppedReason names the trigger (essential container exited, image-pull failure, ulimit etc.); container exitCode disambiguates app crash vs ECS stop.

### Fix
1. **Add capacity (scale ASG up, add instance, or use Fargate)**
   ```
   Increase ASG desiredCapacity OR run-task --launch-type FARGATE
   ```
   _validate:_ Task placed
2. **Reduce task resource requests if over-provisioned**
   ```
   Lower task-level cpu/memory; register new revision
   ```
   _validate:_ Task fits existing capacity
   _rollback:_ Restore

---

## `ecs.task-defs.fm.task-oom-killed` (conf 0.95)

**Symptom:** Task stops with stoppedReason 'OutOfMemoryError: Container killed due to memory usage'. Container hit its hard memory limit.

**Class:** container-cgroup-oom

**Error patterns:** `OutOfMemoryError` \| `memory limit` \| `OOMKilled`


### Diagnose
1. **Check container memory setting**
   ```
   aws ecs describe-task-definition --task-definition <family> --query 'taskDefinition.containerDefinitions[].{name:name,memory:memory,memoryReservation:memoryReservation}'
   ```
   _expect:_ Compare to actual usage from CloudWatch /aws/ecs/containerinsights/<cluster>/performance
2. **Inspect dmesg on container instance for OOM kill**
   ```
   ssh ec2-user@<instance>; sudo dmesg | grep -i 'killed process'
   ```
   _expect:_ OOM kill of the container's main process
3. **Read the active task definition and the failing task's stoppedReason**
   ```
   aws ecs describe-task-definition --task-definition <family>:<revision> --query 'taskDefinition' --output json > /tmp/taskdef.json; aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].{stoppedReason,containers:containers[].{name,lastStatus,reason,exitCode}}'
   ```
   _expect:_ stoppedReason names the trigger (essential container exited, image-pull failure, ulimit etc.); container exitCode disambiguates app crash vs ECS stop.

### Fix
1. **Raise container memory hard limit**
   ```
   Update task-def container.memory; register new revision; update service
   ```
   _validate:_ No more OOM kills under normal load
   _rollback:_ Restore prior limit
2. **Investigate memory leak in app**
   ```
   Run with profiler / heap dump; fix leaks
   ```
   _validate:_ RSS stable over time

---

## `ecs.troubleshooting.fm.amazon-linux-2-eol-2026-06-30` (conf 0.95)

**Symptom:** Cluster running ECS-Optimized AL2 AMI past 2026-06-30. No more security updates from upstream Amazon Linux 2.

**Class:** ami-eol

**Error patterns:** `AL2 EOL` \| `AmazonLinux2 unsupported` \| `deprecated AMI`


### Diagnose
1. **Check AMI variant on instances**
   ```
   aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].{Id:InstanceId,AMI:ImageId}'; cross-reference AMI name
   ```
   _expect:_ Migrate any AL2-based to AL2023
2. **Pull recent service events for the affected service (often the first signal)**
   ```
   aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:10]' --output table
   ```
   _expect:_ Service events name the immediate cause: scaled-in by ASG, task could not be placed, deregistered from target group, etc.
3. **Check container instance state + agent connectivity**
   ```
   aws ecs describe-container-instances --cluster <cluster> --container-instances $(aws ecs list-container-instances --cluster <cluster> --query 'containerInstanceArns' --output text) --query 'containerInstances[].{id:ec2InstanceId, status, agentConnected, runningTasksCount, registeredResources}' --output table
   ```
   _expect:_ All instances ACTIVE + agentConnected=true; sum of registeredResources still has headroom for the desired task placement.

### Fix
1. **Migrate AMIs to AL2023 ECS-Optimized**
   ```
   Update launch template / launch config to use SSM parameter /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id; rotate instances via DRAINING + ASG refresh
   ```
   _validate:_ All instances on AL2023; supported through 2028
   _rollback:_ Pin to AL2 AMI ID (insecure post-EOL)
2. **Apply the targeted remediation (capacity, health-check, IAM) and force a new deployment**
   ```
   aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment
   ```
   _validate:_ Service reaches steady state; events stream shows tasks reaching RUNNING and remaining stable for >2 min.
   _rollback:_ aws ecs update-service --task-definition <prior-rev> --desired-count <prior-count>

---

## `ecs.troubleshooting.fm.containerinsights-missing-metrics` (conf 0.95)

**Symptom:** CloudWatch Container Insights dashboard shows no data for an ECS cluster. Or partial data missing (e.g., per-container memory).

**Class:** container-insights-not-enabled

**Error patterns:** `No metrics in Container Insights` \| `ECS/ContainerInsights namespace empty`


### Diagnose
1. **Check cluster setting**
   ```
   aws ecs describe-clusters --clusters <c> --include SETTINGS --query 'clusters[].settings'
   ```
   _expect:_ containerInsights: enabled (or enhanced)
2. **Pull recent service events for the affected service (often the first signal)**
   ```
   aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:10]' --output table
   ```
   _expect:_ Service events name the immediate cause: scaled-in by ASG, task could not be placed, deregistered from target group, etc.
3. **Check container instance state + agent connectivity**
   ```
   aws ecs describe-container-instances --cluster <cluster> --container-instances $(aws ecs list-container-instances --cluster <cluster> --query 'containerInstanceArns' --output text) --query 'containerInstances[].{id:ec2InstanceId, status, agentConnected, runningTasksCount, registeredResources}' --output table
   ```
   _expect:_ All instances ACTIVE + agentConnected=true; sum of registeredResources still has headroom for the desired task placement.

### Fix
1. **Enable Container Insights on the cluster**
   ```
   aws ecs update-cluster-settings --cluster <c> --settings name=containerInsights,value=enabled
   ```
   _validate:_ Metrics flow within 5-15 min
   _rollback:_ value=disabled
2. **For per-container detail, use 'enhanced' (more cost)**
   ```
   aws ecs update-cluster-settings --cluster <c> --settings name=containerInsights,value=enhanced
   ```
   _validate:_ Per-container metrics appear
   _rollback:_ Back to 'enabled' or 'disabled'

---

## `ecs.troubleshooting.fm.fargate-spot-interruption` (conf 0.95)

**Symptom:** Fargate Spot tasks stopped with stoppedReason 'Spot capacity not available' or 'TerminationNotice'. AWS reclaimed Spot capacity.

**Class:** spot-capacity-reclaimed

**Error patterns:** `Spot capacity not available` \| `TerminationNotice` \| `SpotInterruption`


### Diagnose
1. **Confirm task was on Fargate Spot**
   ```
   aws ecs describe-tasks --cluster <c> --tasks <arn> --query 'tasks[0].capacityProviderName'
   ```
   _expect:_ FARGATE_SPOT
2. **Pull recent service events for the affected service (often the first signal)**
   ```
   aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:10]' --output table
   ```
   _expect:_ Service events name the immediate cause: scaled-in by ASG, task could not be placed, deregistered from target group, etc.
3. **Check container instance state + agent connectivity**
   ```
   aws ecs describe-container-instances --cluster <cluster> --container-instances $(aws ecs list-container-instances --cluster <cluster> --query 'containerInstanceArns' --output text) --query 'containerInstances[].{id:ec2InstanceId, status, agentConnected, runningTasksCount, registeredResources}' --output table
   ```
   _expect:_ All instances ACTIVE + agentConnected=true; sum of registeredResources still has headroom for the desired task placement.

### Fix
1. **Mix FARGATE + FARGATE_SPOT via capacityProviderStrategy with base on FARGATE**
   ```
   Update service: capacityProviderStrategy=[{cp:FARGATE,base:2,weight:1},{cp:FARGATE_SPOT,base:0,weight:9}] — first 2 tasks on guaranteed FARGATE
   ```
   _validate:_ Survives partial Spot interruption
   _rollback:_ All-FARGATE (more expensive but reliable)
2. **App: handle SIGTERM gracefully (2-min grace period)**
   ```
   Trap SIGTERM, drain connections, exit cleanly
   ```
   _validate:_ No connection-mid-flight loss on interruption

---

## `firecracker.networking.fm.guest-initiated-vsock-no-host-listener` (conf 0.95)

**Symptom:** Guest tries to vsock-connect to host CID=2 port N but receives VIRTIO_VSOCK_OP_RST. No process is listening on the host UDS at <uds_path>_<N>.

**Class:** missing-host-listener

**Error patterns:** `vsock RST` \| `ECONNREFUSED` \| `no listener at v.sock_<port>`


### Diagnose
1. **Check whether host listener exists**
   ```
   ss -lx | grep <uds_path>_<port>
   ```
   _expect:_ Listener present (LISTEN state on the UDS)
2. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.
3. **Inspect Firecracker process logs for the request that errored**
   ```
   journalctl -t firecracker -n 100 --no-pager | grep -iE 'error|warn|<interface-id>'
   ```
   _expect:_ Find the relevant API request and its rejection reason; cross-check against fc-docs-network-setup constraints.

### Fix
1. **Pre-create the host-side AF_UNIX listener BEFORE guest connects**
   ```
   host$ socat - UNIX-LISTEN:<uds_path>_<port>,fork
   ```
   _validate:_ Guest connect succeeds
2. **Build a generic per-port spawner on the host (e.g. systemd socket activation on UDS paths)**
   ```
   Configure systemd .socket unit for each expected port
   ```
   _validate:_ Listeners on demand

---

## `firecracker.networking.fm.ip-forward-disabled` (conf 0.95)

**Symptom:** Guest can't reach the internet through the host. Packets from the TAP never make it to the egress interface. Host has IPv4 forwarding disabled.

**Class:** host-routing-disabled

**Error patterns:** `no route to host` \| `100% packet loss to internet`


### Diagnose
1. **Check host ip_forward sysctl**
   ```
   sysctl net.ipv4.ip_forward
   ```
   _expect:_ Should be 1; if 0 → root cause
2. **Trace whether packets reach the TAP**
   ```
   host$ tcpdump -i tap0 -nn
   ```
   _expect:_ Outbound packets visible from guest
3. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.

### Fix
1. **Enable IPv4 forwarding (runtime + persistent)**
   ```
   echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward; echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
   ```
   _validate:_ Guest reaches internet
   _rollback:_ echo 0 > /proc/sys/net/ipv4/ip_forward
2. **Re-issue the API call with corrected payload, then start instance**
   ```
   curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/network-interfaces/eth0 -d '{"iface_id":"eth0","host_dev_name":"<tap>"}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ API returns 204 No Content for PUT and InstanceStart; instance enters Running state.
   _rollback:_ Stop the VM (PUT /actions {action_type: SendCtrlAltDel} for x86_64 or destroy the process) and undo TAP changes.

---

## `firecracker.networking.fm.missing-virtio-vsockets-config` (conf 0.95)

**Symptom:** Guest doesn't see /dev/vsock. PUT /vsock attached the device on Firecracker side but guest kernel lacks CONFIG_VIRTIO_VSOCKETS.

**Class:** guest-kernel-config-missing

**Error patterns:** `/dev/vsock missing` \| `no virtio-vsock driver`


### Diagnose
1. **Check guest kernel config**
   ```
   guest$ zcat /proc/config.gz | grep CONFIG_VIRTIO_VSOCKETS
   ```
   _expect:_ =y or =m
2. **Verify /dev/vsock**
   ```
   guest$ ls -la /dev/vsock
   ```
   _expect:_ Char device should exist
3. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.

### Fix
1. **Rebuild guest kernel with CONFIG_VIRTIO_VSOCKETS=y**
   ```
   Edit .config; make olddefconfig; make -j
   ```
   _validate:_ /dev/vsock appears
   _rollback:_ Revert kernel
2. **Re-issue the API call with corrected payload, then start instance**
   ```
   curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/network-interfaces/eth0 -d '{"iface_id":"eth0","host_dev_name":"<tap>"}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ API returns 204 No Content for PUT and InstanceStart; instance enters Running state.
   _rollback:_ Stop the VM (PUT /actions {action_type: SendCtrlAltDel} for x86_64 or destroy the process) and undo TAP changes.

---

## `firecracker.networking.fm.mmds-data-lost-on-snapshot` (conf 0.95)

**Symptom:** After snapshot restore, MMDS GETs return empty/old data. The MMDS data store is intentionally not persisted across snapshots.

**Class:** intentional-non-persistence

**Error patterns:** `MMDS data missing after restore` \| `metadata empty`


### Diagnose
1. **Confirm MMDS configuration survived (only data is dropped)**
   ```
   GET /mmds/config
   ```
   _expect:_ version, network_interfaces, ipv4_address all preserved; data store empty
2. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.
3. **Inspect Firecracker process logs for the request that errored**
   ```
   journalctl -t firecracker -n 100 --no-pager | grep -iE 'error|warn|<interface-id>'
   ```
   _expect:_ Find the relevant API request and its rejection reason; cross-check against fc-docs-network-setup constraints.

### Fix
1. **Orchestrator must reseed MMDS after every restore**
   ```
   PUT /mmds <fresh-payload> right after PUT /snapshot/load
   ```
   _validate:_ MMDS GET returns expected data
2. **Re-issue the API call with corrected payload, then start instance**
   ```
   curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/network-interfaces/eth0 -d '{"iface_id":"eth0","host_dev_name":"<tap>"}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ API returns 204 No Content for PUT and InstanceStart; instance enters Running state.
   _rollback:_ Stop the VM (PUT /actions {action_type: SendCtrlAltDel} for x86_64 or destroy the process) and undo TAP changes.

---

## `firecracker.networking.fm.mmds-v1-ssrf-vulnerability` (conf 0.95)

**Symptom:** Untrusted guest workload (e.g., AI agent fetching arbitrary URLs) reads sensitive metadata from MMDS via SSRF. MMDS V1 has no token requirement.

**Class:** mmds-v1-deprecated-no-auth

**Error patterns:** `unauthorized metadata exfiltration` \| `SSRF to MMDS`


### Diagnose
1. **Check MMDS version**
   ```
   GET /mmds/config | jq '.version'
   ```
   _expect:_ If 'V1' (or absent → defaults to V1) → vulnerability confirmed
2. **Check Firecracker metrics for evidence of token abuse**
   ```
   Inspect mmds.rx_no_token + mmds.rx_invalid_token counters in metrics output
   ```
   _expect:_ Non-zero → workloads accessing without tokens
3. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.

### Fix
1. **Migrate MMDS to V2 (session-token-required)**
   ```
   PUT /mmds/config {network_interfaces: [...], version: 'V2', ipv4_address: '169.254.169.254'}
   ```
   _validate:_ MMDS rejects unauthenticated GETs; rx_no_token metric stops growing for new workloads
   _rollback:_ Revert to V1 (insecure)
2. **Audit guest workloads to use the V2 PUT-token-then-GET pattern**
   ```
   Update guest tooling to issue PUT /latest/api/token first
   ```
   _validate:_ Guest reads succeed via tokenized path

---

## `firecracker.networking.fm.nat-masquerade-rule-missing` (conf 0.95)

**Symptom:** Guest packets reach the host's egress interface but have non-routable source IPs. NAT masquerade rule isn't installed.

**Class:** missing-nat-rule

**Error patterns:** `packets dropped at upstream router` \| `source IP unrouteable`


### Diagnose
1. **Inspect nftables/iptables NAT rules**
   ```
   sudo nft list ruleset; OR sudo iptables-nft -t nat -S POSTROUTING
   ```
   _expect:_ MASQUERADE rule for guest IP/subnet → egress iface
2. **Trace upstream packet src**
   ```
   host$ tcpdump -i eth0 -nn 'src host <guest-ip>'
   ```
   _expect:_ Without MASQUERADE: packets visible with raw guest IP (172.16.x.x — non-routable)
3. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.

### Fix
1. **Install MASQUERADE rule**
   ```
   sudo nft add table firecracker; sudo nft 'add chain firecracker postrouting { type nat hook postrouting priority srcnat; policy accept; }'; sudo nft add rule firecracker postrouting ip saddr <guest-ip> oifname <egress> counter masquerade; sudo nft add rule firecracker filter iifname <tap> oifname <egress> accept
   ```
   _validate:_ Guest reaches internet
   _rollback:_ sudo nft delete table firecracker
2. **Re-issue the API call with corrected payload, then start instance**
   ```
   curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/network-interfaces/eth0 -d '{"iface_id":"eth0","host_dev_name":"<tap>"}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ API returns 204 No Content for PUT and InstanceStart; instance enters Running state.
   _rollback:_ Stop the VM (PUT /actions {action_type: SendCtrlAltDel} for x86_64 or destroy the process) and undo TAP changes.

---

## `firecracker.networking.fm.uds-path-collision-clones` (conf 0.95)

**Symptom:** Two restored clones of the same snapshot collide on the same vsock UDS path. Second restore fails (or worse: succeeds and steps on the first clone's UDS).

**Class:** snapshot-clone-uds-collision

**Error patterns:** `UDS path in use` \| `address already in use` \| `vsock collision`


### Diagnose
1. **Inspect both clones' configured UDS paths**
   ```
   GET /vm/config (on each)
   ```
   _expect:_ Same uds_path → collision
2. **Check Firecracker API state for the affected interface/socket**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces
   ```
   _expect:_ Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.
3. **Inspect Firecracker process logs for the request that errored**
   ```
   journalctl -t firecracker -n 100 --no-pager | grep -iE 'error|warn|<interface-id>'
   ```
   _expect:_ Find the relevant API request and its rejection reason; cross-check against fc-docs-network-setup constraints.

### Fix
1. **Use vsock_override on snapshot/load to give each clone a unique UDS path**
   ```
   PUT /snapshot/load {..., vsock_override: {uds_path: '/clones/v.sock.<id>'}}
   ```
   _validate:_ Each clone has its own UDS
2. **Use jailer per clone — each gets its own chroot, paths are naturally isolated**
   ```
   Wrap each FC in jailer with unique --id (which becomes the chroot leaf)
   ```
   _validate:_ Per-chroot UDS paths can't collide

---

## `firecracker.setup.fm.action-without-prerequisites` (conf 0.95)

**Symptom:** PUT /actions {action_type: InstanceStart} returns 400. Required pre-boot resources aren't all configured.

**Class:** missing-pre-boot-config

**Error patterns:** `InstanceStart 400` \| `boot source not configured` \| `machine config not set`


### Diagnose
1. **Inspect what's been configured**
   ```
   GET /vm/config | jq '."boot-source", ."machine-config", .drives'
   ```
   _expect:_ boot-source non-null; machine-config non-null; ≥1 drive
2. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.
3. **Check Firecracker process exit status / log for setup errors**
   ```
   journalctl -t firecracker -n 200 --no-pager | tail -60
   ```
   _expect:_ No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.

### Fix
1. **Configure each missing resource before InstanceStart**
   ```
   PUT /boot-source; PUT /machine-config; PUT /drives/<id> with is_root_device=true; (optional: /network-interfaces, /vsock, etc.); THEN PUT /actions
   ```
   _validate:_ InstanceStart returns 204
2. **Apply the missing/corrected configuration via PUT or PATCH then start**
   ```
   curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/machine-config -d '{"vcpu_count":2,"mem_size_mib":1024}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ Both API calls return 204; subsequent GET /vm/config reflects the change.
   _rollback:_ PATCH back to original values; or stop and re-create the microVM.

---

## `firecracker.setup.fm.api-on-tcp-not-uds-attempt` (conf 0.95)

**Symptom:** Operator attempts to bind the Firecracker API to a TCP port. Firecracker only accepts UDS transport.

**Class:** fundamental-design-misunderstanding

**Error patterns:** `TCP bind attempted` \| `API socket type wrong`


### Diagnose
1. **Check firecracker --help and CLI args**
   ```
   firecracker --help | grep -i sock
   ```
   _expect:_ Only --api-sock <path> exists; no TCP option
2. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.
3. **Check Firecracker process exit status / log for setup errors**
   ```
   journalctl -t firecracker -n 200 --no-pager | tail -60
   ```
   _expect:_ No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.

### Fix
1. **Use UDS; bridge to TCP via socat or similar if remote access needed**
   ```
   socat TCP-LISTEN:8080,fork UNIX-CONNECT:/tmp/firecracker.socket
   ```
   _validate:_ TCP clients can reach the API; security: protect with firewall + auth proxy
   _rollback:_ Kill the socat bridge
2. **For multi-host orchestration, use a per-host control plane that holds UDS local and exposes its own auth'd API**
   ```
   Architectural — orchestrator owns the UDS, exposes a tenant-isolated REST/gRPC
   ```

---

## `firecracker.setup.fm.drive-backing-file-missing` (conf 0.95)

**Symptom:** PUT /drives returns 400 with 'Block device backing file does not exist' or InstanceStart fails reading the disk.

**Class:** missing-host-file

**Error patterns:** `backing file does not exist` \| `ENOENT` \| `block device error`


### Diagnose
1. **Check the configured path_on_host (resolved relative to chroot if jailed)**
   ```
   ls -la <chroot>/<path_on_host>
   ```
   _expect:_ File exists and is readable by the FC uid
2. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.
3. **Check Firecracker process exit status / log for setup errors**
   ```
   journalctl -t firecracker -n 200 --no-pager | tail -60
   ```
   _expect:_ No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.

### Fix
1. **Copy/bind-mount the backing file into the chroot before PUT /drives**
   ```
   Inside jail setup: cp <host-path> <chroot>/<inside-path>; chown <fc-uid>
   ```
   _validate:_ Drive attaches
2. **Or pass the file via --bind-mount in your jailer setup script**
   ```
   Use a wrapper that mounts the host path into the chroot read-only or read-write
   ```
   _validate:_ FC sees file at the configured chroot-relative path

---

## `firecracker.setup.fm.drive-unsafe-cache-data-loss` (conf 0.95)

**Symptom:** Host crashes; on reboot, guest filesystem is corrupted or 'recently committed' data is missing. Drive was attached with cache_type=Unsafe — guest fsync()s were dropped.

**Class:** drive-cache-misconfiguration

**Error patterns:** `fsck errors after host crash` \| `data missing after crash`


### Diagnose
1. **Check drive cache_type**
   ```
   GET /vm/config | jq '.drives[].cache_type'
   ```
   _expect:_ 'Writeback' for any drive holding non-ephemeral data
2. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.
3. **Check Firecracker process exit status / log for setup errors**
   ```
   journalctl -t firecracker -n 200 --no-pager | tail -60
   ```
   _expect:_ No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.

### Fix
1. **Restart microVM with cache_type=Writeback for persistent drives**
   ```
   Pre-boot: PUT /drives/<id> {..., cache_type: 'Writeback'}
   ```
   _validate:_ fsync calls propagate to host
   _rollback:_ cache_type=Unsafe (faster, unsafe)
2. **Apply the missing/corrected configuration via PUT or PATCH then start**
   ```
   curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/machine-config -d '{"vcpu_count":2,"mem_size_mib":1024}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ Both API calls return 204; subsequent GET /vm/config reflects the change.
   _rollback:_ PATCH back to original values; or stop and re-create the microVM.

---

## `firecracker.setup.fm.host-kernel-logs-slow-snapshot-restore` (conf 0.95)

**Symptom:** Snapshot restore time degrades inexplicably (e.g., 3ms → 8.5ms on aarch64) after host kernel cmdline change. Host kernel logging hot during TAP create — synchronous console writes hold up the FC main thread.

**Class:** host-console-blocking-fc-syscalls

**Error patterns:** `snapshot restore slow` \| `host kernel log spam`


### Diagnose
1. **Inspect host kernel cmdline**
   ```
   cat /proc/cmdline
   ```
   _expect:_ Should contain `quiet loglevel=1`; any console=ttyAMA0 / console=ttyS0 is suspect
2. **Check dmesg log volume during restore**
   ```
   dmesg -c; trigger restore; dmesg | wc -l
   ```
   _expect:_ Few lines if quiet loglevel=1 is set
3. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.

### Fix
1. **Add quiet loglevel=1 to host kernel cmdline; remove any console= entries**
   ```
   Edit /etc/default/grub GRUB_CMDLINE_LINUX; update-grub; reboot
   ```
   _validate:_ Restore time returns to baseline
   _rollback:_ Revert grub config
2. **Apply the missing/corrected configuration via PUT or PATCH then start**
   ```
   curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/machine-config -d '{"vcpu_count":2,"mem_size_mib":1024}' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d '{"action_type":"InstanceStart"}'
   ```
   _validate:_ Both API calls return 204; subsequent GET /vm/config reflects the change.
   _rollback:_ PATCH back to original values; or stop and re-create the microVM.

---

## `firecracker.setup.fm.ksm-enabled-side-channel-risk` (conf 0.95)

**Symptom:** Multi-tenant host has KSM (Kernel Samepage Merging) enabled. Page-deduplication side channels exploitable — one tenant can detect another's memory contents.

**Class:** host-hardening-missing

**Error patterns:** `/sys/kernel/mm/ksm/run = 1` \| `KSM merging active`


### Diagnose
1. **Check KSM state**
   ```
   cat /sys/kernel/mm/ksm/run /sys/kernel/mm/ksm/pages_shared
   ```
   _expect:_ run=0; pages_shared=0
2. **Read current Firecracker configuration**
   ```
   curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .
   ```
   _expect:_ All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.
3. **Check Firecracker process exit status / log for setup errors**
   ```
   journalctl -t firecracker -n 200 --no-pager | tail -60
   ```
   _expect:_ No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.

### Fix
1. **Disable KSM and unmerge**
   ```
   echo 0 | sudo tee /sys/kernel/mm/ksm/run
   ```
   _validate:_ run=0; pages_shared decreases over time
   _rollback:_ echo 1 > /sys/kernel/mm/ksm/run
2. **Make persistent via systemd unit**
   ```
   Add a systemd unit that sets ksm/run=0 at boot; or set kernel.ksm_run=0 sysctl if your distro maps it
   ```
   _validate:_ Survives reboot
