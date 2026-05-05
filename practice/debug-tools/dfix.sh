#!/usr/bin/env bash
# dfix — keyword-driven remediation dispatcher.
#
# Companion to dprobe.sh. After diagnosis, drop the right fix.
#
# SAFETY: dry-run by default. Every keyword PRINTS what it would do. Add
# --apply (-y) to actually mutate. Every fix prints the "permanent fix"
# note (deployment-level config) after the immediate one.
#
# Usage: dfix <keyword> [container] [args...] [--apply]
#
# Keywords:
#   env <c> <KEY> <VALUE>           Set env var inside container (process restart)
#   hosts <c> <ip> <hostname>       Append /etc/hosts entry inside container
#   hosts-rm <c> <hostname>         Remove a /etc/hosts entry
#   dns <c> <dns_ip>                Set custom DNS in container's resolv.conf
#   cabundle <c> <root> <inter>     Concatenate root+intermediate → full-chain.pem
#   cert-renew <c> <name> [days]    Generate new self-signed cert (test-only)
#   reload <c> [pattern]            SIGHUP a process (graceful reload)
#   restart-process <c> [pattern]   Kill + restart a process inside container
#   restart-container <c>           docker restart <c>
#   recreate-init <c>               Stop container, recreate with --init flag (FIXES ZOMBIES)
#   install-tools <c>               apt/apk install dig+openssl+curl+jq (in-container)
#   prune                           docker system prune -af (frees disk)
#   help                            List keywords
#
# Examples:
#   dfix env staff-tls NODE_EXTRA_CA_CERTS /etc/ssl/custom/root-ca.crt --apply
#   dfix hosts staff-tls 10.0.0.5 db.corp.internal --apply
#   dfix dns staff-tls 10.0.0.53 --apply
#   dfix cabundle staff-tls /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt
#   dfix recreate-init staff-tls --apply
#   dfix prune --apply

set +e

APPLY=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --apply|-y) APPLY=true ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]}"

_section()  { echo ""; echo "=== $* ==="; }
_say()      { echo "  $*"; }
_dryrun()   { echo "  [dry-run] $*"; }
_run()      {
  if $APPLY; then
    echo "  [apply]   $*"
    eval "$@"
  else
    _dryrun "$@"
  fi
}
_perm()     { echo ""; echo "  PERMANENT FIX (do this in your deployment config):"; while [ -n "${1:-}" ]; do echo "    $1"; shift; done; }
_verify()   { echo ""; echo "  VERIFY:"; while [ -n "${1:-}" ]; do echo "    $1"; shift; done; }
_die()      { echo "ERROR: $*" >&2; exit 1; }

# ---------- env ----------
_k_env() {
  local c="$1" key="$2" val="$3"
  [ -z "$c" ] || [ -z "$key" ] || [ -z "$val" ] && _die "usage: dfix env <container> <KEY> <VALUE>"
  _section "TEMP FIX: set env var inside running container '$c'"
  _say "KEY=$key  VALUE=$val"
  _say ""
  _say "Strategy: write env var to a file the entrypoint sources, then restart"
  _say "the main process. Container itself stays up (preserves volumes etc.)."
  _say ""
  _run "docker exec $c sh -c 'echo \"export $key=$val\" >> /etc/profile.d/dfix-env.sh'"
  _run "docker exec $c sh -c 'kill -HUP 1 2>/dev/null || true'"
  _say ""
  _say "If process didn't reload (sleep PID 1 doesn't honor HUP), force restart:"
  _run "docker exec $c sh -c 'pkill -f $(printf '%s' \"${val##*/}\") 2>/dev/null'"
  _perm \
    "docker-compose: add 'environment: $key: $val' under the service" \
    "docker run:    -e $key=$val ..." \
    "k8s:           env: [{name: $key, value: $val}]"
  _verify "docker exec $c sh -c 'env | grep $key'"
}

# ---------- hosts (append) ----------
_k_hosts() {
  local c="$1" ip="$2" host="$3"
  [ -z "$c" ] || [ -z "$ip" ] || [ -z "$host" ] && _die "usage: dfix hosts <container> <ip> <hostname>"
  _section "TEMP FIX: append /etc/hosts entry inside '$c'"
  _say "$ip  $host"
  _run "docker exec $c sh -c 'echo \"$ip  $host\" >> /etc/hosts'"
  _perm \
    "docker-compose: under the service:" \
    "  extra_hosts:" \
    "    - \"$host:$ip\"" \
    "OR add a real DNS resolver via 'dns:' field" \
    "" \
    "k8s pod spec:" \
    "  hostAliases:" \
    "    - ip: \"$ip\"" \
    "      hostnames: [\"$host\"]"
  _verify "docker exec $c getent hosts $host"
}

# ---------- hosts-rm ----------
_k_hosts_rm() {
  local c="$1" host="$2"
  [ -z "$c" ] || [ -z "$host" ] && _die "usage: dfix hosts-rm <container> <hostname>"
  _section "TEMP FIX: remove /etc/hosts entries for '$host' in '$c'"
  _run "docker exec $c sh -c 'sed -i \"/\\b$host\\b/d\" /etc/hosts'"
  _verify "docker exec $c getent hosts $host"
}

# ---------- dns (set custom resolver) ----------
_k_dns() {
  local c="$1" dns="$2"
  [ -z "$c" ] || [ -z "$dns" ] && _die "usage: dfix dns <container> <dns_ip>"
  _section "TEMP FIX: prepend custom DNS '$dns' to '$c' resolv.conf"
  _say "Note: changes inside container revert if the container restarts."
  _run "docker exec $c sh -c 'cp /etc/resolv.conf /etc/resolv.conf.bak'"
  _run "docker exec $c sh -c '(echo \"nameserver $dns\"; cat /etc/resolv.conf) > /tmp/.r && cat /tmp/.r > /etc/resolv.conf && rm /tmp/.r'"
  _perm \
    "docker run:    --dns $dns ..." \
    "docker-compose: dns: [\"$dns\"]" \
    "Better: configure host systemd-resolved to forward .corp.internal to corp DNS:" \
    "  /etc/systemd/resolved.conf.d/corp.conf:" \
    "    [Resolve]" \
    "    DNS=$dns" \
    "    Domains=~corp.internal" \
    "  systemctl restart systemd-resolved"
  _verify "docker exec $c cat /etc/resolv.conf | head -3"
}

# ---------- cabundle (concat root + intermediate) ----------
_k_cabundle() {
  local c="$1" root="$2" inter="$3"
  [ -z "$c" ] || [ -z "$root" ] || [ -z "$inter" ] && _die "usage: dfix cabundle <container> <root.pem> <intermediate.pem>"
  local out="/etc/ssl/custom/full-chain.pem"
  _section "TEMP FIX: concat $root + $inter → $out in '$c'"
  _run "docker exec $c sh -c 'cat $root $inter > $out'"
  _run "docker exec $c sh -c 'grep -c \"BEGIN CERTIFICATE\" $out'"
  _say "Then point NODE_EXTRA_CA_CERTS at it:"
  _run "docker exec $c sh -c 'echo \"export NODE_EXTRA_CA_CERTS=$out\" >> /etc/profile.d/dfix-env.sh'"
  _perm \
    "Build the bundle at image-build time, ship as a single file:" \
    "  COPY full-chain.pem /etc/ssl/custom/full-chain.pem" \
    "  ENV NODE_EXTRA_CA_CERTS=/etc/ssl/custom/full-chain.pem"
  _verify \
    "docker exec $c sh -c 'grep -c BEGIN $out'   # should be 2 (root + intermediate)" \
    "docker exec $c node -e 'process.env.NODE_EXTRA_CA_CERTS && console.log(process.env.NODE_EXTRA_CA_CERTS)'"
}

# ---------- cert-renew (test-only self-signed) ----------
_k_cert_renew() {
  local c="$1" name="$2" days="${3:-365}"
  [ -z "$c" ] || [ -z "$name" ] && _die "usage: dfix cert-renew <container> <hostname> [days=365]"
  _section "TEMP FIX: generate new self-signed cert for '$name' valid $days days"
  _say "WARNING: self-signed only. Production should use proper CA."
  _run "docker exec $c sh -c 'openssl req -x509 -newkey rsa:2048 -nodes \\
        -keyout /etc/ssl/custom/$name.key \\
        -out /etc/ssl/custom/$name.crt \\
        -days $days -subj \"/CN=$name\"'"
  _perm \
    "Real fix: use your cert-manager / ACME / internal CA pipeline." \
    "Audit issuance: check for '-days 0' bug if certs come out zero-day."
  _verify "docker exec $c sh -c 'openssl x509 -in /etc/ssl/custom/$name.crt -noout -dates'"
}

# ---------- reload (SIGHUP) ----------
_k_reload() {
  local c="$1" pat="${2:-node}"
  [ -z "$c" ] && _die "usage: dfix reload <container> [pattern]"
  _section "TEMP FIX: SIGHUP processes matching '$pat' in '$c' (graceful reload)"
  _run "docker exec $c sh -c 'pgrep -f $pat | xargs -r kill -HUP'"
  _verify "docker exec $c sh -c 'pgrep -af $pat'"
}

# ---------- restart-process ----------
_k_restart_process() {
  local c="$1" pat="${2:-gateway\\|server\\|node}"
  [ -z "$c" ] && _die "usage: dfix restart-process <container> [pattern]"
  _section "TEMP FIX: kill+restart processes matching '$pat' in '$c'"
  _say "Most container PID 1s will respawn the process if killed."
  _run "docker exec $c sh -c 'pkill -f $pat'"
  sleep 1
  _verify "docker exec $c sh -c 'pgrep -af $pat'"
}

# ---------- restart-container ----------
_k_restart_container() {
  local c="$1"
  [ -z "$c" ] && _die "usage: dfix restart-container <container>"
  _section "TEMP FIX: docker restart $c"
  _run "docker restart $c"
  _verify "docker inspect $c --format '{{.State.Status}} restarts={{.RestartCount}}'"
}

# ---------- recreate-init (FIXES ZOMBIES) ----------
_k_recreate_init() {
  local c="$1"
  [ -z "$c" ] && _die "usage: dfix recreate-init <container>"
  _section "FIX: recreate container '$c' with --init flag (PID 1 reaping)"
  _say "This is the proper fix for zombie-process accumulation. tini becomes"
  _say "PID 1 inside the container and reaps exited children correctly."
  _say ""
  _say "Strategy: capture current image+args+volumes, stop, run with --init."
  local img cmd
  img=$(docker inspect "$c" --format '{{.Config.Image}}' 2>/dev/null)
  cmd=$(docker inspect "$c" --format '{{join .Config.Cmd " "}}' 2>/dev/null)
  _say "Image: $img"
  _say "Cmd:   $cmd"
  _say ""
  _say "MANUAL — copy the docker-run flags from your scenario script + add --init:"
  _say "  docker stop $c && docker rm $c"
  _say "  docker run -d --init --name $c [...all original flags...] $img $cmd"
  _say ""
  _say "(I won't auto-recreate because losing your run-flags would be worse than zombies.)"
  _perm \
    "docker-compose: add 'init: true' under the service" \
    "k8s: pods get init by default in modern k8s; otherwise use shareProcessNamespace + a sidecar"
}

# ---------- install-tools (in-container diag tooling) ----------
_k_install_tools() {
  local c="$1"
  [ -z "$c" ] && _die "usage: dfix install-tools <container>"
  _section "FIX: install diagnostic tools in '$c' (apt or apk)"
  _say "Container often missing dig/openssl/jq/curl — add them for in-container debug."
  _run "docker exec $c sh -c '(apt-get update -y && apt-get install -y --no-install-recommends dnsutils openssl curl jq net-tools iproute2) 2>/dev/null || (apk add --no-cache bind-tools openssl curl jq net-tools iproute2)'"
  _verify "docker exec $c sh -c 'which dig openssl curl jq'"
}

# ---------- prune (free disk) ----------
_k_prune() {
  _section "FIX: docker system prune -af (frees disk by removing stopped containers, unused images, networks, build cache)"
  _say "WARNING: removes ALL stopped containers + ALL images not in use by a running container."
  _run "docker system prune -af"
  _verify "docker system df"
}

_k_help() {
  cat <<EOF
dfix — keyword-driven remediation dispatcher (DRY-RUN BY DEFAULT, --apply to mutate)

Usage:
  dfix <keyword> [container] [args...] [--apply]

Keywords:
  env <c> <KEY> <VALUE>            Set env var inside container (process restart)
  hosts <c> <ip> <hostname>        Append /etc/hosts entry
  hosts-rm <c> <hostname>          Remove /etc/hosts entry
  dns <c> <dns_ip>                 Prepend custom DNS to resolv.conf
  cabundle <c> <root> <inter>      Concat root+intermediate → /etc/ssl/custom/full-chain.pem
  cert-renew <c> <name> [days]     Generate new self-signed cert (test-only)
  reload <c> [pattern]             SIGHUP processes (graceful reload)
  restart-process <c> [pattern]    Kill + container's PID 1 should respawn
  restart-container <c>            docker restart <c>
  recreate-init <c>                Recreate with --init (zombie fix; manual step)
  install-tools <c>                apt/apk install dig+openssl+curl+jq inside container
  prune                            docker system prune -af (frees disk)
  help                             This text

Each fix prints:
  - The TEMP fix command (immediate, inside container)
  - The PERMANENT fix (docker-compose / k8s / Dockerfile change)
  - VERIFY commands to confirm the fix landed

Examples:
  # Multi-symptom gateway scenario fixes:
  dfix env staff-tls NODE_EXTRA_CA_CERTS /etc/ssl/custom/root-ca.crt --apply
  dfix hosts staff-tls 10.0.0.5 db.corp.internal --apply
  dfix hosts staff-tls 10.0.0.6 cache.corp.internal --apply
  dfix dns staff-tls 10.0.0.53 --apply
  dfix cabundle staff-tls /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt --apply

  # OOM scenario:
  dfix restart-container <c> --apply

  # Zombie scenario:
  dfix recreate-init <c>     # prints the manual recipe (intentionally not auto)

  # Disk full scenario:
  dfix prune --apply
EOF
}

# ---------- dispatch ----------
kw="${1:-help}"
shift 2>/dev/null
case "$kw" in
  env)             _k_env "$@" ;;
  hosts)           _k_hosts "$@" ;;
  hosts-rm)        _k_hosts_rm "$@" ;;
  dns)             _k_dns "$@" ;;
  cabundle|chain)  _k_cabundle "$@" ;;
  cert-renew|cert) _k_cert_renew "$@" ;;
  reload)          _k_reload "$@" ;;
  restart-process|kill) _k_restart_process "$@" ;;
  restart-container|restart) _k_restart_container "$@" ;;
  recreate-init|init) _k_recreate_init "$@" ;;
  install-tools|tools) _k_install_tools "$@" ;;
  prune|cleanup)   _k_prune ;;
  help|-h|--help|"") _k_help ;;
  *) echo "unknown keyword: $kw" >&2; _k_help; exit 2 ;;
esac

if ! $APPLY && [ "$kw" != "help" ] && [ -n "$kw" ]; then
  echo ""
  echo "  (DRY RUN — add --apply to actually run the commands above)"
fi
