# Interview-day playbook — the actual sequence

Open this file in a side window at the start of the screen-share. Top-to-bottom is the literal sequence to run.

## T-5 minutes (before they join)

1. **Install on the VM** (one paste-able line — use this exact form):
   ```bash
   git clone https://github.com/aaronstone2/Domains.git ~/domains && cd ~/domains && bash bootstrap.sh --launch
   ```
   - **Don't** add `\` line continuations. The `bash` form works without `chmod +x`.
   - Pass `--anthropic-key='sk-ant-...'` if `ANTHROPIC_API_KEY` isn't already in the env.
2. **Confirm** the bootstrap printed two `✓ verify` lines:
   - `✓ harness verified — pnpm harness ask returns the OOMKilled playbook`
   - `✓ MCP server boots — claude code can call ask/lookup/playbook as native tools`
3. **Open the cheatsheet** in a side terminal: `cheat` (alias for `${PAGER:-less} domains/_shared/rehearsal/CHEATSHEET.md`)

If anything's broken at this point: `bash ~/domains/bootstrap.sh --no-claude` re-runs the install (idempotent — apt + pnpm steps skip what's already there).

## T-0 (interviewer joins)

### Opener (literally read out loud, ~20 sec):

> "Before I touch anything I want to make sure I understand the problem. Could you tell me what you're seeing — the literal symptom, when it started, and whether it's user-impacting now or just an alert? While you describe it I'll have my support harness open — it's a corpus I built of every Docker / Linux / k8s / Devin failure mode I've documented, and it gives me a structured runbook for almost any common symptom. I'll narrate as I go so you can see my reasoning."

This single paragraph hits **4 of 5 eval criteria** (curiosity, communication, clarity, "the why" of using a tool).

### When they describe a symptom

In Claude (already launched), type:

```
ask the harness what's likely if [their description]
```

Claude will call the `ask` MCP tool. **You read the TALK TRACK section back to the interviewer verbatim** — that's the script for hitting curiosity + diagnose + trade-off + fix.

Or in the terminal:

```bash
ha "<their literal words>"
```

(`ha` is the alias for `pnpm harness ask`.)

### The DIAGNOSE → FIX flow

For each diagnostic step the harness prints:
1. **Don't run it yet.** Say: "I'd start by [paraphrase the action]. The expected outcome is [paraphrase expect:]. Want me to run that?"
2. They say yes → run it. Read the actual output back. **Always** check the result against `expect:` and say "that confirms / contradicts the [class] hypothesis."
3. If it confirms → propose the FIX step. Same pattern: paraphrase the fix, mention the validation step + rollback. Get approval before running.

**Never** run a fix without (a) confirming with a diagnostic, (b) stating the validation, (c) stating the rollback.

### When the harness doesn't have a perfect match

```
harness lookup "<their description>"
```

Returns top 8 candidates. Read the symptoms aloud, ask "does any of these match what you're seeing?" — that's a clarifying question.

If the user picks one: `pnpm harness playbook <fm-id>` opens it.

If none match: fall back to **methodology**. `harness ask "USE method"` or `harness ask "RED method"` — talk through the framework, ask USE/RED questions to narrow.

## Anti-patterns (do not do)

- **Don't** dump 5 commands into the shell at once. One probe → result → one recommendation.
- **Don't** run a `fix_steps` action without first running the matching `diagnostic_steps` to confirm.
- **Don't** silently disagree with what the harness recommends. If you doubt a step, say so out loud: "the harness suggests X, but I'm hesitant because Y — let me verify with [different command] first."
- **Don't** apologize for using a tool. The interviewer KNOWS external tools are allowed. Owning a custom corpus IS the differentiator.
- **Don't** read the harness output verbatim if it's wrong for the situation. The TALK TRACK is a starting frame, not a script.

## Soft-skills questions

If the interviewer pivots to "tell me about a postmortem you ran":

```bash
ha "postmortem became blame"          # methodology.fm.retro-becomes-trial
ha "5 whys human error"               # methodology fm
ha "on-call burnout"                  # methodology fm
```

Methodology domain has 28 fully-deepened scenarios that are answers to soft-skill questions, not just technical ones.

## End-of-interview

If you ran a `capture` bundle, `pnpm harness capture <bundle> --output snapshot-$(date +%H%M).md` saves the diagnostic snapshot. Mention to the interviewer that you'd hand this off as the artifact for an actual ticket.

## What the harness will NOT do

- Hallucinate. Every claim cites a `source_id` resolvable to an official URL.
- Run destructive commands without a `validate:` and `rollback:`.
- Silently fail. If `ask` doesn't find a match it falls back to BM25 doc search and tells you so.

## If the harness CRASHES mid-interview

1. The CLI fallback always works: `pnpm harness ask "..."` directly in the shell.
2. If even pnpm is broken: `duckdb _db/knowledge.duckdb` opens a SQL prompt. `SELECT id, symptom FROM meta.all_failure_modes WHERE symptom ILIKE '%<keyword>%' LIMIT 5;` always works.
3. If the DB is corrupted: `git checkout _db/knowledge.duckdb` restores from the committed snapshot.
4. Last resort: open `domains/_shared/rehearsal/CHEATSHEET.md` directly. The symptom→fm tables there cover the top 40 scenarios from memory.
