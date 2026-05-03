# Scenario 10 — "Our postmortem became a trial"

**Difficulty:** soft-skills heavy (no command output to fix this; tests judgment, communication, references)
**Domains exercised:** methodology
**Time-to-resolution target:** N/A — this is a multi-day cultural intervention, not a debug

---

## User opening message

> Hey — I'm an engineering manager. We had a Sev2 last Tuesday, an engineer on my team made a one-line config mistake during a routine deploy that knocked our payment service down for 18 minutes. We held the postmortem yesterday and it went badly — the engineer was visibly upset, leadership asked a lot of "why didn't you" questions, and now the engineer is talking about quitting. I've also noticed engineers on adjacent teams trying to avoid being assigned to deploys. I think we screwed up the postmortem. Can you help me think about how to recover?

## SE mental model (5 seconds)

This isn't a technical incident — it's a **cultural failure of the postmortem process**. The technical "fix" (whatever the config mistake was) is irrelevant compared to the secondary damage:

- Direct harm: an engineer is at risk of leaving.
- Indirect harm: a chilling effect on willingness to take on risky work.
- Future harm: future incidents will be reported less, investigated less honestly, and recur more.

This is the canonical *Google SRE Book Ch 15 — Postmortem Culture* scenario. The recovery has both immediate (this person, this week) and structural (this team, ongoing) components. Use the harness's methodology fms — `methodology.fm.postmortem-blame` and `methodology.fm.retro-becomes-trial` are both directly applicable.

## Harness queries

```text
$ pnpm harness lookup "postmortem blame culture"
```

Top hit: `sre-postmortem-culture` (Google SRE Book Ch 15 — the canonical reference). Plus the methodology fms:
- `methodology.fm.postmortem-blame`
- `methodology.fm.retro-becomes-trial`
- `methodology.fm.action-items-never-done` (related — failure to learn)

```text
$ pnpm harness playbook methodology.fm.retro-becomes-trial
```

Verified:

```
=== methodology.fm.retro-becomes-trial  [methodology] ===
Patterns: blame | trial | postmortem | retrospective
Affects: methodology.blameless-postmortem, methodology.postmortem,
         methodology.blame-someone-else-anti-method

-- Diagnostic steps --
  1. Observe meeting dynamics
     # 'who did this' vs 'what allowed this'

-- Fix steps --
  1. Reset facilitator role; remove names from doc
     # rewrite doc using roles instead of names
  2. Senior leader publicly thanks the engineer for their honesty
     # in next all-hands or post-mortem doc

Citations:
  sre-postmortem-culture: Google SRE Book — Ch 15 Postmortem Culture
    https://sre.google/sre-book/postmortem-culture/
```

```text
$ pnpm harness playbook methodology.fm.postmortem-blame
```

Verified:

```
=== methodology.fm.postmortem-blame  [methodology] ===
Symptom: Engineer reluctant to participate in postmortem; team morale damaged

-- Fix steps --
  1. Adopt blameless template
     # pagerduty/response.pagerduty.com or sre/postmortem-templates
  2. Train team
     # review SRE Book Ch.15
```

## SE response (turn 1)

> I'm sorry — that's painful, and you're right to take it seriously. The signals you're describing (engineer at flight risk, others avoiding deploy assignments) are exactly what happens when a postmortem turns into a trial. The instinctive next step — "we need a better process next time" — is true but slow; the urgent thing is repairing the immediate harm. I'd structure the recovery as three concentric loops:
>
> **Loop 1 — this person, this week.** Direct, private, and explicit:
>
> - **1:1 with the engineer ASAP**, ideally today. Don't open with the postmortem; open with "I want to check in on how you're doing." Listen first.
> - When the postmortem comes up: **own the failure of the process**, not their failure of the deploy. Something like "the postmortem went off the rails — that wasn't fair to you, it was a process I'm responsible for, and I'm going to fix it." Be specific about what was wrong (the "why didn't you" framing).
> - Make their continued employment unambiguous: "I want you here. Your judgment has been right far more often than wrong. The fact that you noticed and rolled back in 18 minutes is a sign of operational maturity, not failure."
> - Don't ask them to forgive yet. Don't ask them to participate in the rewrite. Just signal that the team's understanding of what happened is going to change.
>
> **Loop 2 — the postmortem doc, this week.** This is where the harness's playbook directly maps:
>
> - **Rewrite the postmortem doc to be blameless.** Concrete techniques (from the SRE Book Ch 15):
>   - Replace names with roles: "the deploy engineer" instead of "Sarah."
>   - Reframe every "Sarah forgot to..." as "the deploy process did not catch...": *the YAML had no schema validation, so the bad value reached prod*; *the canary period was 0 seconds, so the error wasn't caught before full rollout*; *the rollback runbook required a step that hadn't been documented.*
>   - List **contributing factors**, not "the cause." There are always many.
> - **Have a senior leader publicly thank the engineer for their honesty** — in the rewrite, in the next all-hands, in the postmortem-review meeting. The signal needs to be visible to the broader team, not just private with the engineer.
>
> **Loop 3 — the team, structural.** Slower but most important:
>
> - **Adopt a blameless postmortem template** that *forces* the right framing. The PagerDuty Incident Response template and the Google SRE example postmortem are both freely usable starting points.
> - **Move action items into a tracked backlog with deadlines.** "Add YAML schema validation" and "Add 60s canary period" should land in the team's sprint, not a doc nobody reads.
> - **Practice on a fake one** — run a blameless drill on a hypothetical incident from last quarter. Train the team on the framing without the emotional stakes of a real recent failure.
>
> The single biggest mistake to avoid: **don't let leadership "make an example" of the engineer to discourage future mistakes.** Every operational research finding for 30 years says the opposite happens — people start hiding mistakes, and your incident detection time triples.
>
> Citations: [Google SRE Book — Ch 15 Postmortem Culture](https://sre.google/sre-book/postmortem-culture/), [PagerDuty Incident Response — Postmortem](https://response.pagerduty.com/after/post_mortem_process/).

## User reply (turn 2)

> The "rewrite" part is going to be hard — leadership wants to see "accountability." How do I push back without making it political?

## SE mental model (turn 2)

This is the real organizational tension: leadership often equates blameless with no-accountability. The SRE Book is explicit that blameless ≠ accountability-free; it's that *accountability targets the system, not the person.* "Add canary period" is accountability — for a process change.

The strategic move: **reframe what leadership is actually asking for.** They want assurance "this won't happen again." Blameless postmortem produces a much stronger version of that assurance — process changes that prevent the failure regardless of who's at the keyboard. Naming-and-shaming produces no such guarantee.

Also worth knowing: ~30 years of HRO/incident-research literature is on your side. Citing Sidney Dekker's *Just Culture* or *The Field Guide to Understanding 'Human Error'* is a defensible move with senior leaders.

## SE response (turn 2)

> Leadership's instinct ("we need accountability") is legitimate — they're worried about recurrence. The reframe that usually lands:
>
> **"Blameless doesn't mean no consequences — it means the consequences target the system, not the person, because that's what actually prevents recurrence."**
>
> Concretely, here's a 1-paragraph framing you could send leadership:
>
> > "I want to revisit the postmortem framing. The current 'why didn't you' framing assigns the failure to one engineer, which gives us no protection against the next engineer making the same mistake under the same conditions. The blameless framing produces stronger guarantees — by examining what about the deploy *process* allowed a one-line error to reach prod, we get changes that prevent the failure regardless of who runs the deploy. Specifically the rewrite would identify (a) why we don't have YAML schema validation in CI, (b) why our canary period was zero, (c) why the rollback runbook wasn't documented end-to-end. Each becomes a tracked action item with an owner and deadline. That's accountability — to the system. The current framing gives us a sad engineer and no system-level fix."
>
> Add evidence:
>
> - Cite the [Google SRE Book Ch 15](https://sre.google/sre-book/postmortem-culture/) — every major SRE org operates this way; this is the industry default.
> - If they want to go deeper: Sidney Dekker's *The Field Guide to Understanding 'Human Error'* (book) or his short essay "Just Culture: Who Gets to Draw the Line?" The argument is that human error is a *symptom* of system design, not a *cause*.
> - For a numerical version: "post-incident reporting rates fall by 40-60% in blame-heavy environments" — search for any of the High-Reliability Organization (HRO) literature.
>
> The pitch isn't soft-and-fuzzy. It's: *"We get more reliability from blameless postmortems than from blameful ones, because we get more honest data and more system-level fixes."*
>
> If leadership *still* wants to "hold someone accountable" beyond the system fixes, the question to push back with is: "what specifically do you want to change about this engineer's role going forward?" Usually the honest answer is "nothing"; if so, the public posture should match.

## User reply (turn 3)

> That's helpful. Last thing — the engineer asked me yesterday whether I want them to step away from production deploys for a while. What do I say?

## SE mental model (turn 3)

This is a tactical-empathy question disguised as a permissions question. The engineer is offering to make the manager's life easier by removing themselves; they're also testing whether the manager actually believes the "you're valued" message.

The right answer is **no, with a specific show of trust** — but framed in a way that doesn't make them feel forced.

## SE response (turn 3)

> Don't say yes — even if they want it, even if it would be easier in the short term. Saying yes confirms the implicit message of the bad postmortem: "you're the problem, you should be removed." It also creates a precedent where mistakes lead to demotion, which produces every dysfunction we just talked about.
>
> What to say instead — give them the choice but show your trust:
>
> > "I appreciate you offering, but I don't want you to step back. Here's what I'd actually like: I want you on the team that designs the canary-period and YAML-validation changes from the postmortem. You have firsthand knowledge of where the gap is — that's exactly the perspective the fix needs.
> >
> > If you want to take a few days off the on-call rotation while you reset, that's totally fine — I'll cover it. But I don't want you off deploys long-term, and I want to be explicit: the team is better with you doing deploys than with you not."
>
> Two things this does:
>
> 1. **Reframes the deploy from "place where I failed" to "place where I have unique knowledge."** That's the truth — they understand the failure mode in a way nobody else on the team does right now.
> 2. **Offers a real, time-limited break** (the on-call coverage) without the implicit punishment of being removed from work.
>
> If they take the on-call break: pick it up yourself, even if it's inconvenient. The visible signal "manager covers for engineer" is the inverse of "engineer is shamed in postmortem" — both are remembered for years.
>
> One last thing: **document the recovery itself.** In 6 months, when the next incident happens, having a written record that says "after the Tuesday incident, we rewrote the postmortem to focus on system fixes; engineer X led the canary-period fix; here's the result" is a permanent template the team can point at. Past behavior is the strongest predictor of future norms.

## Follow-up question (turn 4)

> What about the engineers on adjacent teams who are now avoiding deploy assignments?

## SE response (turn 4)

> They're rationally responding to a signal: "if you're at the keyboard when something breaks, leadership will hold a public trial." Until that signal changes, no amount of "deploys are part of the job" messaging will change behavior — they're protecting themselves.
>
> Three things actually move this:
>
> 1. **Do the rewrite in public.** When the rewritten postmortem ships, share it broadly with the framing: "we got this postmortem wrong; here's what we changed and why." The adjacent teams need to see the *process* change, not just hear about it.
>
> 2. **Make the deploy process safer for everyone.** YAML schema validation, canary periods, automated rollback — these don't just help your team, they make the whole org's deploys lower-risk. That's the thing that actually shifts "who wants to do deploys."
>
> 3. **Tell the recovery story at an all-hands or org-wide forum.** Including: the original postmortem was blameful; the engineer was harmed; we recognized it; here's what we changed. Engineers on other teams will recalibrate based on watching how *this* one was handled, not based on a memo about how postmortems "should" go.
>
> The harness has a related fm: `methodology.fm.action-items-never-done` — if the recovery action items don't actually get done, the cultural shift won't stick. Put dates on them, put owners on them, surface them in your team's sprint, and report on completion publicly. That's the long-tail commitment.

---

## Coverage notes

- **No-tools scenario:** the harness here surfaces a methodology source (Google SRE Book Ch 15) and two methodology fms, but the answer is judgment-heavy. The corpus's role is "give me defensible language and citations."
- **Three-loop structure (person / doc / structural):** generic recovery framework that maps to most cultural-failure scenarios.
- **Reframe leadership concerns rather than fight them:** "blameless ≠ no accountability" is a sentence that should be memorized; the SRE Book has the longer version.
- **Tactical empathy in turn 3:** the offer-to-step-back is a probe for trust, not a real request. Recognizing it matters.
- **Adjacent-team chilling effect** is the highest-cost long-term damage; explicitly addressed in turn 4.

## Practice notes for interviewer pushback

- "What if the engineer's mistake was actually negligent — they bypassed CI on purpose?" → Then accountability *to the person* starts to apply (probationary period, additional review on their PRs, etc.) — but the postmortem framing is still "what allowed bypassing CI to be possible / appealing?" System-level fixes (require approval to bypass, alert on bypass, audit log) still come first.
- "We're a startup with no SRE function — is this whole framing applicable?" → Yes; SRE is a discipline, not a job title. The blameless-postmortem framing scales down to a 5-person team. The pieces that matter are: tracked action items, depersonalized doc, and one senior person committed to the cultural norm.
- "What if leadership refuses to back the rewrite?" → That's a leadership culture problem bigger than the postmortem; raise it with grandboss / HR / external coach. Make sure the engineer doesn't bear the cost of a fight you're having above them.
- "How do I prevent this in the future?" → Adopt a postmortem template *before* the next incident. Practice with a low-stakes drill. Have a designated facilitator who's not the manager-of-the-engineer-involved (avoids the implicit power dynamic).
- "What about the customer / external stakeholders?" → Different framing for them — they want to know "what changed so this doesn't happen again," answered in terms of the system fixes. Never name engineers in external-facing post-mortems regardless of internal culture.
