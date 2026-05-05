#!/usr/bin/env bash
# dprobe — keyword-driven debug dispatcher.
#
# Run: dprobe <keyword> [container] [extra-args]
#
# Each keyword runs a focused diagnostic block. Use when you've already
# narrowed the problem class (vs `multi-symptom-probe.sh` which dumps
# everything).
#
# Keywords:
#   gateway    Multi-symptom service gateway probe (full dump)
#   oom        OOM debugging — cgroup memory.events, dmesg, oom_score
#   network    DNS + listening ports + interfaces + connectivity tests
#   dns        Just DNS: resolv.conf, dig, getent, /etc/hosts
#   tls        TLS / cert chain + dates + per-tool trust stores
#   procs      Process tree, zombies, stuck-D-state, top consumers
#   leak       Memory + FD leak watch (continuous samples)
#   cgroup     Cgroup limits + memory.events + cpu.stat throttling
#   disk       df + du + per-process I/O
#   throttle   CPU throttling specifically (Devin DevBox classic)
#   secrets    Devin Bug 101 — env vars + /run/repo_secrets check
#   restart    Container restart-loop investigation
#   help       List keywords + examples
#
# Usage examples:
#   dprobe gateway staff-tls
#   dprobe oom staff-tls
#   dprobe leak staff-tls 20            # 20 samples
#   dprobe tls staff-tls auth.corp.internal:8443
#   dprobe dns staff-tls db.corp.internal
#   dprobe procs                         # host-side
#
# Install: source this file or symlink to /usr/local/bin/dprobe.

set +e

# ---------- helpers ----------
_d_in_container() {
  # Run a command inside container if name given, else on host.
  local c="$1"; shift
  if [ -n "$c" ]; then
    docker exec "$c" sh -c "$*" 2>&1
  else
    bash -c "$*" 2>&1
  fi
}
_d_section() { echo ""; echo "=== $* ==="; }
_d_die() { echo "$*" >&2; exit 1; }

# ---------- keywords ----------
_k_gateway() {
  local c="$1"
  [ -z "$c" ] && _d_die "usage: dprobe gateway <container>"
  if [ -f "$(dirname "$0")/multi-symptom-probe.sh" ]; then
    docker exec -i "$c" bash < "$(dirname "$0")/multi-symptom-probe.sh"
  else
    echo "multi-symptom-probe.sh not found alongside dprobe.sh" >&2
    return 1
  fi
}

_k_oom() {
  local c="$1"
  _d_section "Container OOM signal (if container given)"
  [ -n "$c" ] && {
    docker inspect "$c" --format '{{.Name}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}} MemLimit={{.HostConfig.Memory}}'
    docker inspect "$c" --format '{{.LogPath}}' | xargs -I{} echo "log: {}"
  }
  _d_section "Kernel OOM events"
  sudo dmesg -T 2>/dev/null | grep -iE 'killed process|out of memory|oom-killer' | tail -10
  _d_section "Cgroup memory.events (per-container if given)"
  if [ -n "$c" ]; then
    cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/memory.events 2>/dev/null
  else
    cat /sys/fs/cgroup/memory.events 2>/dev/null
  fi
  _d_section "Top RSS consumers"
  ps -eo pid,rss,comm --sort=-rss | head -10
  _d_section "Per-process VmSwap (if any)"
  for p in /proc/[0-9]*; do
    s=$(awk '/^VmSwap/{print $2}' "$p"/status 2>/dev/null)
    [ -z "$s" ] || [ "$s" -eq 0 ] && continue
    printf '%s %skB %s\n' "$(basename "$p")" "$s" "$(cat "$p"/comm 2>/dev/null)"
  done | sort -k2 -rn | head -5
}

_k_network() {
  local c="$1"
  _d_section "Listening ports (host)"
  sudo ss -tlnp 2>/dev/null | head -15
  _d_section "Interfaces"
  ip -br link 2>/dev/null
  ip -br addr 2>/dev/null
  _d_section "Routes"
  ip route show 2>/dev/null
  _d_section "Conntrack count"
  echo "current: $(sudo cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo n/a)"
  echo "max:     $(sudo cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo n/a)"
  if [ -n "$c" ]; then
    _d_section "Container DNS + ports"
    _d_in_container "$c" "cat /etc/resolv.conf"
    _d_in_container "$c" "ss -tlnp 2>/dev/null | head"
  fi
}

_k_dns() {
  local c="$1"; shift
  local target="${1:-google.com}"
  [ -n "$c" ] && {
    _d_section "Container resolv.conf"
    _d_in_container "$c" "cat /etc/resolv.conf"
    _d_section "Container /etc/hosts"
    _d_in_container "$c" "cat /etc/hosts"
    _d_section "From container: dig + getent for $target"
    _d_in_container "$c" "dig +short $target 2>/dev/null"
    _d_in_container "$c" "getent hosts $target"
  } || {
    _d_section "Host resolv.conf"
    cat /etc/resolv.conf
    _d_section "Host: dig + getent for $target"
    dig +short "$target" 2>/dev/null
    getent hosts "$target"
  }
  _d_section "resolvectl status (if present)"
  resolvectl status 2>/dev/null | head -20
}

_k_tls() {
  local c="$1"; shift
  local hp="${1:-localhost:443}"
  local host="${hp%:*}"
  local port="${hp##*:}"
  _d_section "TLS handshake to $hp"
  if [ -n "$c" ]; then
    _d_in_container "$c" "echo | openssl s_client -connect $hp -servername $host 2>&1 | grep -E 'subject|issuer|verify|CN='"
    _d_section "Cert dates"
    _d_in_container "$c" "echo | openssl s_client -connect $hp 2>&1 | openssl x509 -noout -dates 2>/dev/null"
    _d_section "Cert chain (server-presented)"
    _d_in_container "$c" "echo | openssl s_client -connect $hp -showcerts 2>&1 | grep -E 'depth|verify|^   [is]:'"
    _d_section "Container CA env vars"
    _d_in_container "$c" "env | grep -iE 'CA_|CERT|SSL'"
  else
    echo | openssl s_client -connect "$hp" -servername "$host" 2>&1 | grep -E 'subject|issuer|verify|CN='
    _d_section "Cert dates"
    echo | openssl s_client -connect "$hp" 2>&1 | openssl x509 -noout -dates 2>/dev/null
    _d_section "Date sanity (clock skew check)"
    date -u
    curl -sI https://www.google.com 2>/dev/null | grep -i ^date
  fi
}

_k_procs() {
  local c="$1"
  _d_section "Process tree"
  _d_in_container "$c" "ps auxf 2>/dev/null || ps -ef --forest" | head -40
  _d_section "Zombies"
  zc=$(_d_in_container "$c" "ps -eo state | awk '\$1==\"Z\"' | wc -l")
  echo "zombie count: $zc"
  [ "$zc" -gt 0 ] && {
    _d_in_container "$c" "ps -eo pid,ppid,state,cmd | awk '\$3==\"Z\" || \$3 ~ /^Z/'" | head -10
    echo ""
    echo "PID 1 is:"
    _d_in_container "$c" "ps -eo pid,cmd | head -2 | tail -1"
    echo "Hint: 'docker run --init' adds tini to reap"
  }
  _d_section "D-state (uninterruptible — usually I/O)"
  _d_in_container "$c" "ps -eo pid,stat,wchan,cmd | awk '\$2 ~ /^D/'"
  _d_section "Top CPU"
  _d_in_container "$c" "ps -eo pid,pcpu,rss,cmd --sort=-pcpu | head -10"
}

_k_leak() {
  local c="$1"; shift
  local n="${1:-20}"
  local ep="${GATEWAY_PORT:-5000}"
  _d_section "Leak watch ($n samples, 0.3s apart)"
  if [ -n "$c" ]; then
    echo "i  RSS_MB  fd_count"
    for i in $(seq 1 "$n"); do
      pid=$(docker exec "$c" sh -c "pgrep -f 'gateway\|server\|node' | head -1")
      [ -z "$pid" ] && continue
      rss=$(docker exec "$c" sh -c "awk '/VmRSS/ {print int(\$2/1024)}' /proc/$pid/status 2>/dev/null")
      fd=$(docker exec "$c" sh -c "ls /proc/$pid/fd 2>/dev/null | wc -l")
      printf "%-3d %-7s %s\n" "$i" "$rss" "$fd"
      sleep 0.3
    done
  else
    echo "(needs container arg to track per-process)"
  fi
  _d_section "Gateway memoryMB / requestLogSize across $n requests"
  for i in $(seq 1 "$n"); do
    out=$(curl -sf "http://localhost:$ep" 2>/dev/null)
    [ -n "$out" ] && echo "$out" | (jq -c '{i:'"$i"',memoryMB,requestLogSize,totalRequests}' 2>/dev/null || echo "$out")
    sleep 0.2
  done
}

_k_cgroup() {
  local c="$1"
  _d_section "Cgroup memory + cpu (host)"
  cat /sys/fs/cgroup/memory.events 2>/dev/null
  cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep -E 'nr_throttled|throttled_usec'
  if [ -n "$c" ]; then
    cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
    _d_section "Container cgroup state"
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/memory.events 2>/dev/null
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/memory.current 2>/dev/null
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/memory.max 2>/dev/null
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/cpu.stat 2>/dev/null | grep throttled
  fi
}

_k_throttle() {
  local c="$1"
  _d_section "CPU throttling (Devin DevBox classic — 'slow but CPU low')"
  cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep -E 'nr_throttled|throttled_usec'
  if [ -n "$c" ]; then
    cid=$(docker inspect "$c" --format '{{.Id}}' 2>/dev/null)
    _d_section "Container CPU throttling"
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/cpu.stat 2>/dev/null | grep -E 'nr_throttled|throttled_usec'
    cat /sys/fs/cgroup/system.slice/docker-${cid}.scope/cpu.max 2>/dev/null
    docker stats --no-stream --format '{{.Name}} {{.CPUPerc}}' "$c"
  fi
  _d_section "Hint"
  echo "If throttled_usec is climbing while %CPU appears low → cgroup quota is the bottleneck"
  echo "Fix paths: raise --cpus / --cpu-quota, OR shed load, OR profile what's hot"
}

_k_disk() {
  local c="$1"
  _d_section "df -h"
  df -h | head -10
  _d_section "Top dirs by size (under common heavy paths)"
  for d in /var /tmp /home /var/lib/docker; do
    [ -d "$d" ] && du -sh "$d"/* 2>/dev/null | sort -h | tail -3
  done
  _d_section "I/O activity"
  iostat -xz 1 2 2>/dev/null | tail -20
  _d_section "Per-process I/O"
  ps -eo pid,cmd --sort=-rss | head -5 | awk 'NR>1 {print $1}' | while read p; do
    [ -f "/proc/$p/io" ] && { echo "PID $p:"; cat "/proc/$p/io" 2>/dev/null | sed 's/^/  /'; }
  done
}

_k_secrets() {
  local c="$1"
  _d_section "Bug 101 — Devin repo-scoped secrets check"
  _d_section "Container env (look for missing API keys / tokens)"
  _d_in_container "$c" "env | grep -iE 'api|secret|token|key|password' | head"
  _d_section "/run/repo_secrets/ (Devin's repo-scoped secret path)"
  _d_in_container "$c" "ls /run/repo_secrets/ 2>/dev/null"
  _d_in_container "$c" "find /run/repo_secrets/ -name '.env.secrets' 2>/dev/null"
  _d_section "Hint"
  echo "If repo-scoped secret file exists but env vars empty:"
  echo "  set -a; source /run/repo_secrets/<owner>/<repo>/.env.secrets; set +a"
  echo "Permanent fix: add the source to environment.yaml maintenance section"
}

_k_restart() {
  local c="$1"
  [ -z "$c" ] && _d_die "usage: dprobe restart <container>"
  _d_section "Restart count + state"
  docker inspect "$c" --format 'name={{.Name}} status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} policy={{.HostConfig.RestartPolicy.Name}}'
  _d_section "Recent die events"
  docker events --since 1h --filter container="$c" --filter event=die --format '{{.Time}} {{.Action}} exit={{.Actor.Attributes.exitCode}}' &
  events_pid=$!
  sleep 2
  kill $events_pid 2>/dev/null
  _d_section "Last logs"
  docker logs --tail 30 "$c" 2>&1 | tail -30
  _d_section "Hint"
  echo "If exit code 137: OOMKilled. Check memory limit + RSS at death:"
  echo "  docker inspect $c --format '{{.HostConfig.Memory}}'"
  echo "If exit code 143: SIGTERM (graceful shutdown signal received)"
  echo "If exit code 1: app-level error, read the logs"
}

_k_help() {
  cat <<EOF
dprobe — keyword-driven container/host debug dispatcher

Usage:
  dprobe <keyword> [container] [extra-args]

Keywords:
  gateway   <c>          Multi-symptom service gateway full dump
  oom       [c]          OOM signals (cgroup events, dmesg, oom_score)
  network   [c]          Listening ports + interfaces + routes + conntrack
  dns       [c] [host]   resolv.conf + dig + getent for host
  tls       [c] [host:port]  Cert chain + dates + container CA env vars
  procs     [c]          Process tree + zombies + D-state + top CPU
  leak      <c> [n]      Memory + fd leak watch (n samples, default 20)
  cgroup    [c]          memory.events + cpu.stat (host + container)
  throttle  [c]          CPU throttling probe (DevBox classic)
  disk      [c]          df + du + iostat + per-process I/O
  secrets   <c>          Devin Bug 101 — repo-scoped secret check
  restart   <c>          Restart count + die events + logs

Examples:
  dprobe gateway staff-tls
  dprobe leak staff-tls 30
  dprobe tls staff-tls auth.corp.internal:8443
  dprobe dns '' db.corp.internal     # quote empty container = run on host
  dprobe oom staff-tls
EOF
}

# ---------- dispatch ----------
kw="${1:-help}"
shift 2>/dev/null
case "$kw" in
  gateway)   _k_gateway   "$@" ;;
  oom)       _k_oom       "$@" ;;
  network|net) _k_network "$@" ;;
  dns)       _k_dns       "$@" ;;
  tls|cert)  _k_tls       "$@" ;;
  procs|ps)  _k_procs     "$@" ;;
  leak|mem)  _k_leak      "$@" ;;
  cgroup|cg) _k_cgroup    "$@" ;;
  throttle)  _k_throttle  "$@" ;;
  disk|df)   _k_disk      "$@" ;;
  secrets)   _k_secrets   "$@" ;;
  restart|loop) _k_restart "$@" ;;
  help|-h|--help|"") _k_help ;;
  *) echo "unknown keyword: $kw" >&2; _k_help; exit 2 ;;
esac
