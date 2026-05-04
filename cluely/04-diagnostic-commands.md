# 04 — Diagnostic commands (grouped by category)

> The actual commands you'll type. Grouped by tool family. `ha "..."` returns these embedded in fm playbooks; this is the flat browseable list.
>
> Auto-generated. Re-run `pnpm cluely` after corpus changes.

Total: 706 commands across 10 categories.


## Container runtime (docker, runc, containerd) (63)

- `containerd [FLAGS] \| ctr [FLAGS] SUBCOMMAND` — containerd daemon + ctr (low-level CLI for containerd). Note: ctr is for direct 
- `containerd [global-flags]` — The containerd daemon. Default config at /etc/containerd/config.toml. State at /
- `crictl exec [flags] <container-id> <command> [args...]` — Run a command inside a running container via the CRI. Useful for debugging from 
- `crictl pods [flags]` — List pod sandboxes via the CRI grpc API. Connects to `unix:///run/containerd/con
- `crictl ps [flags]` — List containers via the CRI grpc API (the in-pod containers, distinct from the p
- `crictl SUBCOMMAND [FLAGS]` — CRI-direct CLI on node. Bypasses kubelet+API. For low-level container/sandbox/im
- `ctr [global-flags] <subcommand> [subcommand-flags]` — containerd's bundled debug CLI. Native API (NOT CRI). Subcommands grouped by ser
- `docker build [OPTIONS] PATH \| URL \| -` — Build an image from a Dockerfile + context. Since Docker Engine 23.0, `docker bu
- `docker buildx bake [OPTIONS] [TARGET...]` — Build a matrix of targets defined in HCL/JSON/Compose files. Each target is a se
- `docker buildx build [OPTIONS] PATH \| URL \| -` — Same surface as `docker build` (since 23.0 they're aliases) but explicitly invok
- `docker buildx create [OPTIONS] [CONTEXT\|ENDPOINT]` — Create a buildx builder instance. Combined with `--use`, it becomes the active b
- `docker buildx imagetools create [OPTIONS] [SOURCE...]` — Create or modify an image manifest list (multi-arch image) on a registry from ex
- `docker buildx use [OPTIONS] NAME` — Switch the active builder. Persists across shell sessions (per `docker context`)
- `docker compose build [SERVICE...]` — Build images for services that have a `build` block. Reuses BuildKit. Subset by 
- `docker compose down [SERVICE...]` — Stop and remove containers, networks. Volumes preserved by default (use `-v` to 
- `docker compose exec [OPTIONS] SERVICE COMMAND [ARG...]` — Execute a command in a RUNNING service container. Mirrors `docker exec`. Picks t
- `docker compose logs [SERVICE...]` — Fetch + stream logs from project services. Multi-service streams are interleaved
- `docker compose ps [SERVICE...]` — List containers in the project. Default columns: NAME, IMAGE, COMMAND, SERVICE, 
- `docker compose restart [SERVICE...]` — Restart service containers. Doesn't recreate — same container, just stop+start. 
- `docker compose run [OPTIONS] SERVICE [COMMAND] [ARG...]` — Run a one-off container against a service definition. Doesn't reuse the service'
- `docker compose up [SERVICE...]` — Build, (re)create, start, and attach to containers for the project's services. T
- `docker container exec [OPTIONS] CONTAINER COMMAND [ARG...]` — Execute a command in a RUNNING container. Aliases: `docker exec`. Fails on pause
- `docker container inspect [OPTIONS] CONTAINER [CONTAINER...]` — Display detailed JSON for one or more containers (config, state, mounts, network
- `docker container kill [OPTIONS] CONTAINER [CONTAINER...]` — Send a signal (default SIGKILL) to the container's pid 1. Aliases: `docker kill`
- `docker container logs [OPTIONS] CONTAINER` — Fetch logs from a container. Aliases: `docker logs`. Works only with `json-file`
- `docker container ls [OPTIONS]` — List containers. Aliases: `docker ps`, `docker container list`, `docker containe
- `docker container prune [OPTIONS]` — Remove all stopped containers. Their writable layers are freed; named volumes pr
- `docker container rm [OPTIONS] CONTAINER [CONTAINER...]` — Remove one or more containers. Aliases: `docker rm`. Fails on running containers
- `docker container run [OPTIONS] IMAGE [COMMAND] [ARG...]` — Create and run a new container from an image. Pulls the image if missing (contro
- `docker container start [OPTIONS] CONTAINER [CONTAINER...]` — Start one or more stopped containers. Aliases: `docker start`. Reuses the previo
  _... +33 more in corpus; query via `hl "Container"`_

## Kubernetes (kubectl, crictl) (36)

- `kubectl [COMMAND] [TYPE/NAME] [FLAGS]` — The Kubernetes CLI. Talks to API server. Resource-oriented commands (get/describ
- `kubectl api-resources [-o wide]` — List all API resources known to cluster. Includes CRDs. Useful for 'what kinds e
- `kubectl api-versions` — List enabled API versions in cluster.
- `kubectl apply -f FILE_OR_DIR [FLAGS]` — Declarative create-or-update. Reads manifest(s); diffs against live state via la
- `kubectl auth can-i VERB RESOURCE [--as=USER]` — RBAC permission check. 'Can I create deployments?'
- `kubectl cluster-info [dump]` — Quick check of cluster reachability; dump for full state collection.
- `kubectl config SUBCOMMAND` — Manage kubeconfig.
- `kubectl cp [POD:]SRC [POD:]DST [FLAGS]` — Copy files in/out of containers. Implemented via tar piped over exec.
- `kubectl create ingress NAME --rule=HOST/PATH=SERVICE:PORT` — Imperatively create an Ingress.
- `kubectl debug node/NODE -it --image=IMAGE` — Schedule privileged debug pod on node with hostPath rootfs. `chroot /host` to ac
- `kubectl debug POD [-c CONTAINER] [--image=IMAGE] [--target=CONTAINER] [-it]` — Add an ephemeral debug container to a running pod (or copy pod with modification
- `kubectl delete TYPE/NAME [FLAGS]` — Delete resources. Triggers finalizers; respects ownerReferences (cascading delet
- `kubectl describe TYPE/NAME` — Human-readable per-resource detail INCLUDING events. The first command for 'why 
- `kubectl drain NODE [FLAGS]` — Cordon node + evict pods. For node maintenance. Respects PDBs.
- `kubectl events [--for=TYPE/NAME] [--watch]` — Modern event listing. Better filtering than `kubectl get events`.
- `kubectl events [-n NS] [--for=TYPE/NAME] [--watch]` — Cluster events. Modern (1.23+) replacement for `kubectl get events`. Better form
- `kubectl exec POD [-c CONTAINER] [-it] -- COMMAND` — Exec command inside running container. Like docker exec.
- `kubectl explain TYPE[.FIELD]` — Show field documentation for a resource type. Built from API schema. Indispensab
- `kubectl expose RESOURCE NAME [FLAGS]` — Imperatively create a Service exposing a Pod/Deployment/ReplicaSet/Service. Quic
- `kubectl get [TYPE[/NAME]] [FLAGS]` — List or display resources. Default brief table; -o yaml for full spec; -o jsonpa
- `kubectl get endpoints --watch` — Watch endpoints change as pods become ready/unready. Useful for debugging readin
- `kubectl get endpoints [NAME] \| kubectl get endpointslices` — List Service backing pods. Empty endpoints = no pods match selector or no pods R
- `kubectl get ingress` — List Ingress resources with hosts, addresses, ports.
- `kubectl get lease -n kube-node-lease` — Per-node heartbeat leases. Stale lease = node potentially down.
- `kubectl get networkpolicy / netpol` — List NetworkPolicies. Default deny patterns visible here.
- `kubectl get pdb [NAME]` — List PodDisruptionBudgets. Required to understand drain blocking.
- `kubectl get pod NAME -o yaml` — Full pod state including containerStatuses (waiting/running/terminated reasons),
- `kubectl get runtimeclass` — List RuntimeClasses (gvisor, kata, runc, etc.).
- `kubectl get svc [-o wide]` — List Services with type, ClusterIP, ExternalIP, Ports, Age.
- `kubectl logs POD [-c CONTAINER] [FLAGS]` — Container logs (stdout+stderr). For multi-container pods, -c CONTAINER required 
  _... +6 more in corpus; query via `hl "Kubernetes"`_

## Process & cgroups (ps, top, /proc, cgroup) (2)

- `cat /sys/fs/cgroup/kubepods.slice/.../cri-containerd-CID.scope/{memory.max,cpu.max,memory.current,cpu.stat}` — Read cgroup v2 control files for a pod's container directly.
- `pidstat [OPTIONS] [INTERVAL [COUNT]]` — Per-process resource statistics. From sysstat. Shows CPU/memory/IO/context-switc

## Networking (ss, ip, iptables, tcpdump, dig, conntrack) (19)

- `conntrack [-L \| -G \| -D \| -I \| -U \| -E \| -F \| -C] [OPTIONS]` — Inspect/manipulate the kernel connection tracking table. Lists tracked flows, ki
- `dig [@SERVER] [TYPE] [NAME] [+OPTION...]` — DNS lookup tool, the gold-standard debugging interface. Defaults: query default 
- `getent [OPTIONS] DATABASE [KEY...]` — Query system databases via the NSS (name service switch) layer. Goes through nss
- `ip [OPTIONS] OBJECT { COMMAND \| help }` — The Swiss-army knife for Linux networking config — replaces ifconfig, route, arp
- `ip address { add \| del \| flush \| show } [DEV]` — Manage IPv4/IPv6 addresses on interfaces. Add/remove/list addresses, peer addres
- `ip link { add \| delete \| set \| show \| help } [DEV] [TYPE]` — Manage L2 network devices — physical NICs, virtual interfaces (veth, bridge, vla
- `ip neighbour { add \| del \| change \| replace \| show \| flush } [ADDR]` — Manage the ARP/NDP cache (kernel's IP→MAC mapping). 'ip neigh' = synonym. Replac
- `ip netns add <name>` — Create a network namespace for the jailer to attach via --netns. Combine with TA
- `ip route { add \| del \| replace \| get \| show \| flush } [DEST]` — Manage routing-table entries. Add/remove/inspect routes, evaluate which route a 
- `ip route add default via <tap-ip> dev eth0 (in guest)` — Inside the guest, configure the default route through the TAP IP. Combined with 
- `ip tuntap add <name> mode tap` — Create a Linux TAP device for Firecracker to attach to. The TAP must exist on th
- `iptables [-t TABLE] {-A\|-I\|-D\|-R\|-L\|-F\|-N\|-X\|-P\|-Z} CHAIN [RULE] [-j TARGET]` — Configure netfilter rules (legacy front-end). Tables: filter (default), nat, man
- `iptables-nft -t nat -A POSTROUTING -o <host-iface> -s <guest-ip> -j MASQUERADE` — Equivalent to the nft masquerade rule via the iptables-nft compat layer. Use onl
- `iptables-save -t nat \| grep KUBE` — Inspect kube-proxy's iptables rules on a node. The actual DNAT rules implementin
- `nft [OPTIONS] CMD` — Modern netfilter front-end. Single CLI for IPv4/IPv6/ARP/bridge/netdev rules. At
- `nft add rule <table> postrouting ip saddr <guest-ip> oifname <host-iface> counter masquerade` — Create the NAT masquerade rule that rewrites guest packets' source IP to the hos
- `nmap [SCAN-TYPES] [OPTIONS] TARGETS` — Network discovery and security scanner. Port scan, service/version detection, OS
- `ss [OPTIONS] [FILTER]` — Socket statistics. Replaces netstat. Reads /proc/net via NETLINK; faster than ne
- `tcpdump [OPTIONS] [FILTER]` — Capture and display packets on an interface using libpcap. The Swiss-army knife 

## Disk & filesystem (df, du, lsof, mount, blkid) (4)

- `blkid [OPTIONS] [DEVICE...]` — Print block device attributes: UUID, LABEL, TYPE. Reads superblock signatures. U
- `lsblk [OPTIONS] [DEVICES]` — Tree view of block devices: disks → partitions → LVs → filesystems. Shows MAJ:MI
- `lsof [OPTIONS] [NAMES]` — List all open files in the system: regular files, dirs, sockets, pipes, devices,
- `mount [-t TYPE] [-o OPTIONS] DEVICE MOUNTPOINT` — Attach a filesystem. Without args, lists current mounts (read /proc/mounts). Wit

## systemd (systemctl, journalctl, systemd-analyze) (10)

- `journalctl -u kubelet -f [-n N]` — Kubelet logs on the node. Required for: pod admission rejections, mount errors, 
- `journalctl [OPTIONS] [MATCHES...]` — Query systemd journal logs. The replacement for grep'ing /var/log/syslog. Filter
- `systemctl [OPTIONS] COMMAND [UNIT...]` — Control the systemd service manager. The primary interface for managing units (s
- `systemctl enable openvpn && systemctl start openvpn` — Enable and start the OpenVPN systemd service inside DevBox. Used after creating 
- `systemd-analyze [OPTIONS] COMMAND` — Inspect boot performance, unit-file correctness, sandboxing posture. The perform
- `systemd-cgls [OPTIONS] [CGROUP\|UNIT\|PID]` — Tree view of cgroups + processes within. Shows the slice/service hierarchy.
- `systemd-cgls /kubepods.slice` — Visualize kubelet's cgroup hierarchy. See per-pod, per-QoS-class, per-container 
- `systemd-cgtop [OPTIONS]` — Top-style live view of cgroup CPU/memory/IO/task counts. Real-time per-unit reso
- `systemd-run [OPTIONS] -- COMMAND [ARGS]` — Run a command as a transient unit (service, scope, or timer). Lets you apply sys
- `systemd-tmpfiles [OPTIONS] {--create \| --clean \| --remove} [CONFIG_FILES...]` — Apply tmpfiles.d rules: create, clean (delete old per Age field), or remove spec

## Performance / tracing (perf, strace, ltrace, bpf, ftrace) (26)

- `bpftrace -e 'kprobe:<func> { ... }'` — Attach a kprobe to a kernel function and run a BPF action block. The most common
- `bpftrace -e 'profile:hz:99 { ... }'` — Timed sampling — fire on every CPU at the specified rate. Equivalent to perf rec
- `bpftrace -e 'profile:hz:99 { @[ustack, kstack] = count(); }'` — All-CPU mixed kernel/user stack profile via timed sampling — bpftrace's one-line
- `bpftrace -e 'tracepoint:<category>:<name> { ... }'` — Attach to a stable kernel tracepoint (more durable across kernel versions than k
- `bpftrace -e 'uprobe:<binary>:<symbol> { ... }'` — User-space dynamic tracing — attach to any function in any binary at runtime. Hi
- `bpftrace -l` — List available probes matching a glob — discovery before attaching.
- `bpftrace [-e PROGRAM \| FILE] [OPTIONS]` — DTrace-inspired high-level eBPF front-end. Compiles short DSL programs to BPF, a
- `ltrace [OPTIONS] COMMAND [ARGS] \| ltrace -p PID` — Library call tracer — like strace but for shared-library function calls (and opt
- `perf annotate` — Disassemble hot functions and overlay percentages from perf.data on each instruc
- `perf c2c` — Cache-line contention analysis (Linux 4.10+). Records and reports cache-line tra
- `perf list` — List events available to perf_events on this kernel — tracepoints, PMC events, s
- `perf probe` — Add or remove dynamic tracepoints (kprobes/uprobes) at runtime. Lets you observe
- `perf record` — Sample CPU stacks or trace specific events to a perf.data file for later analysi
- `perf record [OPTIONS] -- COMMAND \| perf record [OPTIONS] -p PID` — Sample events into a perf.data file for later analysis with perf report/script. 
- `perf report` — Display a perf.data file as a hierarchical (tree) summary with percentages. Defa
- `perf report [OPTIONS]` — Read perf.data and display profile (default: TUI tree view). Sort by overhead, s
- `perf script` — Dump every event from perf.data as text, one line per event with timestamp, comm
- `perf script [OPTIONS]` — Process perf.data records. Default: print every sample as a line (timestamp, com
- `perf stat` — Count events without recording each one — the lowest-overhead perf mode. Default
- `perf stat [OPTIONS] -- COMMAND [ARGS] \| perf stat [OPTIONS] -p PID` — Run COMMAND (or attach to PID) and print PMU + software event counter values. De
- `perf top` — Live top-N functions by sample count, refreshed continuously. Like top(1) but fo
- `perf top [OPTIONS]` — Real-time top-style profiler. Shows hottest functions live, refreshing per secon
- `perf trace` — strace-like tool built on perf_events — much lower overhead than strace because 
- `perf trace [OPTIONS] -- COMMAND \| perf trace [OPTIONS] -p PID` — Live syscall tracer (like strace, but uses tracepoints + ring buffer — much fast
- `strace [OPTIONS] COMMAND [ARGS] \| strace -p PID` — Trace system calls and signals via ptrace(2). Output: each syscall with arg deco
- `trace-cmd CMD [OPTIONS]` — User-friendly ftrace front-end. Manages /sys/kernel/debug/tracing/ for you. Subc

## AWS / ECS (aws ecs, aws ec2) (9)

- `aws ec2 describe-instance-types --filters Name=instance-type,Values='*.metal*' --query 'InstanceTypes[].Instan` — Enumerate available .metal instance types in the current region.
- `aws ec2 describe-network-interfaces --filters Name=description,Values='*<cluster>/<task-id>*'` — Find the ENI attached to a specific awsvpc task. Useful when debugging connectiv
- `aws ecs create-capacity-provider --name <name> --auto-scaling-group-provider <args>` — Create an EC2-ASG-backed capacity provider with managed-scaling parameters.
- `aws ecs create-cluster --cluster-name <name> [--capacity-providers ...] [--default-capacity-provider-strategy ` — Create a new ECS cluster with optional capacity-provider bindings + default stra
- `aws ecs put-account-setting --name awsvpcTrunking --value enabled` — Opt the account into ENI trunking. Required before ECS_ENABLE_HIGH_DENSITY_ENI=t
- `aws ecs put-cluster-capacity-providers --cluster <name> --capacity-providers <cps> --default-capacity-provider` — Update capacity-provider bindings on an existing cluster (atomic — must include 
- `aws ecs register-task-definition --cli-input-json file://td.json` — Register a new revision of a task definition. Returns the new revision number. I
- `aws ecs run-task --cluster <c> --task-definition <family[:rev]> [...]` — Launch a one-shot (non-service-managed) task. Useful for scheduled batch jobs, m
- `aws ecs update-container-instances-state --cluster <name> --container-instances <arn> --status DRAINING` — Transition a container instance to DRAINING — stops accepting new task placement

## Other (537)

- `![macro_name] <message>` — Slack-only: invoke a named playbook macro at session start. Examples include use
- `!ask <question>` — Get a quick codebase answer without spinning up a full agent session. Available 
- `!dana <message>` — Slack-only: launch a Dana session (Cognition's data-analyst agent variant). Equi
- `!deep <question>` — Deeper research answer using advanced search. Higher-effort variant of !ask. Ava
- `!fast <message>` — Slack-only: launch a fast-mode Devin session. Trades off depth for speed.
- `(aside) <message>  OR  !aside <message>` — Cause Devin to ignore a single message (useful for commenting on Devin's run dir
- `(cd <subdir> && <command>)` — Run a blueprint or shell command in a subshell with a temporary working director
- `[ -r /dev/kvm ] && [ -w /dev/kvm ]` — Verify the calling user has read+write access to /dev/kvm. Typically requires be
- `[AWS] aws route53 change-resource-record-sets --hosted-zone-id <id> --change-batch file://dns-change.json` — Publish a DNS record pointing at the load balancer that fronts the self-hosted e
- `[AWS] Create Application Load Balancer + WAF with IP-allowlist rule` — Stand up an ALB fronting a self-hosted endpoint, with AWS WAF enforcing IP allow
- `[AWS] Create Network Load Balancer with security groups for Devin egress IPs` — Stand up an NLB to front a self-hosted SCM/artifact endpoint, configured with se
- `[Devin run UI] menu > Enable Slack notifications` — Enable per-run private Slack notifications. Devin DMs the user on status updates
- `[GitHub] github.com/settings/installations > Devin.ai Integration > Configure > Danger zone > Uninstall` — Remove Devin's GitHub App installation from a GitHub organization — required whe
- `[Jira] @Devin <instructions> (in ticket comment)` — Trigger Devin from a Jira ticket comment. Devin uses the comment text as the tas
- `[Jira] Add `devin` label (or any label containing 'devin' as a standalone word)` — Trigger Devin using the default playbook by adding a generic devin-label. Word-b
- `[Jira] Add playbook-macro label` — Trigger Devin with a specific playbook by adding a label whose name matches the 
- `[Jira] Assign ticket to Devin` — Trigger a Devin session from Jira by assigning the ticket to Devin's service acc
- `[Jira/Linear] Add label `!plan` (or other macro) to a ticket` — Trigger Devin with a specific playbook by adding a macro-named label to a ticket
- `[Linear] @Devin <instructions> (in ticket comment)` — Trigger Devin from a Linear ticket comment with custom instructions. No playbook
- `[Linear] Add synced playbook label` — Trigger Devin with a specific playbook by adding a label from the 'Devin Playboo
- `[Linear] Assign ticket to Devin` — Trigger Devin from Linear via assignment. Uses the default playbook (`!plan` for
- `[Slack] Workspace Admin > Configure apps > Installed Apps > Devin > App Details > Configuration tab > Bot User` — Rename Devin in a Slack workspace (the bot's display name).
- `[UI] Devin Review > chat > 'Make this change' > Apply as commit` — Ask the chat agent for code edits, review the suggestions, and apply as a commit
- `[UI] Devin Review > PR detail > Merge` — Merge a PR directly from Devin Review without leaving the page.
- `[UI] Devin Review > PR detail > Toggle auto-merge` — Toggle GitHub auto-merge on/off from inside Devin Review.
- `[UI] Enterprise Settings > Enterprise members > Assign account-level role` — Assign an account-level (enterprise-wide) role to a user. Account-level roles in
- `[UI] Enterprise Settings > Members > Configure IdP group mappings` — Map IdP group names to Devin roles for SSO auto-assignment. SSO provider must se
- `[UI] Enterprise Settings > Roles > Create a custom role` — Create a custom org-level or account-level role with selected permissions. Requi
- `[UI] Enterprise Settings > Rollout > per-org table > filter dropdown` — Filter the per-org table by All / Blueprints / Classic / Overrides. Used to find
- `[UI] Enterprise Settings > Rollout > per-org table > opt org IN to blueprints` — Switch a specific organization to declarative blueprints (Testing/Available mode
  _... +507 more in corpus; query via `hl "Other"`_
