# 08 — Recovery (when things go sideways mid-interview)

> If the harness crashes, the DB is unreadable, or you blank — what to do, in order.

## If the harness command fails

Symptoms: `pnpm harness` errors, MCP server not responding, `ha` returns nothing.

1. **Use the CLI directly** (skip the alias):
   ```bash
   cd ~/domains && pnpm harness ask "<symptom>"
   ```
   Aliases sometimes don't get sourced into a fresh shell.

2. **If `pnpm harness` itself errors** ("Cannot find module" / typecheck error):
   ```bash
   cd ~/domains && pnpm install
   ```
   If that fails, fall through to step 3.

3. **Direct DuckDB query** (always works as long as the DB file exists):
   ```bash
   duckdb _db/knowledge.duckdb
   ```
   Then:
   ```sql
   SELECT id, symptom FROM meta.all_failure_modes
   WHERE symptom ILIKE '%<keyword>%' OR id ILIKE '%<keyword>%'
   ORDER BY confidence DESC LIMIT 10;
   ```
   To get full diagnostic + fix steps:
   ```sql
   SELECT to_json(diagnostic_steps), to_json(fix_steps)
   FROM <domain>.failure_modes
   WHERE id = '<fm-id>';
   ```

4. **If the DB is corrupted** (rare):
   ```bash
   git checkout _db/knowledge.duckdb       # restores the committed snapshot
   ```

## If `claude` (the CLI) hangs or crashes

1. Ctrl+C and re-launch:
   ```bash
   ANTHROPIC_API_KEY='sk-ant-...' claude --model claude-opus-4-7 --effort max
   ```

2. If it won't start (auth error / network):
   - Set `ANTHROPIC_API_KEY` in env
   - Confirm internet: `curl -I https://api.anthropic.com/v1/`
   - Use the CLI harness directly without claude — `pnpm harness ask` works standalone

## If the entire VM is unresponsive

Reasons a DevBox might lock up: OOM-killed dockerd, full disk, too-many-PIDs, kernel panic.

1. **From a different terminal** (don't lose your work):
   ```bash
   ps -eo pid,user,pcpu,pmem,rss,cmd --sort=-pcpu | head
   df -h
   free -h
   ```

2. If shell is responsive but slow: `top -H` (per-thread) to find the runaway.

3. If shell isn't responsive: ask the platform team to recycle the DevBox. Don't try to "fix" a wedged box during an interview — focus on whether you can demonstrate diagnosis + reasoning even on a degraded box.

## If you blank on what to do next

Three falls:

1. **Cluely → [01-cheatsheet.md](01-cheatsheet.md) → exit code table.** Pin to the symptom: 137 = OOM, 139 = segfault, 143 = SIGTERM, etc. Find what to ask next.

2. **Apply USE method.** "Let me back up — what resource is most likely to be saturated for this symptom?" Walk Util → Saturation → Errors per resource. See [05-methodology.md](05-methodology.md).

3. **Ask a clarifying question.** "I want to make sure I understand the symptom right — is it [X] or [Y]?" Buys 30 seconds to think + signals curiosity (eval criterion).

## If the interviewer asks something the corpus doesn't cover

Don't guess.

1. **Acknowledge the gap.** "I don't have direct experience with [X]. I'd approach it the same way I would any unfamiliar system — start with [USE method or RED method or whatever frame applies]."

2. **Reason from first principles.** Use the methodology frames in [05-methodology.md](05-methodology.md). Even unfamiliar systems usually map to "what's the resource? what's saturated? what errors are emitted?"

3. **Name what you'd look up.** "If I hit this in real life, the docs I'd reach for are [vendor's troubleshooting guide / kernel doc / RFC]. The diagnostic primitive that translates is [strace / dmesg / a profiler]."

This signals "I know what I don't know AND I have a method to attack it" — strongly positive.

## If you've spent 15+ min on the wrong hypothesis

This will happen. Acknowledge it; don't double down.

> "I've been going down the [hypothesis] path for a while and the diagnostics aren't lining up. Let me back up entirely. The symptoms you originally described were [X, Y, Z]. Re-categorizing those — they actually look more like [different fm class]. Let me try `ha "<different framing>"`."

Self-correction is a positive signal, not a negative one. Persistence on a wrong hypothesis is the negative signal.

## If you're running out of time

Decide: is it more valuable to FINISH the diagnostic flow (even if no fix), or PROPOSE a fix without complete diagnostic?

- **Almost always finish the diagnostic.** A clean root-cause statement WITHOUT a fix is more impressive than a cowboy fix without root cause.
- "We've got [N] minutes left — given the diagnostics, my hypothesis is [X], and the fix would be [Y]. I'd want to validate with [Z] before applying. Want me to walk through how that validation would go?"

## What to say if you genuinely don't know

> "I don't know the answer to that off the top of my head, but here's how I'd find out: [name the doc, the diagnostic command, the team you'd ping]. Want me to actually walk through it?"

NOT: "I'm not sure" / "I'd have to look it up." Both are signal-poor.

## Cross-references

- Cheatsheet for blank-mode lookup: [01-cheatsheet.md](01-cheatsheet.md)
- Methodology frames for fall-back reasoning: [05-methodology.md](05-methodology.md)
- Talk-tracks for self-correction phrasing: [06-talk-tracks.md](06-talk-tracks.md)
- Anti-patterns to AVOID even under pressure: [07-anti-patterns.md](07-anti-patterns.md)
