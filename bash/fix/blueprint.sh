#!/usr/bin/env bash
# fix/blueprint.sh — fix common Devin environment.yaml / blueprint issues
#
# Default: dry-run (prints commands). Add --apply to execute.
#
# Usage:   fix/blueprint.sh <action> [environment.yaml] [--apply]
# Actions: fix-yaml         — fix tabs, trailing spaces, common YAML issues
#          move-to-init     — move a setup command to initialize (bake into snapshot)
#          source-secrets   — add secret sourcing to setup section
#          validate         — full validation against known schema
# Example: fix/blueprint.sh fix-yaml environment.yaml --apply
#          fix/blueprint.sh source-secrets --apply

set +e

APPLY=false
ARGS=()
for a in "$@"; do
  case "$a" in --apply|-y) APPLY=true ;; *) ARGS+=("$a") ;; esac
done
set -- "${ARGS[@]}"

action="$1"; f="${2:-environment.yaml}"
section() { echo ""; echo "=== $* ==="; }
run() { if $APPLY; then echo "[apply]   $*"; eval "$@"; else echo "[dry-run] $*"; fi; }

if [ "$action" = "-h" ] || [ "$action" = "--help" ] || [ -z "$action" ]; then
  sed -n '2,13p' "$0" | sed 's/^# *//'
  exit 0
fi

# Auto-detect
for candidate in "$f" environment.yaml environment.yml .devin/environment.yaml; do
  [ -f "$candidate" ] && f="$candidate" && break
done

case "$action" in
  fix-yaml)
    section "Fixing YAML issues in: $f"
    [ ! -f "$f" ] && { echo "  File not found: $f" >&2; exit 2; }
    run "sed -i 's/\t/  /g' '$f'"
    echo "  → Replaced tabs with spaces"
    run "sed -i 's/[[:space:]]*$//' '$f'"
    echo "  → Removed trailing whitespace"
    echo "  Validating..."
    python3 -c "import yaml; yaml.safe_load(open('$f')); print('  ✓ Valid YAML')" 2>/dev/null || echo "  ✗ Still invalid — check manually"
    ;;
  move-to-init)
    section "MANUAL FIX: Move command from setup/maintenance to initialize"
    echo "  In $f, change:"
    echo ""
    echo "    setup:"
    echo "      - pip install heavy-package    # ← runs every session start (slow)"
    echo ""
    echo "  To:"
    echo ""
    echo "    initialize:"
    echo "      - pip install heavy-package    # ← runs at snapshot build (baked in)"
    echo ""
    echo "  Then trigger a new snapshot build in Devin UI."
    ;;
  source-secrets)
    section "Add secret sourcing to setup section"
    echo "  Add this to your setup: section in $f:"
    echo ""
    echo "    setup:"
    echo "      - source /run/repo_secrets/ORG/REPO/.env.secrets"
    echo "      - # ... rest of your setup commands"
    echo ""
    echo "  Available secrets:"
    find /run/repo_secrets -name '.env.secrets' 2>/dev/null | while read -r sf; do
      echo "    $sf ($(grep -c '=' "$sf" 2>/dev/null) vars)"
    done
    [ ! -d /run/repo_secrets ] && echo "    (not in a DevBox — /run/repo_secrets doesn't exist)"
    ;;
  validate)
    section "Validating: $f"
    [ ! -f "$f" ] && { echo "  File not found: $f" >&2; exit 2; }
    python3 -c "
import yaml, sys
with open('$f') as fh:
  doc = yaml.safe_load(fh)

if not doc:
  print('  ✗ File is empty')
  sys.exit(1)

valid_sections = {'initialize','setup','maintenance','packages','secrets','repos','env','environment','build','pre_install','post_install','cron'}
for key in doc:
  if key in valid_sections:
    print(f'  ✓ {key}: {type(doc[key]).__name__}')
  else:
    print(f'  ? {key}: unknown section (check docs)')

# Check for common mistakes
if 'setup' in doc and isinstance(doc['setup'], list):
  for cmd in doc['setup']:
    if isinstance(cmd, str):
      if 'pip install' in cmd and 'initialize' not in str(doc.get('initialize','')):
        print(f'  WARN: \"{cmd}\" in setup — consider moving to initialize for faster session starts')
      if 'npm install' in cmd or 'yarn install' in cmd:
        print(f'  WARN: \"{cmd}\" in setup — consider moving to initialize')
print('  ✓ Validation complete')
" 2>/dev/null || echo "  ✗ Validation failed"
    ;;
  *)
    echo "Unknown action: $action" >&2
    echo "Actions: fix-yaml, move-to-init, source-secrets, validate" >&2
    exit 2
    ;;
esac

$APPLY || echo "(dry-run; pass --apply to execute)"
