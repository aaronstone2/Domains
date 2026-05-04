# 00 — Context: who, what, eval criteria

> Open this first when the screen-share starts. 30-second read. Sets the frame.

## Who I am

Aaron Stone — interviewing for **AI Support Engineer at Cognition** (makers of Devin.ai). This is the **technical panel round**. Recruiter screen ✓ → hiring manager ✓ → this round.

## The format

- **Live screen-share on a Linux/Docker VM**, likely a real Devin DevBox with a planted issue.
- **External tools allowed**: Google, AI assistants, custom corpora. The harness + Claude Code + this Cluely bundle are all on-table.
- Duration: ~45-60 min.

## What they're evaluating (Cognition's stated criteria, verbatim)

| Criterion | What it looks like in practice |
|---|---|
| **Efficiency** | Find root cause fast; don't run 5 commands when 1 will do |
| **Clarity of thought** | Narrate hypothesis → test → result → next-hypothesis |
| **Communication** | Explain WHY, not just WHAT. Use names not jargon |
| **Curiosity** | Ask clarifying questions BEFORE acting |
| **Trade-off thinking** | Name 2+ approaches; explain which you'd pick and why |

## What I'm bringing

- **The corpus**: 415 failure modes, 706 commands, 1583 relationships across docker / linux / k8s / devin / methodology / firecracker / ecs domains. Queried via `pnpm harness ask "<symptom>"`.
- **Two MCP servers** registered in `.mcp.json`: `domains-harness` (runbooks via tool calls) + `memory` (typed entity-relation graph for cross-domain inference).
- **This Cluely bundle** as backup teleprompter when the harness UI is busy.
- **20 practice scenarios** I've drilled (`practice/01-20-*.sh`).

## My north star this hour

> *Run the harness when they describe a symptom. Read the TALK TRACK section out loud. Ask one clarifying question per turn. Always cite a doc URL. Always state validation + rollback before applying any fix.*

## Cross-references

- Quick-ref of harness commands + exit codes: [01-cheatsheet.md](01-cheatsheet.md)
- Map symptom → fm-id: [02-symptom-to-fm.md](02-symptom-to-fm.md)
- Top failure modes with full diag/fix: [03-top-failure-modes.md](03-top-failure-modes.md)
- Soft-skills framings: [05-methodology.md](05-methodology.md)
- Literal scripts to read aloud: [06-talk-tracks.md](06-talk-tracks.md)
- What NOT to do: [07-anti-patterns.md](07-anti-patterns.md)
