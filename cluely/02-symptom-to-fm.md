# 02 — Symptom → fm-id mapping

> When the user describes a symptom, find it here, then `ha "<keyword>"` or `hp <fm-id>` directly.
>
> Auto-generated from `_db/knowledge.duckdb` — re-run `pnpm cluely` after corpus changes.

This doc lists 351 high-confidence (≥ 0.85) failure modes grouped by domain. For full diag + fix per fm, see [03-top-failure-modes.md](03-top-failure-modes.md). For the commands cited, see [04-diagnostic-commands.md](04-diagnostic-commands.md).


## docker (67 fms)

| Symptom | fm-id | call |
|---|---|---|
| Container exited with code 137; `docker inspect` shows OOMKilled=true | `docker.fm.exit-137-oomkilled` | `ha "exit code 137"` |
| `docker run --security-opt apparmor=docker-custom` fails 'apparmor profile not loaded' | `docker.fm.apparmor-profile-not-loaded` | `ha "apparmor profile"` |
| `docker run -v /host/path:/container/path` 'succeeds' even though /host/path doesn't exist; containe | `docker.fm.bind-mount-source-missing` | `ha "mount source missing"` |
| Bind-mounted shell script fails 'no such file' or '/bin/sh^M: bad interpreter' on Linux container | `docker.fm.bind-mount-windows-line-ending` | `ha "^m"` |
| `docker buildx build -t app .` succeeds but `docker images` doesn't list `app` | `docker.fm.buildkit-output-no-load` | `ha "images empty"` |
| Secret accidentally baked into image (visible in `docker history`) | `docker.fm.buildkit-secret-leaked` | `ha "secret in image"` |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | `docker.fm.cannot-connect-daemon` | `ha "cannot connect to the docker daemon"` |
| `docker run --cap-drop=NET_ADMIN` and yet container can still configure network interfaces | `docker.fm.cap-not-actually-dropped` | `ha "net_admin"` |
| Multi-stage Dockerfile: ARG declared at top but value undefined inside a later FROM stage | `docker.fm.compose-build-args-not-passed-to-stage` | `ha "arg"` |
| Service starts before dependency is actually ready (e.g. app errors connecting to DB despite depends | `docker.fm.compose-depends-on-wrong` | `ha "connection refused"` |
| `docker compose up` doesn't start a service that has `profiles: [debug]` even with `--profile debug` | `docker.fm.compose-profile-not-applied` | `ha "profile"` |
| `COPY --from=builder /out/app /app` fails: 'invalid from flag value builder: stage not found' | `docker.fm.copy-from-stage-not-found` | `ha "stage not found"` |
| `docker stop` takes 10 seconds before container exits (then SIGKILL) | `docker.fm.docker-stop-hangs-10s` | `ha "timeout exceeded"` |
| `docker -H tcp://host:2376 ps` fails 'x509: certificate has expired' | `docker.fm.dockerd-tls-cert-expired` | `ha "x509"` |
| `docker exec -it <c> bash` works but typed keys don't reach shell | `docker.fm.exec-tty-no-input` | `ha "tty"` |
| `docker pull` from private registry fails 'unauthorized: incorrect username or password' OR 'denied: | `docker.fm.image-pull-private-registry-auth` | `ha "unauthorized"` |
| After running `iptables -F`, all docker port publishing breaks until daemon restart | `docker.fm.iptables-docker-chain-flushed` | `ha "iptables -f"` |
| `docker run` on IPv6-only network fails to assign address; container has no IPv6 connectivity | `docker.fm.ipv6-not-enabled` | `ha "ipv6"` |
| `docker inspect` shows exit code like 137, 139, 143; user wonders what they mean | `docker.fm.runc-exit-128-plus-signum` | `ha "exit code 137"` |
| `docker run` (rootless) fails: 'newuidmap: command not found' or 'unable to set up uid mapping' | `docker.fm.runc-rootless-newuidmap-missing` | `ha "newuidmap"` |
| Defunct/zombie processes accumulating inside container; `ps` shows multiple <defunct> entries | `docker.fm.zombie-processes-leaking` | `ha "<defunct>"` |
| `docker pull` or `docker run` fails 'no space left on device'; `df` shows host has space | `docker.fm.disk-full-but-df-shows-free` | `ha "no space left on device"` |
| `docker network create` fails 'all predefined address pools have been fully subnetted' or container  | `docker.fm.bridge-ip-pool-exhausted` | `ha "address pool"` |
| Dockerfile parser feature (heredoc `<<EOF`, `--mount=type=secret`) errors as 'unknown flag' on older | `docker.fm.buildkit-frontend-version-pinning` | `ha "unknown flag"` |
| `RUN --mount=type=secret,id=foo cat /run/secrets/foo` returns empty file or 'No such file' inside bu | `docker.fm.buildkit-secret-not-mounted` | `ha "secret"` |

## linux (80 fms)

| Symptom | fm-id | call |
|---|---|---|
| `mount --bind -o ro` doesn't actually mark target readonly | `linux.fm.bind-mount-readonly-leak` | `ha "bind mount"` |
| Process killed by OOM but free memory available system-wide | `linux.fm.cgroup-memory-oom-kill` | `ha "killed"` |
| Cannot move a process into a cgroup that already has child cgroups: EBUSY | `linux.fm.cgroup-no-internal-process-rule` | `ha "ebusy"` |
| Setting memory.max in a cgroup has no effect; child cgroups can't be created with memory limits | `linux.fm.cgroup-v2-controller-not-enabled` | `ha "no such file or directory"` |
| `nf_conntrack: table full, dropping packet` in dmesg; new connections silently fail | `linux.fm.conntrack-table-full` | `ha "nf_conntrack: table full"` |
| CPU usage low but app slow; cpu.stat shows nr_throttled > 0 | `linux.fm.cpu-throttled` | `ha "throttled_usec"` |
| `df` shows free space but writes fail ENOSPC | `linux.fm.disk-full-but-df-shows-free-space` | `ha "no space left on device"` |
| DNS queries slow inside container; first lookup takes multi-second | `linux.fm.dns-slow-ndots` | `ha "search list expansion"` |
| App using EPOLLET stops getting events for some FDs even though data arrived | `linux.fm.epoll-edge-trigger-starvation` | `ha "epollet"` |
| App fails 'Too many open files' (EMFILE) | `linux.fm.fd-leak` | `ha "too many open files"` |
| Flame graph shows shallow stacks; symbols mostly '[unknown]' | `linux.fm.flame-graph-flat` | `ha "[unknown]"` |
| fork()/clone() returns EAGAIN | `linux.fm.fork-eagain` | `ha "eagain"` |
| `gdb -p <pid>` fails 'ptrace: Operation not permitted' | `linux.fm.gdb-ptrace-restricted-yama` | `ha "ptrace"` |
| Editor (vscode/jetbrains) fails to watch project: 'too many open files' or watches dropped | `linux.fm.inotify-watch-limit` | `ha "no space left"` |
| Linux router not forwarding packets between interfaces | `linux.fm.ip-forward-disabled` | `ha "no route"` |
| After kernel panic, no /var/crash/* dump produced | `linux.fm.kdump-no-crashkernel` | `ha "kdump"` |
| `df` shows disk full but `du` adds up to less; `lsof \| grep deleted` shows large files | `linux.fm.lsof-shows-deleted` | `ha "deleted"` |
| Allow rule placed but traffic still blocked; jump to chain returns earlier | `linux.fm.netfilter-rule-order` | `ha "nftables"` |
| `umount` fails 'target is busy' even after killing all visible users | `linux.fm.path-busy-cant-unmount` | `ha "target is busy"` |
| `perf record` fails 'Permission denied' or 'No permission' | `linux.fm.perf-event-paranoid-blocks` | `ha "permission denied"` |
| `ps` inside container shows accumulating <defunct> processes; PID 1 ignores SIGCHLD | `linux.fm.pid1-not-reaping-zombies` | `ha "<defunct>"` |
| User code can't write to its own cgroup tree even though it owns the slice | `linux.fm.systemd-cgroup-delegation-missing` | `ha "eacces"` |
| systemd `<mount>.mount` unit failed; fstab entry has typo or invalid options | `linux.fm.systemd-mount-failed-fstab` | `ha "failed to mount"` |
| Long-running systemd service killed before finishing graceful shutdown | `linux.fm.systemd-service-killed-on-shutdown` | `ha "timeoutstopsec"` |
| systemd .timer skipped firings; OnCalendar=daily missed days | `linux.fm.systemd-timer-skipped` | `ha "timer"` |

## k8s (61 fms)

| Symptom | fm-id | call |
|---|---|---|
| Pod creation hangs and times out: 'webhook denied: context deadline exceeded' | `k8s.fm.admission-webhook-timeout` | `ha "webhook"` |
| ConfigMap edited but pod doesn't see new value | `k8s.fm.configmap-not-updating` | `ha "stale config"` |
| CoreDNS pods CrashLoopBackOff with 'Loop (127.0.0.1:53 -> :53)' | `k8s.fm.coredns-loop-detection` | `ha "loop"` |
| Pod CrashLoopBackOff: container repeatedly crashing | `k8s.fm.crashloopbackoff` | `ha "crashloopbackoff"` |
| `crictl ps` returns empty even though kubelet runs pods | `k8s.fm.crictl-ps-empty` | `ha "crictl"` |
| `kubectl rollout status` reports 'paused'; pods don't update | `k8s.fm.deployment-stuck-ConditionPaused` | `ha "paused"` |
| DNS lookups inside pods take 3-5 seconds for external hostnames (api.stripe.com, s3.amazonaws.com) — | `k8s.fm.dns-pod-search-too-many` | `ha "search"` |
| Pod ImagePullBackOff or ErrImagePull | `k8s.fm.imagepullbackoff` | `ha "imagepullbackoff"` |
| Ingress shows 'failed to get certificate'; TLS endpoint not reachable | `k8s.fm.ingress-tls-secret-missing` | `ha "tls"` |
| `kubectl` lands in wrong cluster (prod vs staging); accidental damage risk | `k8s.fm.kubeconfig-context-wrong` | `ha "wrong cluster"` |
| Slow-to-start app keeps getting killed by livenessProbe | `k8s.fm.liveness-killing-slow-starter` | `ha "liveness probe failed"` |
| Container OOMKilled (exit 137) inside pod | `k8s.fm.oomkilled` | `ha "oomkilled"` |
| Pod stuck Pending; events show FailedScheduling | `k8s.fm.pod-pending-failedscheduling` | `ha "failedscheduling"` |
| Burstable QoS pods evicted before guaranteed pods under memory pressure | `k8s.fm.qos-class-burstable-eviction` | `ha "evicted"` |
| `Forbidden: User cannot list resource X in namespace Y` | `k8s.fm.rbac-permission-denied` | `ha "forbidden"` |
| Service exists but no endpoints; clients can't reach | `k8s.fm.service-no-endpoints` | `ha "no endpoints"` |
| Pods stuck Pending with FailedScheduling due to taint X but pod has no matching toleration | `k8s.fm.taint-toleration-mismatch` | `ha "had taints"` |
| App slow but `kubectl top` shows low CPU | `k8s.fm.cpu-throttled` | `ha "throttled"` |
| Custom resource stuck Terminating; controller's finalizer never removed | `k8s.fm.controller-stuck-on-crd-finalizer` | `ha "finalizer"` |
| `kubectl apply` fails 'unknown field' or 'invalid' for a CRD field that should exist | `k8s.fm.crd-openapi-validation-mismatch` | `ha "unknown field"` |
| CronJob's pods/jobs immediately deleted; can't inspect failed runs | `k8s.fm.cronjob-ttl-cleaning-too-aggressive` | `ha "ttl"` |
| Pod can't resolve DNS at all (NXDOMAIN for everything) | `k8s.fm.dns-resolution-fail` | `ha "could not resolve"` |
| `kubectl debug` fails 'ephemeral containers feature is not enabled' | `k8s.fm.ephemeral-container-debug-not-supported` | `ha "ephemeral container"` |
| etcd disk usage growing despite low key count; alarm 'NOSPACE' | `k8s.fm.etcd-defrag-needed` | `ha "nospace"` |
| Pods evicted with reason 'Evicted'; status.message about node-pressure | `k8s.fm.evicted-by-node-pressure` | `ha "evicted"` |

## devin (19 fms)

| Symptom | fm-id | call |
|---|---|---|
| Snapshot build failed; build log shows YAML parse error or unsupported directive | `devin.fm.build-failed-blueprint-error` | `ha "yaml parse error"` |
| Build fails: git clone error | `devin.fm.repo-clone-failed` | `ha "clone failed"` |
| Sessions stop running mid-month; ACU cap reached | `devin.fm.acu-budget-exhausted` | `ha "acu limit"` |
| Build step times out after 1 hour; build fails | `devin.fm.build-step-timeout-1h` | `ha "build timeout"` |
| Setup fails behind corporate proxy: 'Could not resolve host' or proxy 407 | `devin.fm.corporate-proxy-not-set` | `ha "proxy"` |
| Build fails 'No space left on device' inside DevBox | `devin.fm.devbox-disk-full` | `ha "no space left on device"` |
| Devin's GitHub PRs fail 'Resource not accessible by integration' after repo settings change | `devin.fm.github-app-perms-stale` | `ha "resource not accessible"` |
| Devin's curl/git fails 'self-signed certificate' or 'unable to get issuer' | `devin.fm.internal-svc-cert-untrusted` | `ha "self-signed"` |
| npm install / pip install fails on private packages despite credentials in env | `devin.fm.private-pkg-pull-fail` | `ha "eacces"` |
| DevBox can't pull from private container registry / npm registry | `devin.fm.private-registry-pull-fail` | `ha "unauthorized"` |
| Devin can't post to Slack channel: 'invalid_auth' or 'token_revoked' | `devin.fm.slack-integration-stale-token` | `ha "invalid_auth"` |
| Single session burns hundreds of ACUs; checking takes hours | `devin.fm.acu-burn-runaway` | `ha "acu"` |
| Devin API client gets HTTP 429 | `devin.fm.api-rate-limit` | `ha "429"` |
| Devin tells you 'app listening on :8080' but you can't reach it via shared URL | `devin.fm.devbox-port-not-exposed` | `ha "port"` |
| Adding new Knowledge entry fails 'limit reached' | `devin.fm.knowledge-cap-hit` | `ha "knowledge limit"` |
| Setup script fails 'Permission denied (publickey)' or 'fatal: could not read Username for https' | `devin.fm.repo-clone-https-vs-ssh` | `ha "permission denied"` |
| Devin DevBox can't reach internal/private service (staging.internal.acme.io). Session log: 'Could no | `devin.fm.session-cant-reach-internal-svc` | `ha "could not connect"` |
| Devin session shows 'failed to start' / DevBox provisioning error | `devin.fm.session-failed-to-start` | `ha "devbox provisioning failed"` |
| Devin runs `npm install` at session start (stale snapshot); session takes long to set up | `devin.fm.snapshot-stale-deps` | `ha "installing dependencies"` |

## methodology (27 fms)

| Symptom | fm-id | call |
|---|---|---|
| BCC tool (e.g. opensnoop, biolatency) not found on prod host during incident | `methodology.fm.bpf-tool-not-found` | `ha "command not found"` |
| Flame graph generated but appears flat / shallow; symbols mostly '[unknown]' | `methodology.fm.flame-graph-flat` | `ha "flame graph flat"` |
| Same alert pages 30+ times in an hour; oncall demoralized | `methodology.fm.pager-thrash-from-flap` | `ha "pager"` |
| Team reports 'p99 latency 50ms' but users complain about 5s requests | `methodology.fm.percentile-vs-mean-confusion` | `ha "p99"` |
| SLO breach detected too late; only after error budget exhausted | `methodology.fm.slo-no-burn-rate-alert` | `ha "slo"` |
| 5-whys analysis terminates with 'human error' or 'process broken'; no actionable cause | `methodology.fm.5whys-not-finding-root` | `ha "5 whys"` |
| Postmortem action items pile up; never completed; same incident recurs | `methodology.fm.action-items-never-done` | `ha "action items"` |
| Operators stop responding to alerts; everyone knows they're noise | `methodology.fm.alert-fatigue` | `ha "alert fatigue"` |
| New service hits scale-related issue at 'random' load; no headroom indicator before failure | `methodology.fm.capacity-planning-without-baseline` | `ha "capacity"` |
| App is slow under load but `top`/`kubectl top` shows low CPU usage (e.g. 35%) and no errors. RED met | `methodology.fm.cpu-utilization-misleading` | `ha "high cpu"` |
| Operator can't find signal on Grafana board; ignores dashboard during incident | `methodology.fm.dashboard-too-many-metrics` | `ha "too many metrics"` |
| SLO breach; error budget at zero; team must halt feature work | `methodology.fm.error-budget-exhausted` | `ha "error budget exhausted"` |
| Engineer reads flame graph as 'time' but it's 'samples'; wrong conclusion drawn | `methodology.fm.flame-graph-misread` | `ha "flame graph"` |
| bpftrace kprobe attach fails — function not found | `methodology.fm.kprobe-attach-fails` | `ha "function not found"` |
| User reports 'system slow' but no baseline metrics to compare against | `methodology.fm.no-baseline-cant-debug` | `ha "no baseline"` |
| During incident, no clear lead; multiple people stepping on each other; chaotic comms | `methodology.fm.no-incident-commander` | `ha "chaos in incident"` |
| Incoming oncall doesn't know about ongoing incidents/anomalies from previous shift | `methodology.fm.oncall-handoff-info-loss` | `ha "handoff"` |
| Oncall follows runbook; commands fail or return unrelated info because system has changed | `methodology.fm.runbook-stale` | `ha "runbook"` |
| Incident response slow; many people in war-room ask repeated questions | `methodology.fm.war-room-too-many-people` | `ha "war room"` |
| Investigating service-throughput problem with USE Method finds nothing useful (or vice versa) | `methodology.fm.applied-wrong-method` | `ha "use method blank"` |
| Service passes synthetic load test but fails in production at lower QPS | `methodology.fm.benchmark-not-realistic` | `ha "benchmark"` |
| Prometheus storage growing fast; queries timing out | `methodology.fm.metric-cardinality-explosion` | `ha "cardinality explosion"` |
| Engineer reluctant to participate in postmortem; team morale damaged | `methodology.fm.postmortem-blame` | `ha "blame culture"` |
| Postmortem turns into blame; engineer at risk of leaving; adjacent teams now avoiding deploy assignm | `methodology.fm.retro-becomes-trial` | `ha "blame"` |
| Different teams cite conflicting numbers for same metric (request rate, error budget remaining) | `methodology.fm.single-source-of-truth-broken` | `ha "conflicting"` |

## firecracker (56 fms)

| Symptom | fm-id | call |
|---|---|---|
| Guest tries to vsock-connect to host CID=2 port N but receives VIRTIO_VSOCK_OP_RST. No process is li | `firecracker.networking.fm.guest-initiated-vsock-no-host-listener` | `ha "vsock rst"` |
| Guest can't reach the internet through the host. Packets from the TAP never make it to the egress in | `firecracker.networking.fm.ip-forward-disabled` | `ha "no route to host"` |
| Guest doesn't see /dev/vsock. PUT /vsock attached the device on Firecracker side but guest kernel la | `firecracker.networking.fm.missing-virtio-vsockets-config` | `ha "/dev/vsock missing"` |
| After snapshot restore, MMDS GETs return empty/old data. The MMDS data store is intentionally not pe | `firecracker.networking.fm.mmds-data-lost-on-snapshot` | `ha "mmds data missing after restore"` |
| Untrusted guest workload (e.g., AI agent fetching arbitrary URLs) reads sensitive metadata from MMDS | `firecracker.networking.fm.mmds-v1-ssrf-vulnerability` | `ha "unauthorized metadata exfiltration"` |
| Guest packets reach the host's egress interface but have non-routable source IPs. NAT masquerade rul | `firecracker.networking.fm.nat-masquerade-rule-missing` | `ha "packets dropped at upstream router"` |
| Two restored clones of the same snapshot collide on the same vsock UDS path. Second restore fails (o | `firecracker.networking.fm.uds-path-collision-clones` | `ha "uds path in use"` |
| PUT /actions {action_type: InstanceStart} returns 400. Required pre-boot resources aren't all config | `firecracker.setup.fm.action-without-prerequisites` | `ha "instancestart 400"` |
| Operator attempts to bind the Firecracker API to a TCP port. Firecracker only accepts UDS transport. | `firecracker.setup.fm.api-on-tcp-not-uds-attempt` | `ha "tcp bind attempted"` |
| PUT /drives returns 400 with 'Block device backing file does not exist' or InstanceStart fails readi | `firecracker.setup.fm.drive-backing-file-missing` | `ha "backing file does not exist"` |
| Host crashes; on reboot, guest filesystem is corrupted or 'recently committed' data is missing. Driv | `firecracker.setup.fm.drive-unsafe-cache-data-loss` | `ha "fsck errors after host crash"` |
| Snapshot restore time degrades inexplicably (e.g., 3ms → 8.5ms on aarch64) after host kernel cmdline | `firecracker.setup.fm.host-kernel-logs-slow-snapshot-restore` | `ha "snapshot restore slow"` |
| Multi-tenant host has KSM (Kernel Samepage Merging) enabled. Page-deduplication side channels exploi | `firecracker.setup.fm.ksm-enabled-side-channel-risk` | `ha "/sys/kernel/mm/ksm/run = 1"` |
| Production Firecracker is started with --no-seccomp (or with a custom filter that whitelists too man | `firecracker.setup.fm.no-seccomp-in-production` | `ha "--no-seccomp in process args"` |
| API call returns 400 with 'cannot be modified after machine startup' or similar. Trying to PUT a pre | `firecracker.setup.fm.pre-boot-only-call-after-boot` | `ha "api call returns 400 with cannot"` |
| Multi-tenant Firecracker host has SMT (Hyperthreading) enabled. Speculation-class side channels (Spe | `firecracker.setup.fm.smt-enabled-side-channel-risk` | `ha "smt enabled in /sys"` |
| PUT /snapshot/create with snapshot_type=Diff returns 400. machine-config.track_dirty_pages was not s | `firecracker.snapshots.fm.diff-snapshot-without-track-dirty` | `ha "track_dirty_pages must be enabled"` |
| Firecracker fails to boot when guest kernel is built for a different architecture than the host (e.g | `firecracker.vmm.fm.cross-arch-guest-on-host` | `ha "kvm_exit_fail_entry"` |
| Firecracker fails to start with 'Resource busy' on /dev/kvm. Another hypervisor (VMware Workstation, | `firecracker.vmm.fm.dev-kvm-busy-vbox-vmware` | `ha "resource busy"` |
| Guest panics at boot with 'Cannot open root device vda' even though /drives is configured correctly. | `firecracker.vmm.fm.missing-virtio-blk-cannot-mount-root` | `ha "vfs: cannot open root device"` |
| Guest `reboot` doesn't terminate the Firecracker process. Guest enters reboot loop — kernel restarts | `firecracker.vmm.fm.reboot-without-reboot-k-hangs` | `ha "guest rebooting in loop"` |
| MicroVM boot takes 500+ ms instead of expected ≤125 ms. Serial console is enabled — every kernel pri | `firecracker.vmm.fm.serial-console-enabled-slow-boot` | `ha "slow boot"` |
| Firecracker thread becomes unresponsive after receiving a signal (SIGSEGV/SIGSYS). Custom signal han | `firecracker.vmm.fm.signal-handler-deadlock-on-log-lock` | `ha "thread unresponsive"` |
| Guest `poweroff` shuts down the OS but the Firecracker process stays alive — no ACPI PM means there' | `firecracker.vmm.fm.x86-poweroff-leaves-process-alive` | `ha "guest poweroff shuts down the os"` |
| Guest gets connection-refused or no-route when trying to fetch from MMDS at 169.254.169.254 (or conf | `firecracker.networking.fm.mmds-unreachable-no-route` | `ha "connection refused 169.254.169.254"` |

## ecs (41 fms)

| Symptom | fm-id | call |
|---|---|---|
| Task fails ResourceInitializationError 'failed to create container: failed to initialize logging dri | `ecs.agent.fm.awslogs-missing-log-group` | `ha "log group does not exist"` |
| Fargate task fills its scratch disk; container crashes with 'no space left on device'. Default ephem | `ecs.agent.fm.ephemeral-storage-exhausted-fargate` | `ha "no space left on device"` |
| Fargate task fails to launch: 'unsupported parameter: privileged' or 'sysctl X not allowed'. Fargate | `ecs.agent.fm.fargate-restricted-syscall-or-cap` | `ha "unsupported parameter"` |
| Spot-backed instance terminated mid-task. Tasks were running but no draining happened; service has t | `ecs.agent.fm.spot-interruption-no-draining` | `ha "spot instance interrupted"` |
| Task fails to start: 'volume name X already exists'. Two task-def volumes with the same name; OR mou | `ecs.agent.fm.task-def-volume-name-collision` | `ha "volume name"` |
| Second task in host network mode fails to start: 'port already allocated'. Two tasks on same instanc | `ecs.networking.fm.host-mode-port-conflict` | `ha "port already allocated"` |
| Task ENI security group denies egress (or ingress). App can't reach RDS, can't be reached by ALB tar | `ecs.networking.fm.security-group-blocks-task-traffic` | `ha "connection refused"` |
| stoppedReason 'CannotPullContainerError: toomanyrequests: You have reached your pull rate limit. You | `ecs.task-defs.fm.cannot-pull-container-error-rate-limited` | `ha "toomanyrequests"` |
| Task stops with stoppedReason 'Essential container in task exited' and container exitCode != 0. App  | `ecs.task-defs.fm.essential-container-exited-app-crash` | `ha "essential container in task exited"` |
| RunTask fails synchronously with failures[].reason 'RESOURCE:CPU' or 'RESOURCE:MEMORY' — no instance | `ecs.task-defs.fm.placement-failure-resource-cpu-memory` | `ha "resource:cpu"` |
| Task stops with stoppedReason 'OutOfMemoryError: Container killed due to memory usage'. Container hi | `ecs.task-defs.fm.task-oom-killed` | `ha "outofmemoryerror"` |
| Cluster running ECS-Optimized AL2 AMI past 2026-06-30. No more security updates from upstream Amazon | `ecs.troubleshooting.fm.amazon-linux-2-eol-2026-06-30` | `ha "al2 eol"` |
| CloudWatch Container Insights dashboard shows no data for an ECS cluster. Or partial data missing (e | `ecs.troubleshooting.fm.containerinsights-missing-metrics` | `ha "no metrics in container insights"` |
| Fargate Spot tasks stopped with stoppedReason 'Spot capacity not available' or 'TerminationNotice'.  | `ecs.troubleshooting.fm.fargate-spot-interruption` | `ha "spot capacity not available"` |
| API calls return 'enable the new ARN format with account-setting before using this feature'. Tagging | `ecs.agent.fm.account-setting-arn-format-required` | `ha "new arn format"` |
| Task in account A pulls from ECR in account B; CannotPullContainerError. Cross-account ECR repo poli | `ecs.agent.fm.cross-account-ecr-pull-denied` | `ha "accessdenied"` |
| Task fails ResourceInitializationError 'environment file s3://bucket/file not accessible'. Bucket/ke | `ecs.agent.fm.environment-file-s3-not-found` | `ha "environment file"` |
| aws ecs execute-command fails: 'The execute command failed because execute command was not enabled w | `ecs.agent.fm.exec-command-ssm-session-failed` | `ha "execute command was not enabled"` |
| ALB target group constantly killing tasks. Cascading failures: tasks killed → service launches repla | `ecs.networking.fm.alb-health-check-cascading-failures` | `ha "task failed elb health checks"` |
| awsvpc tasks in private subnets can't reach ECR. CannotPullContainerError net-timeout. No VPC endpoi | `ecs.networking.fm.awsvpc-cant-pull-from-ecr-no-vpce` | `ha "cannotpullcontainererror"` |
| Tasks fail to launch with 'ENI attach timeout'. Per-instance ENI limit hit (e.g., 4 on m5.large) bef | `ecs.networking.fm.awsvpc-eni-quota-exhaustion` | `ha "eni attach timeout"` |
| Task ENI attach fails with 'InsufficientFreeAddressesInSubnet'. Subnet IP space exhausted by accumul | `ecs.networking.fm.awsvpc-subnet-ip-exhaustion` | `ha "insufficientfreeaddressesinsubnet"` |
| Untrusted task code accesses 169.254.169.254 (EC2 instance metadata) and exfiltrates the container i | `ecs.networking.fm.imds-leak-from-task` | `ha "imds access from task"` |
| Task stops with stoppedReason 'CannotPullContainerError: pull access denied for <repo>, repository d | `ecs.task-defs.fm.cannot-pull-container-error-auth` | `ha "cannotpullcontainererror"` |
| stoppedReason 'CannotPullContainerError: net/http: TLS handshake timeout' or 'no such host'. Task su | `ecs.task-defs.fm.cannot-pull-container-error-network` | `ha "cannotpullcontainererror"` |
