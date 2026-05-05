#!/usr/bin/env bash
# multi-symptom-probe.sh
#
# Drop into ANY container during a multi-symptom incident. Dumps everything
# you'd want to see in one structured report. Then read top-to-bottom.
#
# Usage (3 ways):
#
#   1. Inside the container — `bash probe.sh`
#   2. From the host without copying the file:
#      docker exec -i <container> bash < /path/to/multi-symptom-probe.sh
#   3. Pipe over the network:
#      curl -sL https://raw.githubusercontent.com/aaronstone2/Domains/main/practice/debug-tools/multi-symptom-probe.sh \
#        | docker exec -i <container> bash
#
# Designed to fail-soft: every section continues even if a tool is missing.
# Never modifies state. Read-only diagnostic.

set +e
PROBE_TS=$(date -u 2>/dev/null || echo "?")
GW_PORT=${GATEWAY_PORT:-5000}

echo "=================================================="
echo "MULTI-SYMPTOM PROBE — $PROBE_TS"
echo "=================================================="

# 1. ENV — CA paths, service URLs, anything cert/secret-related
echo ""
echo "=== 1. ENV (CA / URLs / certs) ==="
env | grep -iE '^(CA_|.*_CERT|.*_CA_|NODE_EXTRA|SSL_|.*_URL|.*_HOST|.*_PORT|.*_SECRET|.*_TOKEN)' | sort | head -40

# 2. /etc/hosts — fake DNS entries
echo ""
echo "=== 2. /etc/hosts ==="
cat /etc/hosts 2>/dev/null

# 3. /etc/resolv.conf — DNS resolver chain
echo ""
echo "=== 3. /etc/resolv.conf ==="
cat /etc/resolv.conf 2>/dev/null

# 4. Listening ports — what's actually serving
echo ""
echo "=== 4. Listening ports ==="
(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | head -20

# 5. Process tree (auxf shows parent-child)
echo ""
echo "=== 5. Process tree ==="
(ps auxf 2>/dev/null || ps -ef --forest 2>/dev/null) | head -40

# 6. Zombie count (PID 1 doesn't reap → zombies pile up)
echo ""
echo "=== 6. Zombies ==="
zcount=$(ps -eo state 2>/dev/null | awk '$1=="Z"' | wc -l)
echo "Zombie count: $zcount"
if [ "$zcount" -gt 0 ]; then
  echo "Likely cause: PID 1 doesn't reap. PID 1 is:"
  ps -eo pid,cmd | head -2 | tail -1
  echo "Sample zombies:"
  ps -eo pid,ppid,state,cmd 2>/dev/null | awk '$3=="Z" || $3 ~ /^Z/' | head -5
  echo "Fix: docker run --init ... (adds tini as PID 1 to reap)"
fi

# 7. Application config files
echo ""
echo "=== 7. Application config ==="
for f in /etc/app/*.yaml /etc/app/*.yml /etc/app/*.json \
         /etc/*.yaml /etc/*.yml /etc/*.json \
         /app/config.* /app/*.yaml /app/*.yml \
         /opt/app/*.yaml /opt/*/config*; do
  [ -f "$f" ] 2>/dev/null && { echo "--- $f ---"; cat "$f" 2>/dev/null | head -50; }
done

# 8. Application log tails
echo ""
echo "=== 8. App log tails ==="
for log in /var/log/app/*.log /var/log/*.log /app/*.log /tmp/app/*.log; do
  [ -f "$log" ] 2>/dev/null && { echo "--- $log ---"; tail -25 "$log" 2>/dev/null; }
done

# 9. SSL/TLS cert paths
echo ""
echo "=== 9. SSL/TLS cert paths ==="
for d in /etc/ssl/custom /etc/ssl/corp /etc/ssl/certs /usr/local/share/ca-certificates /opt/certs; do
  [ -d "$d" ] && { echo "--- $d ---"; ls -la "$d" 2>/dev/null | head -10; }
done

# 10. Probe each *_URL env var — DNS + TCP + TLS in one shot
echo ""
echo "=== 10. Probe each *_URL env var ==="
for url_var in $(env | grep -E '_URL=' | cut -d= -f1); do
  url=$(env | grep "^$url_var=" | cut -d= -f2-)
  host_port=$(echo "$url" | sed -E 's|^[a-z]+://||; s|@.*@|@|; s|^.*@||; s|/.*$||')
  host=${host_port%:*}
  port=${host_port##*:}
  [ "$host" = "$port" ] && port=""
  echo "--- $url_var = $url ---"
  echo "  Host:Port = $host:$port"
  resolved=$(getent hosts "$host" 2>/dev/null | awk '{print $1}')
  echo "  DNS:        ${resolved:-NXDOMAIN}"
  if [ -n "$port" ]; then
    timeout 3 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null \
      && { echo "  TCP $port:  open"; exec 3<&- 3>&-; } \
      || echo "  TCP $port:  refused/timeout"
  fi
  case "$url" in
    https://*)
      echo "  TLS handshake / cert info:"
      timeout 5 openssl s_client -connect "$host:$port" -servername "$host" </dev/null 2>&1 \
        | grep -E 'depth|verify|notAfter|notBefore|^   [is]:' | head -10 | sed 's/^/    /'
      ;;
  esac
done

# 11. Memory leak watch — hit gateway N times, look for growth
echo ""
echo "=== 11. Gateway memory across 10 requests ==="
if command -v curl >/dev/null && curl -sf "http://localhost:$GW_PORT" >/dev/null 2>&1; then
  echo "Hit  memoryMB  requestLogSize  totalRequests"
  for i in $(seq 1 10); do
    out=$(curl -sf "http://localhost:$GW_PORT" 2>/dev/null)
    if command -v jq >/dev/null; then
      mem=$(echo "$out" | jq -r '.memoryMB // "?"' 2>/dev/null)
      log=$(echo "$out" | jq -r '.requestLogSize // "?"' 2>/dev/null)
      total=$(echo "$out" | jq -r '.totalRequests // "?"' 2>/dev/null)
    else
      mem=$(echo "$out" | grep -oE '"memoryMB":[0-9]+' | grep -oE '[0-9]+')
      log=$(echo "$out" | grep -oE '"requestLogSize":[0-9]+' | grep -oE '[0-9]+')
      total=$(echo "$out" | grep -oE '"totalRequests":[0-9]+' | grep -oE '[0-9]+')
    fi
    printf "%-4d %-9s %-15s %s\n" "$i" "$mem" "$log" "$total"
    sleep 0.1
  done
else
  echo "(no curl or gateway not on localhost:$GW_PORT)"
fi

# 12. cgroup limits — memory + cpu
echo ""
echo "=== 12. Cgroup limits ==="
if [ -f /sys/fs/cgroup/memory.max ]; then
  echo "memory.max:    $(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
  echo "memory.current:$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"
  echo "memory.events:"
  cat /sys/fs/cgroup/memory.events 2>/dev/null | sed 's/^/  /'
  echo "cpu.max:       $(cat /sys/fs/cgroup/cpu.max 2>/dev/null)"
  echo "cpu.stat (throttled):"
  grep -E 'nr_throttled|throttled_usec' /sys/fs/cgroup/cpu.stat 2>/dev/null | sed 's/^/  /'
fi

# 13. Disk / fd / open files
echo ""
echo "=== 13. Disk + fd ==="
df -h 2>/dev/null | head -5
echo "Open fds (top 5 procs):"
for pid in /proc/[0-9]*; do
  p=$(basename $pid)
  used=$(ls $pid/fd 2>/dev/null | wc -l)
  [ "$used" -gt 0 ] && printf '%6d %5d %s\n' "$used" "$p" "$(cat $pid/comm 2>/dev/null)"
done | sort -rn | head -5

echo ""
echo "=================================================="
echo "PROBE COMPLETE — $(date -u 2>/dev/null)"
echo "=================================================="
echo ""
echo "What to look for in the output:"
echo "  - Section 1: missing CA env vars OR pointing at wrong file"
echo "  - Section 2-3: DNS routing — fake /etc/hosts entries, missing upstreams"
echo "  - Section 4: services on unexpected ports"
echo "  - Section 5-6: zombies = no init"
echo "  - Section 7: config file paths/values vs actual env vars"
echo "  - Section 8: smoking-gun stack traces"
echo "  - Section 10: per-URL DNS+TCP+TLS triage"
echo "  - Section 11: memoryMB growing = leak"
echo "  - Section 12: throttled_usec growing = cgroup CPU throttling"
echo "  - Section 13: fd count near limit = leak"
