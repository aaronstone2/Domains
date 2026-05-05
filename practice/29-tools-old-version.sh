#!/usr/bin/env bash
# Scenario:  Customer added a tool to their environment.yaml initialize section
#            and pushed. Their next session still doesn't have the tool — or
#            has the OLD version. They insist they updated it.
# Symptom:   "I added X to my environment but it's not there." Tools are
#            missing or wrong version. Customer is confused/frustrated.
# Suggested: pnpm harness ask "devin snapshot fell back silently old version"
# Restore:   removes /tmp/domains-practice/29-snapshot/

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/29-snapshot"
SNAPSHOT_LOG="$SCENARIO_DIR/snapshot-build.log"
ENV_YAML="$SCENARIO_DIR/environment.yaml"

start() {
  mkdir -p "$SCENARIO_DIR"

  # Customer's environment.yaml — claims to install awscli v2 + a custom CLI.
  cat > "$ENV_YAML" <<'EOF'
# environment.yaml — last edited yesterday by customer
initialize:
  - name: install AWS CLI v2
    run: |
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
      unzip -q awscliv2.zip
      sudo ./aws/install --update

  - name: install internal company CLI
    run: |
      pip install --upgrade companycli==2.4.0
      companycli --version

  - name: install kubectl 1.30
    run: |
      KUBECTL_VER=v1.30.4
      curl -fsSLo /usr/local/bin/kubectl \
        https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl
      chmod +x /usr/local/bin/kubectl

maintenance:
  - name: log session start
    run: echo "session started at $(date)"
EOF

  # Realistic snapshot build log — shows the build SECRETLY failed but
  # the system fell back to the previous snapshot without surfacing it
  # prominently to the customer. The relevant signal is buried.
  cat > "$SNAPSHOT_LOG" <<'EOF'
[2026-05-04T14:22:01Z] snapshot.build.start build_id=blueprint-abc123 trigger=git-push
[2026-05-04T14:22:03Z] snapshot.clone.repo branch=main commit=a3f912e
[2026-05-04T14:22:05Z] snapshot.initialize.start steps=3
[2026-05-04T14:22:05Z] snapshot.initialize.step name="install AWS CLI v2" status=running
[2026-05-04T14:23:18Z] snapshot.initialize.step name="install AWS CLI v2" status=success duration=73s
[2026-05-04T14:23:18Z] snapshot.initialize.step name="install internal company CLI" status=running
[2026-05-04T14:23:24Z] pip.install.error package=companycli==2.4.0 message="ERROR: Could not find a version that satisfies the requirement companycli==2.4.0 (from versions: 2.3.5, 2.3.6)"
[2026-05-04T14:23:24Z] snapshot.initialize.step name="install internal company CLI" status=failed exit_code=1 duration=6s
[2026-05-04T14:23:24Z] snapshot.initialize.aborted reason="step failed: install internal company CLI"
[2026-05-04T14:23:24Z] snapshot.build.failed reason="initialize step failed"
[2026-05-04T14:23:24Z] snapshot.fallback.activate reason="latest build failed, using previous successful snapshot" prev_build_id=blueprint-abc098 prev_built=2026-05-02T11:14:33Z
[2026-05-04T14:23:24Z] session.assign snapshot=blueprint-abc098
EOF

  cat <<EOF

================================================================================
Customer ticket #5113 (P2 — "Devin is broken")
================================================================================

Customer wrote:

   "I added kubectl 1.30 and our internal companycli to environment.yaml
    yesterday. I pushed to main, waited for the snapshot to build, and
    started a new session today. kubectl is still 1.27 and companycli is
    2.3.6 (old). I'm sure I pushed the changes — git log shows my commit.
    Did Devin not pick up my changes? This is blocking my team."

Their environment.yaml (the most recent version on main):
  $ENV_YAML

The build log for what happened to their snapshot:
  $SNAPSHOT_LOG

Find:
  1. Why does the customer's session NOT have their latest changes?
  2. What's the immediate workaround for their session?
  3. What's the permanent fix so the snapshot actually builds?

Try:       pnpm harness ask "devin snapshot wrong version after push"
Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$SCENARIO_DIR"
  echo "[29] cleaned"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[29] still set up at $SCENARIO_DIR. Run: $0 restore"
    return 1
  else
    echo "[29] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[29-tools-old-version] reveal:

  Failure mode id:    devin.fm.snapshot-fallback-after-build-failure
                      (top-3 most-confusing Devin ticket because the failure
                       is silent from the customer's UI perspective)

  Why it happens:     Devin's snapshot system is fail-safe: if a new
                      snapshot build fails, sessions continue to use the
                      previous successful snapshot rather than handing
                      out a broken one. This is correct behavior — but
                      the UI doesn't surface "your latest build FAILED;
                      you're on snapshot from <date>" prominently. Customer
                      thinks their changes deployed; actually they're
                      running on the previous snapshot.

  Diagnostic flow:
    1. Customer says "kubectl is wrong version" — first instinct is
       to look at what they're running:
         kubectl version --client
         which kubectl
       → confirms it's NOT what they expected

    2. Check the snapshot the session is on (Devin web UI shows snapshot
       ID under the session info, or via API). Compare against the latest
       snapshot build for the project:
         devin snapshots list --project <name>

    3. The smoking gun: snapshot build LOG. Look for:
         grep -E "snapshot.build.failed|snapshot.fallback.activate" build.log
       → tells you the build failed AND that fallback activated

    4. Then look at WHY the build failed. Walk the initialize.step events
       in order:
         grep "snapshot.initialize.step" build.log
       → identify the failed step + its error message

    5. In this scenario: pip can't find companycli==2.4.0; available
       versions are 2.3.5 and 2.3.6. Customer typo'd or company hasn't
       released 2.4.0 yet to PyPI.

  Immediate workaround for THIS session (so customer can keep working):
    # Install the missing tools manually in the running session:
    KUBECTL_VER=v1.30.4
    sudo curl -fsSLo /usr/local/bin/kubectl \
      https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl
    sudo chmod +x /usr/local/bin/kubectl
    pip install companycli==2.3.6   # use available version

  Permanent fix — fix environment.yaml so the next snapshot build succeeds:
    # Option A: pin to an actually-available version
    pip install --upgrade companycli==2.3.6

    # Option B: use --pre or skip pinning if appropriate
    pip install --upgrade 'companycli>=2.3.5,<2.4'

    # Then push, wait for the new snapshot build, verify build_id changed.

  How to AVOID this in the future:
    - Add 'set -e' equivalent at top of every initialize step so failures
      are loud (most are bash, set -euo pipefail at the top).
    - Watch the snapshot build log after every environment.yaml change
      (Devin's UI shows it under "Snapshots" / "Builds").
    - Set up Slack notification on snapshot build FAILED status.

  Customer expectation management:
    Acknowledge the silent-fallback UX is poor. Ship it as feedback to
    the platform team. The fail-safe BEHAVIOR is correct (better to keep
    sessions working than to break them); the SIGNAL needs improvement.

  Validation:
    grep "snapshot.fallback.activate" /tmp/domains-practice/29-snapshot/snapshot-build.log
    grep "snapshot.initialize.step.*status=failed" /tmp/domains-practice/29-snapshot/snapshot-build.log
    # both should print evidence

  Cross-domain:
    Same pattern in Heroku (dyno fall-back to previous slug after build
    failure) and Kubernetes (Deployment rolling back if new pods crash on
    startup). The pattern: fail-safe is good, silent fail-safe is bad.

  Reference: pnpm harness playbook devin.fm.snapshot-fallback-after-build-failure
             pnpm harness ask "devin tools wrong version after pushing yaml"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
