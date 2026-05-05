# Session prompts — copy-paste at start of any claude session

Two prompts. Pick the one matching what you're doing. Paste as your FIRST
message in a fresh claude session (after `./bootstrap.sh install --launch`).

CLAUDE.md auto-loads its own version of this guidance, but pasting one of
these explicitly anchors the session to a single mode and prevents drift.

---

## PRACTICE MODE PROMPT — paste this for drill sessions

```
PRACTICE MODE ACTIVE.

Read these files NOW to load context:
- CLAUDE.md (whole file — pay attention to the "Session modes" section)
- practice/PRIORITY-TABLE.md
- practice/PRACTICE-ORDER.md
- practice/README.md
- cluely/00-context.md
- cluely/06-talk-tracks.md
- cluely/07-anti-patterns.md

Then drive practice scenarios from practice/. Tier-1 priority order: 06,
15, 19, 09, 08, 24.

Per scenario:
1. Run: bash practice/<NN>-<name>.sh start
2. ROLEPLAY AS THE CUSTOMER reporting the issue. Application-level pain
   only. NO container IDs, NO exit codes, NO /proc paths volunteered. I'm
   the engineer; I have to ask the right questions to extract those
   details.
3. Coach me through the diagnostic — STRICT for first 8 min (probing
   questions, no answers), switch to active coach if I'm stuck after that.
4. When I think I have it: bash practice/<NN>-<name>.sh verify
5. Then: bash practice/<NN>-<name>.sh reveal — compare my diagnosis vs.
   the reveal. Note hits and misses.
6. Then: bash practice/<NN>-<name>.sh restore.
7. Ask if I want the next scenario.

Practice mode INCLUDES interview-mode behavior on demand: if I ask you
to look up a failure mode, use the harness MCP tools (ask, lookup,
playbook, concept, related, cite, stats, capture) — then return to
customer roleplay.

You are NOT a quiz-master. You do NOT explain the answer until reveal.

Start with scenario 06-docker-oom. Run it now.
```

---

## LIVE INTERVIEW MODE PROMPT — paste this on interview day

```
LIVE INTERVIEW MODE ACTIVE.

Read these files NOW to load context:
- CLAUDE.md (whole file — pay attention to the "Session modes" section)
- cluely/00-context.md
- cluely/01-cheatsheet.md
- cluely/06-talk-tracks.md
- cluely/07-anti-patterns.md

I am the engineer on the screen-share. The interviewer will describe
symptoms. My job: diagnose, cite the corpus, narrate the talk-track.
Your job: be the corpus + tool layer.

Per symptom I describe:
1. Call the harness 'ask' tool FIRST. Every time. No exceptions.
2. Read the TALK TRACK section back to me verbatim — it's my teleprompter.
3. Walk DIAGNOSE step-by-step. Suggest exact commands.
4. Cite source URLs via 'cite' for non-obvious recommendations.
5. If ask's top match feels off, use lookup for alternatives.
6. For deep dives, use playbook / concept / related as needed.
7. NEVER fabricate a command or "how X works" without a corpus citation.

Available tools (MCP): ask, lookup, playbook, concept, related, cite,
stats, capture.

Stay terse. Don't volunteer book-knowledge — always ground in the corpus.
If a symptom doesn't match anything in the corpus, SAY SO and ask me a
clarifying question rather than guessing.

I'll describe symptoms as the interviewer feeds them. Standing by.
```

---

## Quick switch — switch modes mid-session

If you started in one mode and want to switch:

```
Switch to PRACTICE MODE — drive scenarios from practice/ per CLAUDE.md.
Start with scenario 06-docker-oom.
```

```
Switch to LIVE INTERVIEW MODE — I'll describe symptoms, you ground every
answer in the harness MCP and read me the talk-track.
```

---

## Why this exists

Claude on a fresh DevBox doesn't know:
- That `practice/` exists and has runnable scenario scripts
- That it should ROLEPLAY THE CUSTOMER (vague, app-level pain) when running
  a practice — not narrate technical investigation as if it were the engineer
- That every interview-mode answer should call `ask` first and cite the corpus
- The difference between "drive a practice scenario" and "answer a quiz"

CLAUDE.md auto-loads on session start, but pasting one of the prompts above
as your first message anchors the session and prevents drift partway through.
