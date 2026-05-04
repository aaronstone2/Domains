# 06 — Talk tracks (literal scripts to read aloud)

> When you want what to SAY in the moment. Read these verbatim. Pivot the wording slightly to match the actual symptom.

## T-0: when the interviewer first describes the scenario (~15 seconds)

> "Before I touch anything I want to make sure I understand the problem. Could you tell me **what you're seeing** — the literal symptom — **when it started**, and whether it's **user-impacting now** or just an alert? While you describe it I'll have my support harness open — it's a corpus I built of every Docker / Linux / k8s / Devin failure mode I've documented, and it gives me a structured runbook for almost any common symptom. I'll narrate as I go so you can see my reasoning."

This hits **4 of 5 eval criteria** (curiosity, communication, clarity, "the why" of using a tool). See [00-context.md](00-context.md) for the criteria.

## T+30: after they've described enough to pick a fm

> "OK, I'm hearing **[paraphrase the keyword]**. That maps to a known failure-mode class. Let me confirm with the cheapest diagnostic before I commit to a hypothesis."

Then call `ha "<their description>"` — read the **TALK TRACK** section of the output back to them. The talk-track is pre-written to script the rest of this interaction.

## T+60: paraphrasing a diagnostic step before running it

> "I'd start by **[paraphrase action from harness output]**. The expected outcome is **[paraphrase expect:]**. Want me to run that?"

Wait for confirmation. Then run. Read the output back. Then:

> "That [confirms / contradicts] the [class] hypothesis. **Result reads as expected — no surprises.**" OR
> "That contradicts what I expected — **expected X, saw Y. Let me try the next diagnostic to disambiguate.**"

## T+120: proposing a fix

> "Based on the diagnostics, this looks like **[fm-id, in plain words]**. The fix has two paths:
>
> **(A)** the immediate one — `[fix step 1 paraphrased]`. Validation is **[validate: paraphrased]**. Rollback if it doesn't take is **[rollback:]**.
>
> **(B)** the systemic / longer-term one — **[mention the architectural fix from the playbook]**.
>
> I'd start with (A) because [reason — usually 'lower blast radius' or 'reversible']. Want me to apply it?"

This script alone hits **trade-off thinking + clarity + communication** — three eval criteria in one breath.

## T+180: when stuck and the diagnostics don't fit

> "What I'm seeing isn't matching the standard pattern for [hypothesis]. Let me back up a level and apply USE method:
>
> - **Utilization** of [the relevant resource]: [number from a quick metric]
> - **Saturation**: [is there a queue / wait time / throttle metric]
> - **Errors**: [is there an error count]
>
> The first one with non-zero saturation or errors will be where I focus next."

USE method as a fallback frame keeps you from going silent. See [05-methodology.md](05-methodology.md) for the full method.

## When asked a soft-skills question (postmortem, blame, on-call burnout)

> "I think about [topic] through the lens of the SRE postmortem framing — there are 4 rules I try to follow: use roles not names, reframe 'X forgot' as 'the process didn't catch', list contributing factors not 'the cause', and make action items system-level. Specifically for **[their question]**: ..."

Then drill into the specific topic. The methodology corpus has fms for these — query `ha "<topic>"` to get a structured answer. See [03](03-top-failure-modes.md) for `methodology.fm.*` entries.

## Closing the interaction

When you've fixed it OR are about to escalate:

> "To recap: the symptom was **[X]**. Root cause was **[Y]** — confirmed by **[diagnostic that proved it]**. The fix was **[Z]**, with **[validation step]** showing it took. Going forward, the systemic guard would be **[architectural fix from the playbook]** — that prevents the class of failure, not just this instance. Anything I should clarify?"

This script demonstrates **clarity + trade-off thinking** at the close. It's also rehearsable — practice it on the [practice scenarios](../practice/) until it's natural.

## Phrases to embed throughout (these are eval-criterion signals)

| Signal | Phrase |
|---|---|
| Curiosity | "Before I do X, I want to know..." |
| Hypothesis-driven | "My hypothesis is X; the cheapest test is Y" |
| Trade-off thinking | "Two paths here: A has [property], B has [property]. I'd pick A because..." |
| Validation | "How will we know this fix worked? Specifically: [metric or command output]" |
| Rollback awareness | "Before I apply this — rollback would be [Z]" |
| Citing | "Source for this is [doc URL from harness output]" |

## What NOT to say

See [07-anti-patterns.md](07-anti-patterns.md) — entire doc on this.
