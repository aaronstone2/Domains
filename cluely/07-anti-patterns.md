# 07 — Anti-patterns (what NOT to do or say)

> Things that nuke an otherwise good interview. These are pattern-matched against real SE interview feedback.

## Diagnostic anti-patterns

❌ **Run a fix step before running the matching diagnostic.**
"Let me just bump the memory limit and see if it helps" → doesn't tell you WHY it was OOMing. The fix might mask a real leak.

✅ Always: diagnose → hypothesis → confirm → fix.

❌ **Dump 5 commands into the shell at once.**
"Let me check `docker ps && docker logs && docker inspect && dmesg && journalctl`" — interviewer can't follow your reasoning + you can't react to one's output before the next runs.

✅ One probe → read result → state finding → next probe.

❌ **Run a fix without saying validation + rollback FIRST.**
Gives the impression you're cowboy-debugging. Even if you'd rollback in your head, SAY it out loud.

✅ "Before I apply: validation will be [X], rollback if it doesn't take is [Y]."

❌ **Disable security controls as a "fix".**
- `setenforce 0` → "I disabled SELinux" is a 10-second fix that removes the security control. Permanent regression.
- `--security-opt apparmor=unconfined` → same in containers.
- `chmod 777` → "I made it world-writable" — wrong layer, lazy fix, leaks privilege.
- `--insecure` / `-k` for cert errors → bypasses TLS verification entirely. Use for one-off diagnostic, NEVER as a fix.

✅ Narrow the policy/scope, don't disable it.

❌ **`rm -rf` to "free space" without identifying the offender.**
- `rm -rf /tmp/*` blanket → you may delete logs the team needs.
- `docker system prune -a -f --volumes` → nukes images + volumes including ones with unbacked-up data.

✅ Find the offender (`du -sh /tmp/* | sort -h | tail`); rm specific files only.

❌ **Restart the service before reading what failed.**
"Let me restart the daemon and see if it comes back" → you destroyed the evidence + you don't know if the restart actually fixes anything or if it'll fail again in 2 minutes.

✅ Read logs/state FIRST, restart only after you have a hypothesis.

## Communication anti-patterns

❌ **Apologize for using a tool.**
"Sorry, let me check my notes..." — Cognition explicitly said external tools are allowed. Owning a custom corpus IS the differentiator. Don't downplay it.

✅ "I'll check my support harness — that's the corpus I built for this kind of issue."

❌ **Silent debugging.**
Long pauses where you're typing into the harness but not narrating leave the interviewer no signal of your thinking. Eval criteria include "clarity of thought" and "communication" — both require you to TALK.

✅ Always narrate: "I'm pulling up the playbook for this... it suggests three diagnostic paths... I'll start with the cheapest one because..."

❌ **Pretend you don't have an opinion when asked one.**
"I'd need to think about it" / "It depends" — vague. Take a position; defend it; acknowledge the trade-off.

✅ "I'd do A, because [reason]. The trade-off vs B is [property]. If [condition] I'd switch to B."

❌ **Read the harness output verbatim when it's wrong for the situation.**
The TALK TRACK is a starting frame, not a script. If the symptom doesn't quite match, name the mismatch out loud.

✅ "The harness suggests this is a cgroup OOM — but the symptom you described doesn't include exit 137. Let me query a different angle."

❌ **Skip the clarifying question.**
Going straight from symptom to action looks impulsive. Even ONE clarifying question signals curiosity.

✅ At minimum: "When did this start? Is it user-impacting now or just an alert?" — even if you know the answer, asking shows the eval criterion.

❌ **Forget the cite.**
Citing the source URL with every recommendation is what differentiates "fixing" from "Support Engineering." The harness output ALREADY has citations — read them out loud.

✅ "This is documented at [URL from harness CITATIONS section]."

## Pacing anti-patterns

❌ **Spending 15 minutes on the wrong hypothesis.**
If your first diagnostic doesn't confirm your hypothesis within 2-3 commands, BACK UP. Don't double down.

✅ "OK, that didn't show what I expected. Let me back up — `harness ask` with a different framing of the symptom."

❌ **Trying to fix in real-time without confirming with the user.**
Running `kubectl delete` / `docker rm -f` without a "want me to do this?" — interviewer has no chance to redirect.

✅ Always pause before destructive actions. "Want me to apply this fix? Validation is X."

❌ **Optimizing the wrong layer.**
If the problem is at layer 7 (app), don't spend 10 minutes on layer 4 (TCP). Use the harness's MATCH section to confirm you're at the right layer before drilling.

✅ "The harness placed this in [layer]. I'll confirm at that layer first; if I rule it out I'll go up/down."

## When the interviewer is testing patience

Sometimes they'll INTRODUCE a red herring or wait silently to see if you'll fill the silence with bad guesses.

✅ Don't fill the silence with speculation. Re-state where you are: "OK, current state: I've confirmed X via Y. My next hypothesis is Z, which I'll test with [command]." Then PAUSE. Wait for them.

## Cross-references

- Methodology you SHOULD apply: [05-methodology.md](05-methodology.md)
- Talk tracks that AVOID these patterns: [06-talk-tracks.md](06-talk-tracks.md)
- If you fall into a pattern and the interview goes off rails: [08-recovery.md](08-recovery.md)
