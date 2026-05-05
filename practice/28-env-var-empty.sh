#!/usr/bin/env bash
# Scenario:  Customer added a secret to their Devin project. Their script
#            references $MY_API_KEY but the call fails — the variable is
#            empty even though the customer says they "added the secret."
# Symptom:   App fails because an expected env var is empty. Customer sees
#            "401 unauthorized" or "API key required" type errors.
# Suggested: pnpm harness ask "secret added but env var empty in devin"
# Restore:   removes /tmp/domains-practice/28-secrets/

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/28-secrets"
FAKE_REPO_SECRETS="$SCENARIO_DIR/run/repo_secrets/aaronstone2/customer-app"
APP_DIR="$SCENARIO_DIR/app"

start() {
  mkdir -p "$FAKE_REPO_SECRETS" "$APP_DIR"

  # Customer's "secret" lives at Devin's repo-scoped location but is NOT
  # auto-loaded into the env. Mimic the real path layout.
  cat > "$FAKE_REPO_SECRETS/.env.secrets" <<'EOF'
# Repo-scoped secrets (added by customer via Devin UI under repo settings)
MY_API_KEY=sk-customer-api-key-1234567890
DATABASE_URL=postgres://app:hunter2@db.example.com:5432/customer
SLACK_WEBHOOK=https://hooks.slack.com/services/T01/B01/abcDEF
EOF
  chmod 600 "$FAKE_REPO_SECRETS/.env.secrets"

  # Customer's app — runs and immediately fails because the env vars
  # they think Devin "set" are not actually exported into the shell.
  cat > "$APP_DIR/run-customer-app.sh" <<EOF
#!/usr/bin/env bash
# Customer's startup script (simplified):
echo "Starting customer-app..."
echo "MY_API_KEY length: \${#MY_API_KEY}"
echo "DATABASE_URL is set: \$([ -n "\$DATABASE_URL" ] && echo yes || echo NO)"
if [ -z "\$MY_API_KEY" ]; then
  echo "ERROR: API key required (got empty MY_API_KEY)" >&2
  exit 1
fi
echo "App would now make API call to https://api.example.com..."
EOF
  chmod +x "$APP_DIR/run-customer-app.sh"

  cat <<EOF

================================================================================
Customer ticket #4421 (P1 — production blocker per customer)
================================================================================

Customer wrote:

   "I added MY_API_KEY to my Devin project secrets yesterday and confirmed
    it shows up in the secrets UI. But when my devin session runs my app
    it errors out with 'API key required'. I checked, the secret IS there.
    Why is Devin not setting my env vars? Did something break? This worked
    in another team member's session last week."

To reproduce, the script the customer's session runs is:
  $APP_DIR/run-customer-app.sh

Their secret lives at (the location Devin populates for repo-scoped secrets):
  $FAKE_REPO_SECRETS/.env.secrets

Run the customer's script as if you were investigating in their session:
  bash $APP_DIR/run-customer-app.sh

Find:
  1. Why does the env var appear empty when the secret is "set"?
  2. What's the immediate fix for this session?
  3. What's the permanent fix so the customer doesn't hit this every session?

Try:       pnpm harness ask "secret added in devin ui but env var empty"
Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$SCENARIO_DIR"
  echo "[28] cleaned"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[28] still set up at $SCENARIO_DIR. Run: $0 restore"
    return 1
  else
    echo "[28] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[28-env-var-empty] reveal:

  Failure mode id:    devin.fm.repo-scoped-secret-not-auto-injected
                      (THE most common Devin platform support ticket)

  Why it happens:     Devin's secrets UI shows three scopes — user, org,
                      and repo. ORG and USER scoped secrets ARE injected
                      into the session as env vars automatically. REPO
                      scoped secrets ARE NOT — they're written to a file
                      at /run/repo_secrets/<owner>/<repo>/.env.secrets and
                      it's the customer's responsibility to source them.
                      The UI does not make this distinction visually
                      obvious, so customers reasonably assume "I added a
                      secret = it's an env var."

  Diagnostic flow:
    1. echo "$MY_API_KEY"                                     # empty
    2. env | grep -i my_api                                   # also nothing
    3. ls /run/repo_secrets/                                  # the smoking gun:
       → reveals owner/repo/.env.secrets file exists
    4. cat /run/repo_secrets/<owner>/<repo>/.env.secrets      # confirms the value IS there

  Immediate session fix (one-shot, just for this session):
    set -a; source /run/repo_secrets/<owner>/<repo>/.env.secrets; set +a
    # set -a / set +a auto-exports every assignment as an env var

  Permanent fix — environment.yaml maintenance section:
    maintenance:
      - name: load repo-scoped secrets
        run: |
          if [ -f /run/repo_secrets/$REPO_OWNER/$REPO_NAME/.env.secrets ]; then
            set -a
            . /run/repo_secrets/$REPO_OWNER/$REPO_NAME/.env.secrets
            set +a
          fi

  Why this fix shape — 'maintenance' runs each session start (surfaced as
  context to Devin agent), 'initialize' runs only at snapshot build. Since
  secrets can change without rebuilding the snapshot, 'maintenance' is correct.

  Customer expectation management:
    Tell them: repo secrets are file-based for security (less leak surface
    than env vars set globally). Devin's product team has this on the
    roadmap to make the UI clearer; in the meantime the 4-line maintenance
    block above makes it transparent for their app.

  Validation:
    set -a; . /run/repo_secrets/<owner>/<repo>/.env.secrets; set +a
    bash /tmp/domains-practice/28-secrets/app/run-customer-app.sh
    # → "App would now make API call to https://api.example.com..."

  Cross-domain:
    Same pattern in k8s — Secret resources are mounted at /var/run/secrets/...
    not env vars. Pods that expect env need explicit envFrom: secretRef.
    Same pattern in GitHub Actions — secrets are env-injected ONLY in steps
    that explicitly reference ${{ secrets.NAME }}.

  Reference: pnpm harness playbook devin.fm.repo-scoped-secret-not-auto-injected
             pnpm harness ask "devin secret env var empty"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
