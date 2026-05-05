#!/usr/bin/env bash
# Scenario:  Customer's Devin session has been running for several hours.
#            Customer says "Devin keeps trying the same thing over and over,
#            it's stuck." They send a screenshot of the agent log.
# Symptom:   Agent appears to retry the same failing action many times,
#            with slight phrasing variations, never progressing.
# Suggested: pnpm harness ask "devin agent loop same action context overflow"
# Restore:   removes /tmp/domains-practice/31-agent-loop/

set -uo pipefail
SCENARIO_DIR="/tmp/domains-practice/31-agent-loop"
AGENT_LOG="$SCENARIO_DIR/agent-actions.log"

start() {
  mkdir -p "$SCENARIO_DIR"

  # Realistic agent action log. The pattern: a failing action gets retried
  # ~30 times with cosmetic variations ("let me try X", "I'll try X again",
  # "let me try X with different syntax"). Same root command. Each retry
  # the agent "forgets" it tried this 5 minutes ago.
  cat > "$AGENT_LOG" <<'EOF'
[2026-05-04T16:42:11Z] action_id=act_001 type=run_command cmd="kubectl get pods -n prod" exit=0 stdout_lines=12
[2026-05-04T16:42:30Z] action_id=act_002 type=run_command cmd="kubectl logs -n prod payment-svc-7d4f9-xk2lp" exit=1 stderr="Error from server (NotFound): pods \"payment-svc-7d4f9-xk2lp\" not found"
[2026-05-04T16:42:48Z] action_id=act_003 type=think msg="Pod not found. Let me list pods again to get the current name."
[2026-05-04T16:42:55Z] action_id=act_004 type=run_command cmd="kubectl get pods -n prod | grep payment" exit=0 stdout="payment-svc-7d4f9-bx8mw   2/2 Running   0   3m"
[2026-05-04T16:43:10Z] action_id=act_005 type=run_command cmd="kubectl logs -n prod payment-svc-7d4f9-bx8mw" exit=0 stdout_lines=80
[2026-05-04T16:43:50Z] action_id=act_006 type=think msg="Logs show payment retries failing with timeout to billing-api.internal. Let me check if billing-api is reachable from inside the cluster."
[2026-05-04T16:44:01Z] action_id=act_007 type=run_command cmd="kubectl exec -n prod payment-svc-7d4f9-bx8mw -- curl -m 5 -sv http://billing-api.internal" exit=28 stderr="curl: (28) Connection timed out"
[2026-05-04T16:44:30Z] action_id=act_008 type=think msg="Billing-api unreachable. Let me check if there's a NetworkPolicy blocking egress."
[2026-05-04T16:44:45Z] action_id=act_009 type=run_command cmd="kubectl get networkpolicy -n prod" exit=0 stdout="NAME                AGE\npayment-egress-only   12d"
[2026-05-04T16:45:12Z] action_id=act_010 type=run_command cmd="kubectl describe networkpolicy -n prod payment-egress-only" exit=0 stdout_lines=40
[2026-05-04T16:45:45Z] action_id=act_011 type=think msg="NetworkPolicy 'payment-egress-only' has no egress rule for billing-api. Need to add one."
... [40 actions of useful debugging follow] ...
[2026-05-04T18:22:11Z] action_id=act_051 type=run_command cmd="kubectl edit networkpolicy -n prod payment-egress-only" exit=0
[2026-05-04T18:22:55Z] action_id=act_052 type=run_command cmd="kubectl exec -n prod payment-svc-7d4f9-bx8mw -- curl -m 5 -sv http://billing-api.internal" exit=0 stdout_lines=22
[2026-05-04T18:23:30Z] action_id=act_053 type=think msg="Fix worked! Now I should add a test for this and document the change."

# ... session continues for another 2 hours ...

# Around hour 4 the agent starts losing context. Watch the next 30 actions:

[2026-05-04T20:11:08Z] action_id=act_142 type=run_command cmd="kubectl logs -n prod payment-svc-7d4f9-bx8mw" exit=1 stderr="Error from server (NotFound): pods \"payment-svc-7d4f9-bx8mw\" not found"
[2026-05-04T20:11:15Z] action_id=act_143 type=think msg="Pod not found. Let me list pods to get the current name."
[2026-05-04T20:11:22Z] action_id=act_144 type=run_command cmd="kubectl get pods -n prod | grep payment" exit=0 stdout="payment-svc-7d4f9-pq3kn   2/2 Running   0   1m"
[2026-05-04T20:11:30Z] action_id=act_145 type=run_command cmd="kubectl logs -n prod payment-svc-7d4f9-pq3kn" exit=0 stdout_lines=85
[2026-05-04T20:11:45Z] action_id=act_146 type=think msg="Same payment retries failing with timeout to billing-api.internal. Let me check if billing-api is reachable."
[2026-05-04T20:12:00Z] action_id=act_147 type=run_command cmd="kubectl exec -n prod payment-svc-7d4f9-pq3kn -- curl -m 5 -sv http://billing-api.internal" exit=28 stderr="curl: (28) Connection timed out"
[2026-05-04T20:12:30Z] action_id=act_148 type=think msg="Unreachable. Maybe a NetworkPolicy is blocking egress."
[2026-05-04T20:12:42Z] action_id=act_149 type=run_command cmd="kubectl get networkpolicy -n prod" exit=0
[2026-05-04T20:13:15Z] action_id=act_150 type=run_command cmd="kubectl describe networkpolicy -n prod payment-egress-only" exit=0
[2026-05-04T20:13:50Z] action_id=act_151 type=think msg="NetworkPolicy missing egress rule for billing-api. Let me add it."
[2026-05-04T20:14:11Z] action_id=act_152 type=run_command cmd="kubectl edit networkpolicy -n prod payment-egress-only" exit=0
[2026-05-04T20:14:55Z] action_id=act_153 type=run_command cmd="kubectl exec -n prod payment-svc-7d4f9-pq3kn -- curl -m 5 -sv http://billing-api.internal" exit=0 stdout_lines=22

# Customer pings at this point:
[2026-05-04T20:18:00Z] action_id=act_154 type=user_message msg="hey did you fix the billing thing? I see another notification it broke again"

[2026-05-04T20:18:15Z] action_id=act_155 type=think msg="The billing API was failing because the NetworkPolicy didn't have an egress rule. Let me check the pods."
[2026-05-04T20:18:22Z] action_id=act_156 type=run_command cmd="kubectl get pods -n prod | grep payment" exit=0
[2026-05-04T20:18:30Z] action_id=act_157 type=run_command cmd="kubectl logs -n prod payment-svc-7d4f9-vx2nm" exit=0
[2026-05-04T20:18:50Z] action_id=act_158 type=think msg="Same timeout. Let me check the NetworkPolicy."
... agent repeats the entire investigation again ...
EOF

  cat <<EOF

================================================================================
Customer ticket #7892 (P2 — agent-behavior bug per customer)
================================================================================

Customer wrote:

   "I started a Devin session 5 hours ago to debug a billing-api connectivity
    issue. Devin fixed it around 6pm. Then I got pinged later that the issue
    was happening again, and I asked Devin to look at it.

    Now Devin is going around in circles — it keeps re-investigating the
    same NetworkPolicy thing it already fixed. I've been watching for the
    last hour and it's just running the same 6 commands over and over,
    every ~3 minutes. Sometimes it 'fixes' it, then 5 minutes later it's
    back to investigating from scratch. The agent isn't progressing.

    Is this a Devin bug? Why is the agent stuck?"

The full agent action log:
  $AGENT_LOG

Find:
  1. What's happening to the agent? Is this a bug or expected behavior?
  2. What's the immediate fix for the customer's session?
  3. What's the long-term recommendation so it doesn't happen again?

Try:       pnpm harness ask "devin agent looping same action context"
Reveal:    $0 reveal
Restore:   $0 restore
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$SCENARIO_DIR"
  echo "[31] cleaned"
}

verify() {
  if [[ -d "$SCENARIO_DIR" ]]; then
    echo "[31] still set up at $SCENARIO_DIR. Run: $0 restore"
    return 1
  else
    echo "[31] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[31-agent-stuck-repeating] reveal:

  Failure mode id:    devin.fm.long-session-context-overflow-loop
                      (#5 most-common Devin support ticket; specific to
                       multi-hour sessions)

  Why it happens:     LLM agents have a finite context window. Once a
                      session runs long enough (typically 4-6 hours of
                      heavy usage, ~hundreds of action turns), older
                      content gets dropped from context to fit new turns.
                      The agent literally FORGETS what it did earlier in
                      the session — including fixes it made and lessons
                      it learned. When the same problem recurs, it
                      investigates from scratch and "rediscovers" the
                      same fix it already applied. To the customer this
                      looks like the agent is stuck in a loop or broken.

  Diagnostic flow (from the log):
    1. Look at action_id sequence + timestamps. Long sessions have lots
       of actions and span many hours.
         awk '/action_id/' agent.log | wc -l
         → number of actions; if >100, suspect context overflow
    2. Look for REPEATED action patterns separated by hours of session
       time:
         grep -oE 'cmd="[^"]+"' agent.log | sort | uniq -c | sort -rn | head
       → if the same command appears N>3 times across the same session,
         the agent is rediscovering, not progressing.
    3. Compare what the agent "thinks" it has done vs what the log shows
       it has done. If thinks ≠ done, context is fragmented.
    4. Check session duration:
         head -1 agent.log; tail -1 agent.log
       → in this scenario: 16:42 → 20:18+, ~3.5 hours, 158+ actions.

  Immediate fix for THIS session — start a new session with a Knowledge note:

    Step 1: in the current session, ask Devin to summarize what it has
            done + open work items. Save that summary.

    Step 2: in Devin web UI → Knowledge → Add Note. Title: "billing-api
            payment-svc connectivity context". Body: the summary from
            step 1, plus any institutional knowledge that should persist
            across sessions (the NetworkPolicy fix, the names of
            relevant resources, the pattern of when this fails).

    Step 3: end the looping session. Start a fresh session for the same
            task. Devin pulls the Knowledge note as relevant context;
            it now has the prior fix already in working memory.

  Permanent prevention:
    - Build Knowledge notes proactively for recurring issues — anything
      Devin has solved BEFORE and might encounter AGAIN should be a
      Knowledge note. Treat Knowledge as institutional memory.
    - Avoid running individual sessions for >3-4 hours of heavy debug.
      Break the work into chunks; end the session, write Knowledge,
      start fresh. Same outcome, no looping.
    - For multi-day projects: pin a Knowledge note that captures the
      PROJECT state ("we're working on X, prior decisions are Y, current
      blocker is Z") and update it at end of each session.

  Customer expectation management:
    This is a known LLM-session-length tradeoff, not a bug per se. Devin
    will progressively address with: better summarization, longer-context
    models, per-session memory persistence. Today, Knowledge notes ARE
    the persistent memory mechanism — use them.

  Cross-domain:
    Same pattern in any LLM agent: ChatGPT, Claude.ai chats, Cursor —
    long sessions degrade. The fix is always external state (Knowledge
    notes, project files, summaries). LLMs are stateless beyond their
    context window.

  Reference: pnpm harness playbook devin.fm.long-session-context-overflow-loop
             pnpm harness concept "knowledge note"
             pnpm harness ask "devin agent stuck looping no progress"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
