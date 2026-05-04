#!/usr/bin/env bash
# Scenario: Trying to start a service on port 8080, but "address already in use".
# Symptom:  `EADDRINUSE` / `bind: address already in use`
# Suggested:`ha "address already in use"` or `ha "port already bound"`
# Restore:  kill the holder process

set -uo pipefail
DIR="/tmp/domains-practice/05-port"
PIDFILE="$DIR/holder.pid"
PORT="${PRACTICE_PORT:-18080}"

start() {
  mkdir -p "$DIR"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[05-port-collision] already running (pid=$(cat "$PIDFILE"))"
  elif command -v python3 >/dev/null 2>&1; then
    # No nohup: bash $! captures nohup's pid not python's. setsid for detachment.
    setsid python3 -m http.server "$PORT" --bind 127.0.0.1 > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 0.4
  elif command -v nc >/dev/null 2>&1; then
    setsid nc -l -p "$PORT" > /dev/null 2>&1 < /dev/null &
    echo "$!" > "$PIDFILE"
    sleep 0.4
  else
    echo "[05-port-collision] needs python3 or nc — install one and re-run"
    exit 1
  fi
  cat <<EOF

Scenario:  You're trying to start your own service on port $PORT but it
           refuses with "address already in use". Identify what's holding
           the port and stop it.

What's true: A small HTTP/listener is bound to 127.0.0.1:$PORT.

Try:       \`pnpm harness ask "address already in use"\`
           \`ss -tlnp\`                              # listening sockets + pid
           \`ss -tlnp 'sport = :$PORT'\`
           \`sudo lsof -i :$PORT\`                   # alternative
           \`fuser -n tcp $PORT\`                    # who's holding it
           \`netstat -tlnp 2>/dev/null | grep $PORT\` (older systems)

Reveal:    $0 reveal
Restore:   $0 restore (kills the holder)
Verify:    $0 verify
EOF
}

restore() {
  if [[ -f "$PIDFILE" ]]; then
    local pid; pid="$(cat "$PIDFILE")"
    kill "$pid" 2>/dev/null || true
    sleep 0.3
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  rm -rf "$DIR"
  echo "[05-port-collision] cleaned"
}

verify() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[05-port-collision] still holding port $PORT. Run: $0 restore"
    return 1
  else
    echo "[05-port-collision] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[05-port-collision] reveal:

  Failure mode id:    linux.fm.port-already-in-use / linux.fm.bind-eaddrinuse
  Why it happens:     another process already bound the same port:protocol pair
  Diagnostic:         ss -tlnp 'sport = :PORT'             (modern, fast)
                      sudo lsof -i :PORT                   (more detail, needs sudo for foreign procs)
                      fuser -n tcp PORT                    (just pid)
                      cat /proc/net/tcp                    (raw, last resort)
  Fix:                kill <pid>                           (graceful)
                      OR pick a different port
                      OR set SO_REUSEPORT in your service if intentional sharing
  Trade-off:          TIME_WAIT after a kill: socket may stay bound briefly.
                      SO_REUSEADDR helps but doesn't help with TIME_WAIT on
                      same {srcip, srcport, dstip, dstport} 4-tuple.
                      Common gotcha: docker-published ports can show as held
                      by docker-proxy; check `docker ps --format ...` too.

  Reference: pnpm harness ask "port already in use"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
