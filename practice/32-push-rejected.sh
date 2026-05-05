#!/usr/bin/env bash
# Scenario:  Devin tried to push a fix to the customer's GitHub repo, got
#            "permission denied / push rejected." Customer says "Devin had
#            access yesterday, why not now?"
# Symptom:   git push fails. Devin's PR creation flow fails. Customer is
#            blocked because Devin can't ship the fix.
# Suggested: pnpm harness ask "devin git push permission denied"
# Restore:   removes /tmp/domains-practice/32-push/

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/32-push"
LOCAL_REPO="$SCENARIO_DIR/customer-app"
REMOTE_REPO="$SCENARIO_DIR/origin.git"
GH_APP_LOG="$SCENARIO_DIR/github-app-events.log"
PROTECTION_DUMP="$SCENARIO_DIR/branch-protection.json"

start() {
  mkdir -p "$SCENARIO_DIR"

  # Set up a real local git repo + remote that REJECTS pushes via a
  # pre-receive hook (mimicking branch protection).
  cd "$SCENARIO_DIR"
  git init --bare --quiet "$REMOTE_REPO"
  cat > "$REMOTE_REPO/hooks/pre-receive" <<'HOOK'
#!/bin/bash
# Mimics GitHub's "Require pull request before merging" branch protection.
echo "ERROR: Branch protection rule violated:" >&2
echo "  - Required status checks must pass before merging." >&2
echo "  - Pull requests required before merging to main." >&2
echo "" >&2
echo "remote: To push to this branch, open a PR." >&2
exit 1
HOOK
  chmod +x "$REMOTE_REPO/hooks/pre-receive"

  git -C "$REMOTE_REPO" symbolic-ref HEAD refs/heads/main 2>/dev/null
  git clone --quiet "$REMOTE_REPO" "$LOCAL_REPO"
  cd "$LOCAL_REPO"
  git config user.email "devin@bot.devin.ai"
  git config user.name "Devin"
  echo "# Customer App" > README.md
  git checkout -b main 2>/dev/null
  git add README.md
  git commit --quiet -m "initial commit"
  git push --quiet origin main 2>/dev/null || true   # may fail due to hook, harmless

  # Devin made a fix and tried to push:
  echo "fix: handle null user input" >> README.md
  git add README.md
  git commit --quiet -m "fix: handle null user input gracefully"

  # Github App event log Devin's session captured (mimicked):
  cat > "$GH_APP_LOG" <<'EOF'
2026-05-04T19:14:02Z github.token.fetch installation_id=12345678 status=success
2026-05-04T19:14:02Z github.token.permissions {"contents":"read","metadata":"read","pull_requests":"write"}
2026-05-04T19:14:30Z git.clone repo=customer-org/customer-app status=success
2026-05-04T19:18:12Z git.commit hash=a7c918e msg="fix: handle null user input gracefully"
2026-05-04T19:18:14Z git.push refs=main remote=origin
2026-05-04T19:18:14Z git.push.failed exit=1 stderr="ERROR: Permission denied to devin[bot]/customer-app/main\nremote: error: GH013: Repository rule violations found for refs/heads/main.\nremote: error: 7 of 7 required status checks are expected.\nremote: error: Required pull request reviews missing.\nTo github.com:customer-org/customer-app.git\n ! [remote rejected] main -> main (push declined due to repository rule violations)"
EOF

  # Branch protection state from gh CLI (what an investigator would pull):
  cat > "$PROTECTION_DUMP" <<'EOF'
{
  "url": "https://api.github.com/repos/customer-org/customer-app/branches/main/protection",
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci/build", "ci/test", "ci/lint", "ci/security-scan", "ci/typecheck", "ci/license-check", "ci/codecov"]
  },
  "enforce_admins": {"enabled": true},
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 2
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

  cat <<EOF

================================================================================
Customer ticket #8341 (P1 — blocking deploy)
================================================================================

Customer wrote:

   "Devin made a fix in our customer-app repo (saw it in the session,
    looks correct). When Devin tried to push, got 'permission denied to
    devin[bot]'. Devin had access yesterday — opened 5 PRs successfully.
    What changed? We need this fix shipped today."

Devin's session has these artifacts you can look at:

  Local repo (where Devin made the commit):  $LOCAL_REPO
  GitHub App events from Devin's session:    $GH_APP_LOG
  Branch protection on main:                 $PROTECTION_DUMP

Reproduce the failure:
  cd $LOCAL_REPO
  git push origin main

Find:
  1. Is this a permission problem (Devin's GitHub App lacks access) OR
     a branch-protection problem (push not allowed regardless of perms)?
  2. What's the SAFE workaround so the fix ships today?
  3. What's the long-term recommendation for the customer?

Try:       pnpm harness ask "devin git push rejected branch protection"
Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$SCENARIO_DIR"
  echo "[32] cleaned"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[32] still set up at $SCENARIO_DIR. Run: $0 restore"
    return 1
  else
    echo "[32] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[32-push-rejected] reveal:

  Failure mode id:    devin.fm.git-push-blocked-by-branch-protection
                      (one of the top-7 Devin support tickets; usually
                       confused with a permissions issue)

  Why it happens:     TWO distinct things look the same in the error:
                      (A) GitHub App permission missing 'contents:write'
                          → "Permission denied" hard-fail.
                      (B) Branch protection rules enabled on main →
                          even with full permissions, push to main
                          requires a PR + reviews + status checks.
                      (B) is FAR more common, especially after a customer
                      enables branch protection on a repo where Devin
                      previously could direct-push.

  Diagnostic flow — distinguish (A) vs (B):

    1. Look at the GitHub App's installed permissions:
         gh api /user/installations | jq '.installations[].permissions'
         OR check the github-app-events.log we have:
         grep "github.token.permissions" github-app-events.log
       → confirms what Devin's bot CAN do. Look for 'contents:write'.
         If it says 'contents:read' → that's case A (perms problem).

    2. Look at branch protection on the target branch:
         gh api repos/<owner>/<repo>/branches/main/protection
         OR check the dump we have:
         cat branch-protection.json
       → if restrictions are present (required_pull_request_reviews,
         required_status_checks) → case B.

    3. Look at the actual push error message — GitHub's error includes
       which check failed:
         GH013: "Repository rule violations" → case B (branch protection)
         "permission denied to <bot>" with no other context → case A

    In THIS scenario:
      - Permissions log shows "contents:write" — wait, actually shows
        "contents:read" only. Read more carefully:
        "contents":"read","metadata":"read","pull_requests":"write"
      - So Devin can READ contents and WRITE PRs but NOT write contents
        directly to refs.
      - BUT the error message also shows "Required pull request reviews
        missing" which is branch protection language.
      - Both signals point at: Devin should open a PR, NOT push direct
        to main. Devin's app is configured correctly for the PR-based
        workflow; the customer just needs to use it.

  SAFE workaround so the fix ships TODAY:

    Open a pull request from a feature branch (this is the supported
    Devin workflow when branch protection is on):
      cd $LOCAL_REPO
      git checkout -b devin/fix-null-user-input
      git push origin devin/fix-null-user-input
      gh pr create --base main \
        --title "fix: handle null user input gracefully" \
        --body "Devin session 8341. Fixes blocking issue."
      # → returns the PR URL; customer reviewers approve it; CI runs;
      #   merges normally. Same effective outcome as direct push.

  Long-term customer recommendations:

    (a) Educate the team that Devin uses PR-based workflow when branch
        protection is on. This is intentional and safer.

    (b) If they want Devin to bypass for hotfixes, they can grant the
        Devin GitHub App an 'admin' role on the repo (it gets the
        'enforce_admins: false' carve-out)... but this is BAD practice.
        Don't.

    (c) Add Devin's bot user to a CODEOWNERS group with limited paths
        so Devin's PRs auto-route to the right reviewers. Speeds up
        the review loop.

    (d) Pre-configure CI status checks Devin's PRs are expected to
        pass before merging. Then Devin can merge once green via the
        'pull_requests:write' permission it already has.

  How to distinguish if it WERE case A (real perm problem):

    - GH App permissions don't include the relevant write scope
    - Error says "Resource not accessible by integration" (different
      from branch-protection error)
    - Customer needs to update the GitHub App installation:
        github.com/settings/installations/<id> → repository access +
        permissions → enable contents:write.

  Validation:
    cd $LOCAL_REPO
    git checkout -b devin/test-pr
    git push origin devin/test-pr   # branch push works; only main is protected
    # → succeeds; PR can then be opened; merge happens through GitHub UI.

  Cross-domain:
    Same pattern in any system with two layers of authz: ALL the
    permissions in the world don't override resource-level rules
    (k8s RBAC vs admission webhooks; AWS IAM vs SCP; database GRANT
    vs row-level security).

  Reference: pnpm harness playbook devin.fm.git-push-blocked-by-branch-protection
             pnpm harness ask "devin permission denied push to main"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
