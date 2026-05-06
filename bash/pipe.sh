#!/usr/bin/env bash
# pipe.sh -- Source this to get shortcut functions that auto-pipe to ~/logs/
#
# Usage:   source bash/pipe.sh
# Then:    di myapp           docker inspect -> ~/logs/inspect-myapp.json
#          dl myapp           docker logs    -> ~/logs/logs-myapp.txt
#          kl mypod           kubectl logs   -> ~/logs/klogs-mypod.txt
#          p myfile.txt cmd   any command    -> ~/logs/myfile.txt
#
# Every function prints the output path so you can tell Claude Code:
#   "Read ~/logs/inspect-myapp.json and diagnose"

mkdir -p "$HOME/logs"

# -- helper -------------------------------------------------------------------
_p() {
  local file="$HOME/logs/$1"
  shift
  "$@" > "$file" 2>&1
  echo "=> $file"
}

# -- Docker -------------------------------------------------------------------

# docker inspect <container>
di() {
  _p "inspect-${1}.json" docker inspect "$1"
}

# docker logs <container> [--tail N]
dl() {
  local c="$1"; shift
  _p "logs-${c}.txt" docker logs ${@:---tail 200} "$c"
}

# docker stats (snapshot)
ds() {
  _p "stats-${1:-all}.txt" docker stats --no-stream ${1:+"$1"}
}

# docker top <container>
dt() {
  _p "top-${1}.txt" docker top "$1" -aux
}

# docker events (last 10 min)
de() {
  _p "events-${1:-all}.txt" docker events --since 10m --until 0s ${1:+--filter "container=$1"}
}

# docker diff <container>
ddi() {
  _p "diff-${1}.txt" docker diff "$1"
}

# docker ps -a
dps() {
  _p "ps.txt" docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
}

# docker system df
ddf() {
  _p "docker-df.txt" docker system df -v
}

# docker info
din() {
  _p "docker-info.txt" docker info
}

# docker exec <container> <cmd...>
dx() {
  local c="$1"; shift
  local label
  label=$(echo "$*" | tr ' /' '--' | head -c 40)
  _p "exec-${c}-${label}.txt" docker exec "$c" "$@"
}

# -- Kubernetes ---------------------------------------------------------------

# kubectl logs <pod> [-n ns]
kl() {
  local pod="$1"; shift
  _p "klogs-${pod}.txt" kubectl logs "$pod" --tail=200 "$@"
}

# kubectl logs --previous
klp() {
  local pod="$1"; shift
  _p "klogs-prev-${pod}.txt" kubectl logs "$pod" --previous --tail=200 "$@"
}

# kubectl describe pod
kd() {
  local pod="$1"; shift
  _p "kdesc-${pod}.txt" kubectl describe pod "$pod" "$@"
}

# kubectl get pod -o yaml
ky() {
  local pod="$1"; shift
  _p "kyaml-${pod}.yaml" kubectl get pod "$pod" -o yaml "$@"
}

# kubectl get events
kev() {
  _p "kevents.txt" kubectl get events ${1:+-n "$1"} --sort-by='.lastTimestamp'
}

# kubectl top pod
ktp() {
  _p "ktop-${1:-all}.txt" kubectl top pod ${1:+"$1"} ${2:+-n "$2"}
}

# kubectl top node
ktn() {
  _p "ktop-node-${1:-all}.txt" kubectl top node ${1:+"$1"}
}

# kubectl get nodes -o wide
kn() {
  _p "knodes.txt" kubectl get nodes -o wide
}

# kubectl exec <pod> -- <cmd...>
kx() {
  local pod="$1"; shift
  local label
  label=$(echo "$*" | tr ' /' '--' | head -c 40)
  _p "kexec-${pod}-${label}.txt" kubectl exec "$pod" -- "$@"
}

# -- Linux / System -----------------------------------------------------------

# dmesg (last 200 lines)
dm() {
  _p "dmesg.txt" bash -c 'dmesg -T 2>/dev/null | tail -200'
}

# dmesg OOM only
dmo() {
  _p "dmesg-oom.txt" bash -c 'dmesg -T 2>/dev/null | grep -i "killed\|oom\|out of memory" || echo "(none found)"'
}

# free -h
mf() {
  _p "free.txt" free -h
}

# /proc/meminfo
mi() {
  _p "meminfo.txt" cat /proc/meminfo
}

# ps top memory consumers
pm() {
  _p "ps-mem.txt" bash -c 'ps aux --sort=-%mem | head -30'
}

# ps top CPU consumers
pc() {
  _p "ps-cpu.txt" bash -c 'ps aux --sort=-%cpu | head -30'
}

# ps full tree
pa() {
  _p "ps-tree.txt" ps auxf
}

# df -h (disk)
dfh() {
  _p "df.txt" df -h
}

# df -i (inodes)
dfi() {
  _p "df-inodes.txt" df -i
}

# du top-level
dut() {
  _p "du-top.txt" bash -c 'du -sh /* 2>/dev/null | sort -rh | head -20'
}

# lsof deleted but open files
lsd() {
  _p "lsof-deleted.txt" lsof +L1
}

# ss listening ports
sp() {
  _p "ports.txt" ss -tlnp
}

# ss all TCP connections
sc() {
  _p "connections.txt" ss -tan
}

# ss TIME_WAIT count
stw() {
  _p "time-wait.txt" bash -c 'echo "TIME_WAIT count: $(ss -tan state time-wait | wc -l)"'
}

# iptables
ipt() {
  _p "iptables.txt" sudo iptables -L -n -v --line-numbers
}

# iptables NAT
ipn() {
  _p "iptables-nat.txt" sudo iptables -t nat -L -n -v
}

# conntrack
ct() {
  _p "conntrack.txt" bash -c 'echo "count: $(conntrack -C 2>/dev/null || echo n/a)"; echo "max: $(sysctl -n net.nf_conntrack_max 2>/dev/null || echo n/a)"'
}

# ulimits
ul() {
  _p "ulimits.txt" ulimit -a
}

# uptime + load
up() {
  _p "uptime.txt" uptime
}

# vmstat
vs() {
  _p "vmstat.txt" vmstat 1 5
}

# iostat
io() {
  _p "iostat.txt" iostat -xz 1 3
}

# findmnt
mnt() {
  _p "mounts.txt" findmnt
}

# namespaces
nss() {
  _p "namespaces.txt" lsns
}

# -- Network ------------------------------------------------------------------

# ip addr
ia() {
  _p "ip-addr.txt" ip addr show
}

# ip route
ir() {
  _p "ip-route.txt" ip route show
}

# curl verbose
cv() {
  local url="$1"
  local label
  label=$(echo "$url" | tr '/:.' '----' | tr -cd 'a-zA-Z0-9-' | head -c 40)
  _p "curl-${label}.txt" curl -sv --connect-timeout 5 "$url"
}

# dig
dg() {
  _p "dig-${1}.txt" dig "$1"
}

# dig trace
dgt() {
  _p "dig-trace-${1}.txt" dig "$1" +trace
}

# traceroute
trt() {
  _p "traceroute-${1}.txt" traceroute -n -w 2 "$1"
}

# tcpdump (10 packets)
td() {
  _p "tcpdump-${1}.txt" sudo timeout 10 tcpdump -i any -nn "host $1" -c 10
}

# resolv.conf
rsc() {
  _p "resolv.conf" cat /etc/resolv.conf
}

# -- TLS ----------------------------------------------------------------------

# openssl cert check
tlsc() {
  local host="$1"
  local port="${2:-443}"
  _p "tls-${host}.txt" bash -c "openssl s_client -connect ${host}:${port} -servername ${host} </dev/null 2>&1"
}

# openssl cert dates + subject
tlsd() {
  local host="$1"
  local port="${2:-443}"
  _p "tls-dates-${host}.txt" bash -c "openssl s_client -connect ${host}:${port} -servername ${host} </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer"
}

# openssl full chain
tlscc() {
  local host="$1"
  local port="${2:-443}"
  _p "tls-chain-${host}.txt" bash -c "openssl s_client -connect ${host}:${port} -servername ${host} -showcerts </dev/null 2>&1"
}

# -- Cgroup (by container) ----------------------------------------------------

cg() {
  local ctr="$1"
  local pid
  pid=$(docker inspect --format '{{.State.Pid}}' "$ctr" 2>/dev/null) || { echo "Can't get PID for $ctr"; return 1; }
  local cgdir
  cgdir=$(cat /proc/"$pid"/cgroup 2>/dev/null | head -1 | cut -d: -f3) || true
  {
    echo "PID: $pid"
    echo "Cgroup: $cgdir"
    echo ""
    for stat in memory.max memory.current memory.events cpu.stat cpu.max pids.max pids.current; do
      local f="/sys/fs/cgroup${cgdir}/${stat}"
      if [[ -f "$f" ]]; then
        echo "=== $stat ==="
        cat "$f"
        echo ""
      fi
    done
    echo "=== /proc/$pid/limits ==="
    cat /proc/"$pid"/limits 2>/dev/null || echo "n/a"
    echo ""
    echo "=== /proc/$pid/status ==="
    cat /proc/"$pid"/status 2>/dev/null || echo "n/a"
    echo ""
    echo "=== open FDs ==="
    echo "count: $(ls /proc/"$pid"/fd 2>/dev/null | wc -l)"
  } > "$HOME/logs/cgroup-${ctr}.txt" 2>&1
  echo "=> $HOME/logs/cgroup-${ctr}.txt"
}

# -- ECS ----------------------------------------------------------------------

# ecs describe-tasks
et() {
  local task="$1"
  local cluster="${2:-default}"
  _p "ecs-task.json" aws ecs describe-tasks --cluster "$cluster" --tasks "$task"
}

# ecs describe-services
es() {
  local svc="$1"
  local cluster="${2:-default}"
  _p "ecs-svc-${svc}.json" aws ecs describe-services --cluster "$cluster" --services "$svc"
}

# -- Journald -----------------------------------------------------------------

# journalctl for a unit
jl() {
  _p "journal-${1}.txt" journalctl -u "$1" --no-pager -n 200
}

# journalctl since 10 min ago
jr() {
  _p "journal-recent.txt" journalctl --since '10 min ago' --no-pager -n 200
}

# -- Generic: pipe any command ------------------------------------------------

# p <filename> <cmd...>
p() {
  local file="$1"; shift
  _p "$file" "$@"
}

# -- List collected files -----------------------------------------------------

lf() {
  echo "~/logs/ contents:"
  ls -lhSt "$HOME/logs/" 2>/dev/null || echo "(empty)"
}

echo "Pipe functions loaded. All output -> ~/logs/"
echo "Run 'lf' to list files. Run 'p <name> <cmd...>' for any command."
