#!/usr/bin/env bash
# debug/secrets.sh — Devin Bug 101: env var set in UI but empty at runtime
#
# Reads: env vars, /run/repo_secrets/, container env
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/secrets.sh [container]
# Example: debug/secrets.sh staff-tls
#          debug/secrets.sh                  # host-wide (Devin DevBox)

set +e

c="${1:-}"
section() { echo ""; echo "=== $* ==="; }
in_c() { [ -n "$c" ] && docker exec "$c" sh -c "$*" 2>&1 || bash -c "$*" 2>&1; }

if [ "$c" = "-h" ] || [ "$c" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Env vars matching secret patterns ${c:+(in $c)}"
in_c "env | grep -iE 'api|secret|token|key|password|auth' | sort"

section "/run/repo_secrets/ (Devin repo-scoped secrets)"
if [ -d /run/repo_secrets ]; then
  find /run/repo_secrets -name '.env.secrets' 2>/dev/null | while read f; do
    echo "  found: $f"
    echo "  vars:  $(grep -cE '^[A-Z]' "$f" 2>/dev/null) defined"
  done
  [ -z "$(find /run/repo_secrets -name '.env.secrets' 2>/dev/null)" ] && echo "  (no .env.secrets files found)"
else
  echo "  /run/repo_secrets/ does not exist (not a Devin session, or no repo secrets configured)"
fi

section "Sourced vs unsourced check"
echo "If a secret is in /run/repo_secrets but not in env, it hasn't been sourced."
echo "Fix: source /run/repo_secrets/<owner>/<repo>/.env.secrets"
echo "     set -a; . /run/repo_secrets/<owner>/<repo>/.env.secrets; set +a"

if [ -n "$c" ]; then
  section "Container env (full, sorted)"
  docker exec "$c" env 2>/dev/null | sort | head -40
fi

section "Hint"
echo "Devin repo-scoped secrets are NOT auto-injected as env vars."
echo "They live at /run/repo_secrets/<owner>/<repo>/.env.secrets"
echo "You must source them manually or in your environment config."
echo "Common gotcha: secret added in UI → shows in file → not sourced → env var empty"
