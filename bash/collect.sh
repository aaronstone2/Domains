#!/usr/bin/env bash
# collect.sh — Diagnostic data collector for interview debugging
# Usage: bash bash/collect.sh <scenario> [target]
#
# Collects logs + metrics → ~/saved/<scenario>-<timestamp>/
# Then tell Claude Code: "read the files in ~/saved/<dir> and diagnose"
#
# Scenarios:
#   container <name>    — Docker container diagnostics
#   pod <name> [ns]     — Kubernetes pod diagnostics
#   node [name]         — K8s node / Linux host diagnostics
#   system              — Full host system snapshot
#   network [host:port] — Network/connectivity diagnostics
#   tls <host[:port]>   — TLS/SSL certificate diagnostics
#   ecs <task-arn>       — ECS task diagnostics
#   oom                 — OOM investigation
#   disk                — Disk/inode/mount diagnostics
#   dns [domain]        — DNS resolution diagnostics
#   all [container]     — Everything (system + container if provided)
#
# Output: ~/saved/<scenario>-<timestamp>/
# Files are plain text, ready for Claude Code to read.

set -euo pipefail

SCENARIO="${1:-help}"
TARGET="${2:-}"
EXTRA="${3:-}"
TS=$(date +%Y%m%d-%H%M%S)
TARGET_SLUG=""
if [[ -n "$TARGET" ]]; then
  TARGET_SLUG="-$(echo "$TARGET" | tr '/:. ' '----' | tr -cd 'a-zA-Z0-9-' | head -c40)"
fi
LOGDIR="$HOME/saved/${SCENARIO}${TARGET_SLUG}-${TS}"

header() { echo "=== $1 ===" >> "$2"; echo "" >> "$2"; }

help() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

setup() {
  mkdir -p "$LOGDIR"
  echo "Collecting $SCENARIO diagnostics → $LOGDIR"
  # Start the summary file
  {
    echo "DIAGNOSTIC COLLECTION SUMMARY"
    echo "============================="
    echo "Scenario:  $SCENARIO"
    echo "Target:    ${TARGET:-n/a}"
    echo "Collected: $(date)"
    echo "Host:      $(hostname 2>/dev/null || echo unknown)"
    echo "Kernel:    $(uname -r 2>/dev/null || echo unknown)"
    echo ""
    echo "FILES COLLECTED:"
  } > "$LOGDIR/summary.txt"
}

finish() {
  # Append file listing to summary
  echo "" >> "$LOGDIR/summary.txt"
  echo "FILE LISTING:" >> "$LOGDIR/summary.txt"
  ls -lhS "$LOGDIR" | tail -n+2 >> "$LOGDIR/summary.txt"

  # Add quick-look highlights to summary
  {
    echo ""
    echo "QUICK HIGHLIGHTS:"

    # OOM?
    local oom_found=false
    for f in "$LOGDIR"/dmesg*.txt "$LOGDIR"/oom*.txt; do
      [[ -f "$f" ]] || continue
      if grep -qi 'killed\|oom' "$f" 2>/dev/null; then
        echo "  ⚠ OOM events found — see $(basename "$f")"
        oom_found=true
        break
      fi
    done

    # Exit codes?
    if [[ -f "$LOGDIR/inspect.json" ]]; then
      local ec=""
      ec=$(python3 -c "import json; d=json.load(open('$LOGDIR/inspect.json')); print(d[0]['State'].get('ExitCode','?'))" 2>/dev/null) || ec=""
      if [[ -n "$ec" && "$ec" != "0" ]]; then
        echo "  ⚠ Container exited with code $ec"
      fi
    fi

    # Disk?
    if [[ -f "$LOGDIR/df.txt" ]]; then
      awk 'NR>1{gsub(/%/,"",$5); if($5+0>=90) print "  ⚠ Disk usage ≥90% on " $6}' "$LOGDIR/df.txt" 2>/dev/null || true
    fi

    if [[ "$oom_found" == "false" ]] && [[ ! -f "$LOGDIR/inspect.json" ]]; then
      echo "  (no critical anomalies auto-detected — review files manually)"
    fi
  } >> "$LOGDIR/summary.txt"

  echo ""
  echo "Done. Files saved to: $LOGDIR"
  echo ""
  ls -lhS "$LOGDIR"
  echo ""
  echo "─────────────────────────────────────────────"
  echo "Tell Claude Code:"
  echo ""
  echo "  Read ~/saved/$(basename "$LOGDIR")/summary.txt then diagnose"
  echo ""
}

# ── Container diagnostics ──────────────────────────────────────────
collect_container() {
  local CTR="${TARGET:?Usage: collect.sh container <name|id>}"
  setup

  echo "Collecting container state..."
  docker inspect "$CTR" > "$LOGDIR/inspect.json" 2>&1 || true

  echo "Collecting container logs..."
  docker logs --tail 200 "$CTR" > "$LOGDIR/logs.txt" 2>&1 || true

  echo "Collecting container stats..."
  docker stats --no-stream "$CTR" > "$LOGDIR/stats.txt" 2>&1 || true

  echo "Collecting container top..."
  docker top "$CTR" -aux > "$LOGDIR/top.txt" 2>&1 || true

  echo "Collecting container diff..."
  docker diff "$CTR" > "$LOGDIR/diff.txt" 2>&1 || true

  echo "Collecting container events..."
  docker events --since 10m --until 0s --filter "container=$CTR" > "$LOGDIR/events.txt" 2>&1 || true

  echo "Collecting host OOM logs..."
  dmesg -T 2>/dev/null | grep -i 'killed\|oom' > "$LOGDIR/oom-dmesg.txt" 2>&1 || true

  echo "Collecting host docker info..."
  docker system df > "$LOGDIR/docker-df.txt" 2>&1 || true
  docker info > "$LOGDIR/docker-info.txt" 2>&1 || true

  # Try to get cgroup info if container is running
  local PID
  PID=$(docker inspect --format '{{.State.Pid}}' "$CTR" 2>/dev/null) || true
  if [[ -n "$PID" && "$PID" != "0" ]]; then
    echo "Collecting cgroup stats (PID $PID)..."
    local CG="/proc/$PID/cgroup"
    cat "$CG" > "$LOGDIR/cgroup-path.txt" 2>&1 || true

    # cgroup v2 stats
    local CGDIR
    CGDIR=$(cat /proc/"$PID"/cgroup 2>/dev/null | head -1 | cut -d: -f3) || true
    if [[ -d "/sys/fs/cgroup${CGDIR}" ]]; then
      {
        header "memory.max" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/memory.max" 2>/dev/null || echo "n/a"
        header "memory.current" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/memory.current" 2>/dev/null || echo "n/a"
        header "memory.events" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/memory.events" 2>/dev/null || echo "n/a"
        header "cpu.stat" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/cpu.stat" 2>/dev/null || echo "n/a"
        header "cpu.max" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/cpu.max" 2>/dev/null || echo "n/a"
        header "pids.max" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/pids.max" 2>/dev/null || echo "n/a"
        header "pids.current" "$LOGDIR/cgroup-stats.txt"
        cat "/sys/fs/cgroup${CGDIR}/pids.current" 2>/dev/null || echo "n/a"
      } >> "$LOGDIR/cgroup-stats.txt" 2>&1
    fi

    echo "Collecting open FDs..."
    ls /proc/"$PID"/fd 2>/dev/null | wc -l > "$LOGDIR/fd-count.txt" 2>&1 || true
    cat /proc/"$PID"/limits > "$LOGDIR/limits.txt" 2>&1 || true
    cat /proc/"$PID"/status > "$LOGDIR/proc-status.txt" 2>&1 || true
  fi

  finish
}

# ── Kubernetes pod diagnostics ─────────────────────────────────────
collect_pod() {
  local POD="${TARGET:?Usage: collect.sh pod <name> [namespace]}"
  local NS="${EXTRA:-default}"
  setup

  echo "Collecting pod describe..."
  kubectl describe pod "$POD" -n "$NS" > "$LOGDIR/describe.txt" 2>&1 || true

  echo "Collecting pod YAML..."
  kubectl get pod "$POD" -n "$NS" -o yaml > "$LOGDIR/pod.yaml" 2>&1 || true

  echo "Collecting pod logs..."
  kubectl logs "$POD" -n "$NS" --tail=200 > "$LOGDIR/logs.txt" 2>&1 || true
  kubectl logs "$POD" -n "$NS" --previous --tail=200 > "$LOGDIR/logs-previous.txt" 2>&1 || true

  echo "Collecting all container logs..."
  kubectl logs "$POD" -n "$NS" --all-containers --tail=100 > "$LOGDIR/logs-all-containers.txt" 2>&1 || true

  echo "Collecting pod events..."
  kubectl get events -n "$NS" --field-selector "involvedObject.name=$POD" --sort-by='.lastTimestamp' > "$LOGDIR/events.txt" 2>&1 || true

  echo "Collecting pod top..."
  kubectl top pod "$POD" -n "$NS" > "$LOGDIR/top.txt" 2>&1 || true

  echo "Collecting service endpoints..."
  kubectl get ep -n "$NS" > "$LOGDIR/endpoints.txt" 2>&1 || true

  echo "Collecting related services..."
  kubectl get svc -n "$NS" > "$LOGDIR/services.txt" 2>&1 || true

  echo "Collecting network policies..."
  kubectl get netpol -n "$NS" -o yaml > "$LOGDIR/netpol.yaml" 2>&1 || true

  echo "Collecting resolv.conf from pod..."
  kubectl exec "$POD" -n "$NS" -- cat /etc/resolv.conf > "$LOGDIR/resolv.conf" 2>&1 || true

  echo "Collecting node info for pod's node..."
  local NODE
  NODE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null) || true
  if [[ -n "$NODE" ]]; then
    kubectl describe node "$NODE" > "$LOGDIR/node-describe.txt" 2>&1 || true
    kubectl top node "$NODE" > "$LOGDIR/node-top.txt" 2>&1 || true
  fi

  finish
}

# ── Node / host diagnostics ────────────────────────────────────────
collect_node() {
  setup

  if [[ -n "$TARGET" ]]; then
    echo "Collecting K8s node describe..."
    kubectl describe node "$TARGET" > "$LOGDIR/node-describe.txt" 2>&1 || true
    kubectl top node "$TARGET" > "$LOGDIR/node-top.txt" 2>&1 || true
  fi

  echo "Collecting K8s node list..."
  kubectl get nodes -o wide > "$LOGDIR/nodes.txt" 2>&1 || true
  kubectl top nodes > "$LOGDIR/nodes-top.txt" 2>&1 || true

  echo "Collecting cluster events..."
  kubectl get events -A --sort-by='.lastTimestamp' | tail -50 > "$LOGDIR/events.txt" 2>&1 || true

  # Also collect system metrics
  collect_system_inner

  finish
}

# ── System snapshot ────────────────────────────────────────────────
collect_system_inner() {
  echo "Collecting system metrics..."
  {
    header "uptime" "$LOGDIR/system.txt"
    uptime
    header "free -h" "$LOGDIR/system.txt"
    free -h
    header "df -h" "$LOGDIR/system.txt"
    df -h
    header "df -i (inodes)" "$LOGDIR/system.txt"
    df -i
    header "vmstat 1 3" "$LOGDIR/system.txt"
    vmstat 1 3
  } >> "$LOGDIR/system.txt" 2>&1

  echo "Collecting process list..."
  ps auxf > "$LOGDIR/ps.txt" 2>&1 || true

  echo "Collecting listening ports..."
  ss -tlnp > "$LOGDIR/ports.txt" 2>&1 || true

  echo "Collecting open files..."
  lsof +L1 > "$LOGDIR/deleted-open.txt" 2>&1 || true

  echo "Collecting dmesg..."
  dmesg -T 2>/dev/null | tail -100 > "$LOGDIR/dmesg.txt" 2>&1 || true

  echo "Collecting mount info..."
  findmnt > "$LOGDIR/mounts.txt" 2>&1 || true

  echo "Collecting iptables..."
  sudo iptables -L -n -v --line-numbers > "$LOGDIR/iptables.txt" 2>&1 || true

  echo "Collecting conntrack..."
  {
    echo "Count: $(conntrack -C 2>/dev/null || echo n/a)"
    echo "Max: $(sysctl -n net.nf_conntrack_max 2>/dev/null || echo n/a)"
  } > "$LOGDIR/conntrack.txt" 2>&1

  echo "Collecting ulimits..."
  ulimit -a > "$LOGDIR/ulimits.txt" 2>&1 || true

  echo "Collecting namespaces..."
  lsns > "$LOGDIR/namespaces.txt" 2>&1 || true
}

collect_system() {
  setup
  collect_system_inner
  finish
}

# ── Network diagnostics ────────────────────────────────────────────
collect_network() {
  setup

  echo "Collecting network interfaces..."
  ip addr show > "$LOGDIR/interfaces.txt" 2>&1 || true

  echo "Collecting routes..."
  ip route show > "$LOGDIR/routes.txt" 2>&1 || true
  ip rule list > "$LOGDIR/ip-rules.txt" 2>&1 || true

  echo "Collecting ARP..."
  ip neigh show > "$LOGDIR/arp.txt" 2>&1 || true

  echo "Collecting listening ports..."
  ss -tlnp > "$LOGDIR/listening.txt" 2>&1 || true

  echo "Collecting all connections..."
  ss -tan > "$LOGDIR/connections.txt" 2>&1 || true
  ss -tan state time-wait | wc -l > "$LOGDIR/time-wait-count.txt" 2>&1 || true

  echo "Collecting iptables..."
  sudo iptables -L -n -v --line-numbers > "$LOGDIR/iptables.txt" 2>&1 || true
  sudo iptables -t nat -L -n -v > "$LOGDIR/iptables-nat.txt" 2>&1 || true

  echo "Collecting conntrack..."
  {
    echo "Count: $(conntrack -C 2>/dev/null || echo n/a)"
    echo "Max: $(sysctl -n net.nf_conntrack_max 2>/dev/null || echo n/a)"
  } > "$LOGDIR/conntrack.txt" 2>&1

  if [[ -n "$TARGET" ]]; then
    local HOST PORT
    HOST=$(echo "$TARGET" | cut -d: -f1)
    PORT=$(echo "$TARGET" | cut -d: -f2 -s)
    PORT="${PORT:-443}"

    echo "Collecting connectivity to $HOST:$PORT..."
    curl -sv --connect-timeout 5 "https://$HOST:$PORT" > "$LOGDIR/curl.txt" 2>&1 || true

    echo "Collecting DNS for $HOST..."
    dig "$HOST" +short > "$LOGDIR/dns-dig.txt" 2>&1 || true
    dig "$HOST" +trace > "$LOGDIR/dns-trace.txt" 2>&1 || true

    echo "Collecting traceroute..."
    traceroute -n -w 2 "$HOST" > "$LOGDIR/traceroute.txt" 2>&1 || true

    echo "Collecting TCP dump (10 packets)..."
    sudo timeout 10 tcpdump -i any -nn "host $HOST" -c 10 > "$LOGDIR/tcpdump.txt" 2>&1 || true
  fi

  finish
}

# ── TLS diagnostics ────────────────────────────────────────────────
collect_tls() {
  local HOST="${TARGET:?Usage: collect.sh tls <host[:port]>}"
  local PORT
  PORT=$(echo "$HOST" | cut -d: -f2 -s)
  PORT="${PORT:-443}"
  HOST=$(echo "$HOST" | cut -d: -f1)
  setup

  echo "Collecting TLS certificate chain..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" </dev/null > "$LOGDIR/tls-handshake.txt" 2>&1 || true

  echo "Collecting certificate details..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" </dev/null 2>/dev/null | \
    openssl x509 -noout -text > "$LOGDIR/cert-details.txt" 2>&1 || true

  echo "Collecting certificate dates..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" </dev/null 2>/dev/null | \
    openssl x509 -noout -dates -subject -issuer > "$LOGDIR/cert-dates.txt" 2>&1 || true

  echo "Collecting certificate chain (full)..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -showcerts </dev/null > "$LOGDIR/cert-chain.txt" 2>&1 || true

  echo "Collecting SANs..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" </dev/null 2>/dev/null | \
    openssl x509 -noout -text 2>/dev/null | grep -A1 'Subject Alternative' > "$LOGDIR/cert-sans.txt" 2>&1 || true

  echo "Collecting OCSP stapling..."
  openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -status </dev/null > "$LOGDIR/ocsp.txt" 2>&1 || true

  echo "Collecting supported protocols..."
  for proto in tls1 tls1_1 tls1_2 tls1_3; do
    echo "--- $proto ---" >> "$LOGDIR/protocols.txt"
    openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -"$proto" </dev/null >> "$LOGDIR/protocols.txt" 2>&1 || echo "NOT SUPPORTED" >> "$LOGDIR/protocols.txt"
  done

  echo "Collecting curl verbose..."
  curl -sv --connect-timeout 5 "https://$HOST:$PORT/" > "$LOGDIR/curl.txt" 2>&1 || true

  finish
}

# ── ECS diagnostics ────────────────────────────────────────────────
collect_ecs() {
  local TASK="${TARGET:?Usage: collect.sh ecs <task-arn> [cluster]}"
  local CLUSTER="${EXTRA:-default}"
  setup

  echo "Collecting ECS task description..."
  aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" > "$LOGDIR/task.json" 2>&1 || true

  echo "Collecting ECS service events..."
  local SVC
  SVC=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --query 'tasks[0].group' --output text 2>/dev/null | sed 's/service://' ) || true
  if [[ -n "$SVC" && "$SVC" != "None" ]]; then
    aws ecs describe-services --cluster "$CLUSTER" --services "$SVC" > "$LOGDIR/service.json" 2>&1 || true
  fi

  echo "Collecting container instances..."
  aws ecs describe-container-instances --cluster "$CLUSTER" \
    --container-instances "$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --query 'tasks[0].containerInstanceArn' --output text 2>/dev/null)" \
    > "$LOGDIR/container-instance.json" 2>&1 || true

  echo "Collecting CloudWatch logs..."
  # Try to get log group from task definition
  local TD
  TD=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --query 'tasks[0].taskDefinitionArn' --output text 2>/dev/null) || true
  if [[ -n "$TD" ]]; then
    aws ecs describe-task-definition --task-definition "$TD" > "$LOGDIR/task-definition.json" 2>&1 || true
  fi

  finish
}

# ── OOM investigation ──────────────────────────────────────────────
collect_oom() {
  setup

  echo "Collecting OOM events from dmesg..."
  dmesg -T 2>/dev/null | grep -i 'killed\|oom\|out of memory' > "$LOGDIR/dmesg-oom.txt" 2>&1 || true

  echo "Collecting full dmesg (last 200 lines)..."
  dmesg -T 2>/dev/null | tail -200 > "$LOGDIR/dmesg-tail.txt" 2>&1 || true

  echo "Collecting memory info..."
  free -h > "$LOGDIR/free.txt" 2>&1 || true
  cat /proc/meminfo > "$LOGDIR/meminfo.txt" 2>&1 || true

  echo "Collecting top memory consumers..."
  ps aux --sort=-%mem | head -20 > "$LOGDIR/top-mem.txt" 2>&1 || true

  echo "Collecting cgroup memory info..."
  find /sys/fs/cgroup -name memory.events -exec sh -c 'echo "--- {} ---"; cat {}' \; > "$LOGDIR/cgroup-memory-events.txt" 2>&1 || true
  find /sys/fs/cgroup -name memory.max -exec sh -c 'echo "--- {} ---"; cat {}' \; > "$LOGDIR/cgroup-memory-max.txt" 2>&1 || true

  echo "Collecting Docker OOM..."
  docker ps -a --format '{{.ID}} {{.Names}} {{.Status}}' > "$LOGDIR/docker-ps.txt" 2>&1 || true
  for ctr in $(docker ps -aq 2>/dev/null); do
    local oom
    oom=$(docker inspect --format '{{.State.OOMKilled}}' "$ctr" 2>/dev/null) || continue
    if [[ "$oom" == "true" ]]; then
      local name
      name=$(docker inspect --format '{{.Name}}' "$ctr" 2>/dev/null)
      echo "$name (OOMKilled=true)" >> "$LOGDIR/oomkilled-containers.txt"
      docker inspect "$ctr" >> "$LOGDIR/oomkilled-containers.txt" 2>&1
    fi
  done

  echo "Collecting K8s OOMKilled pods..."
  kubectl get pods -A -o json 2>/dev/null | \
    python3 -c "
import json,sys
data=json.load(sys.stdin)
for p in data.get('items',[]):
  for cs in p.get('status',{}).get('containerStatuses',[]):
    ls=cs.get('lastState',{}).get('terminated',{})
    if ls.get('reason')=='OOMKilled':
      print(f\"{p['metadata']['namespace']}/{p['metadata']['name']} container={cs['name']} exitCode={ls.get('exitCode')}\")
" > "$LOGDIR/k8s-oomkilled.txt" 2>&1 || true

  finish
}

# ── Disk diagnostics ───────────────────────────────────────────────
collect_disk() {
  setup

  echo "Collecting disk usage..."
  df -h > "$LOGDIR/df.txt" 2>&1 || true

  echo "Collecting inode usage..."
  df -i > "$LOGDIR/df-inodes.txt" 2>&1 || true

  echo "Collecting large files..."
  du -sh /* 2>/dev/null | sort -rh | head -20 > "$LOGDIR/du-root.txt" 2>&1 || true

  echo "Collecting deleted but open files..."
  lsof +L1 > "$LOGDIR/deleted-open.txt" 2>&1 || true

  echo "Collecting mount points..."
  findmnt > "$LOGDIR/mounts.txt" 2>&1 || true
  mount | grep overlay > "$LOGDIR/overlay-mounts.txt" 2>&1 || true

  echo "Collecting Docker disk..."
  docker system df -v > "$LOGDIR/docker-df.txt" 2>&1 || true

  echo "Collecting IO stats..."
  iostat -xz 1 3 > "$LOGDIR/iostat.txt" 2>&1 || true

  finish
}

# ── DNS diagnostics ────────────────────────────────────────────────
collect_dns() {
  local DOMAIN="${TARGET:-google.com}"
  setup

  echo "Collecting resolv.conf..."
  cat /etc/resolv.conf > "$LOGDIR/resolv.conf" 2>&1 || true

  echo "Collecting DNS resolution..."
  dig "$DOMAIN" +short > "$LOGDIR/dig-short.txt" 2>&1 || true
  dig "$DOMAIN" > "$LOGDIR/dig-full.txt" 2>&1 || true
  dig "$DOMAIN" +trace > "$LOGDIR/dig-trace.txt" 2>&1 || true

  echo "Collecting search domain timing..."
  time dig +search "$DOMAIN" > "$LOGDIR/dig-search.txt" 2>&1 || true

  echo "Collecting nslookup..."
  nslookup "$DOMAIN" > "$LOGDIR/nslookup.txt" 2>&1 || true

  echo "Collecting DNS packets (10)..."
  sudo timeout 10 tcpdump -i any -nn port 53 -c 10 > "$LOGDIR/dns-tcpdump.txt" 2>&1 || true

  # K8s DNS
  echo "Collecting K8s DNS..."
  kubectl get svc -n kube-system 2>/dev/null | grep dns > "$LOGDIR/k8s-dns-svc.txt" 2>&1 || true
  kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50 > "$LOGDIR/coredns-logs.txt" 2>&1 || true

  finish
}

# ── All diagnostics ────────────────────────────────────────────────
collect_all() {
  setup
  collect_system_inner

  if [[ -n "$TARGET" ]]; then
    echo ""
    echo "Collecting container diagnostics for $TARGET..."
    docker inspect "$TARGET" > "$LOGDIR/container-inspect.json" 2>&1 || true
    docker logs --tail 200 "$TARGET" > "$LOGDIR/container-logs.txt" 2>&1 || true
    docker stats --no-stream "$TARGET" > "$LOGDIR/container-stats.txt" 2>&1 || true
    docker top "$TARGET" -aux > "$LOGDIR/container-top.txt" 2>&1 || true
    dmesg -T 2>/dev/null | grep -i 'killed\|oom' > "$LOGDIR/oom-dmesg.txt" 2>&1 || true
  fi

  finish
}

# ── Dispatch ───────────────────────────────────────────────────────
case "$SCENARIO" in
  container)  collect_container ;;
  pod)        collect_pod ;;
  node)       collect_node ;;
  system)     collect_system ;;
  network)    collect_network ;;
  tls)        collect_tls ;;
  ecs)        collect_ecs ;;
  oom)        collect_oom ;;
  disk)       collect_disk ;;
  dns)        collect_dns ;;
  all)        collect_all ;;
  help|--help|-h) help ;;
  *)
    echo "Unknown scenario: $SCENARIO"
    echo "Run: bash bash/collect.sh help"
    exit 1
    ;;
esac
