# `exercise/anatomy`

Leaf of the `exercise` domain. **Depth: exhaustive.** See `PLAN.md` for the full phase plan and
`PROGRESS.md` for the running log.

## What this leaf is

The **coverage backbone** of the corpus: a complete, canonical enumeration of every trainable muscle
and muscle head, with the kinesiology that makes each one targetable. It fills the `muscles` table.
The routine generator's "hit EVERY muscle" gap-analysis runs by joining prescribed sets against these
rows — so an anatomical gap here silently becomes an untrained muscle in the final program. This leaf
is **descriptive only**: it carries no programming opinion (that lives in `programming` / `techniques`).

## What it serves

From these rows the corpus can answer:

- *What is the full set of muscles I must train?* (the completeness checklist)
- *What does muscle X do?* — `primary_actions[]`, `planes[]`, `joints_crossed[]`
- *How do I bias its long length?* — `length_bias` + `biarticular` (gastroc trains knee-**straight**,
  soleus knee-**bent**; rectus femoris stretches hip-extended/knee-flexed; triceps long head needs an
  overhead/shoulder-flexed position; hamstrings as hip-extensors vs knee-flexors).
- *What is its antagonist?* — `antagonist_ids[]` (drives push/pull balance + antagonist supersets).

## Fills

| Table | Rows | Notes |
|---|---|---|
| `muscles` | **~55–75** | one row per muscle or independently-trainable head |
| `relationships` | ~60–100 | `antagonist-of`, `head-of`/`part-of`, `region-member` |
| `concepts` | ~15–25 | planes, joint actions, biarticular, active/passive insufficiency, regionalization |
| `claims` | ~6–12 | only genuinely **contested anatomy** (lat regionalization, rectus-femoris active insufficiency, soleus/gastroc independence, biceps/triceps head bias) |
| `studies` | ~5–12 | only where a contested claim leans on a specific paper |
| `sources` / `documents` | ~12–25 | the references behind every row |

Does **not** fill: `exercises`, `movement_patterns`, `substitutions`, `training_variables`,
`set_structures`, `constraints`.

## Coverage scope (regions enumerated)

BACK / posterior chain (lats, teres major/minor, rhomboids, traps upper/mid/lower, levator scapulae,
erector spinae, rotator cuff) · CHEST (pec major clavicular/sternocostal/costal, pec minor, serratus
anterior) · SHOULDERS (deltoid anterior/lateral/posterior) · ARMS (biceps long/short, brachialis,
triceps long/lateral/medial) · FOREARMS (brachioradialis, wrist flexors, wrist extensors, **finger-flexor
crush group — flagged for the left-pinky constraint**) · CORE (rectus abdominis, ext/int obliques,
transversus abdominis, QL) · LEGS (rectus femoris + 3 vasti; hamstrings biceps-femoris/semitendinosus/
semimembranosus; glutes max/med/min; adductors; gastrocnemius; soleus; tibialis anterior).

## Authorities

Anatomy atlases (Kenhub, Physiopedia, TeachMeAnatomy, OpenStax A&P) · exercise-science muscle
directories (ExRx, Muscle & Motion) · kinesiology texts (Neumann, NSCA Essentials) · primary literature
**only** for the contested regional-activation claims.

## Position in the graph

Root of the leaf chain: `anatomy → movements → routine`. The `exercise.muscle.<slug>` id namespace is
**frozen here**; every downstream leaf references it. Acceptance: no anatomical gap versus a complete
kinesiology muscle list, verified by 3–5 adversarial skeptics each handed a different canonical muscle
index.
