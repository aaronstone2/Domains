#!/usr/bin/env bash
# debug/blueprint.sh — diagnose Devin environment.yaml / blueprint issues
#
# Reads: environment.yaml, snapshot build status, secret mounts, setup/init logs
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/blueprint.sh [environment.yaml]
# Example: debug/blueprint.sh environment.yaml
#          debug/blueprint.sh                     # auto-detect

set +e

f="${1:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$f" = "-h" ] || [ "$f" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

# Auto-detect environment.yaml
if [ -z "$f" ]; then
  for candidate in environment.yaml environment.yml .devin/environment.yaml; do
    [ -f "$candidate" ] && f="$candidate" && break
  done
fi

if [ -n "$f" ] && [ -f "$f" ]; then
  section "Blueprint file: $f"
  echo "  Lines: $(wc -l < "$f")"

  section "YAML syntax validation"
  python3 -c "
import yaml, sys
try:
  with open('$f') as fh:
    doc = yaml.safe_load(fh)
  print('  ✓ Valid YAML')
  if doc:
    for k in doc:
      print(f'  Section: {k}')
except yaml.YAMLError as e:
  print(f'  ✗ YAML ERROR: {e}')
  sys.exit(1)
" 2>/dev/null || echo "  (python3-yaml not available — install with: pip install pyyaml)"

  section "Sections defined"
  grep -nE '^\w+:' "$f" | while read -r line; do
    echo "  $line"
  done

  section "Common issues check"
  # Check for tabs (YAML hates tabs)
  if grep -Pn '\t' "$f" 2>/dev/null | head -3 | grep -q '.'; then
    echo "  ✗ TABS FOUND (YAML requires spaces):"
    grep -Pn '\t' "$f" | head -3 | sed 's/^/    /'
  else
    echo "  ✓ No tabs found"
  fi

  # Check section names against known valid sections
  grep -oE '^\w+:' "$f" | tr -d ':' | while read -r sec; do
    case "$sec" in
      initialize|setup|maintenance|packages|secrets|repos|env|environment|build|pre_install|post_install|cron)
        echo "  ✓ Known section: $sec" ;;
      *)
        echo "  ? Unknown section: $sec (check docs for valid section names)" ;;
    esac
  done
else
  echo "  No environment.yaml found. Checking common locations..."
  find . -maxdepth 3 -name 'environment.yaml' -o -name 'environment.yml' 2>/dev/null | head -5
  [ $? -ne 0 ] && echo "  (none found)"
fi

section "Repo-scoped secrets available"
if [ -d /run/repo_secrets ]; then
  find /run/repo_secrets -name '.env.secrets' 2>/dev/null | while read -r sf; do
    echo "  $sf"
    grep -c '=' "$sf" 2>/dev/null | { read -r n; echo "    ($n secrets defined)"; }
  done
else
  echo "  /run/repo_secrets does not exist (not in a DevBox?)"
fi

section "Secret env vars in current shell"
env | grep -iE 'SECRET|TOKEN|KEY|PASSWORD|API' | sed 's/=.*/=***/' | head -10
echo "  (values masked — showing names only)"

section "Snapshot / build status indicators"
echo "  Last snapshot build log (if available):"
ls -lt /var/log/devin-build*.log 2>/dev/null | head -3 || echo "  (no build logs found — check Devin UI: Settings > Environment > Build Log)"

section "HINTS"
echo "• 'initialize' runs at snapshot build time — for deps that should be baked in"
echo "• 'setup' runs at session start — for per-session config (source secrets, start services)"
echo "• 'maintenance' runs on schedule — for keeping deps up to date"
echo "• Secrets at /run/repo_secrets/.../  .env.secrets — must be explicitly sourced"
echo "• If snapshot build failed: Devin falls back to previous snapshot (tools may be old)"
echo "• Check build log in UI: Settings > Environment > last build"
echo "• Common fix: move 'pip install X' from maintenance to initialize"
