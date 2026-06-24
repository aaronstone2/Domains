# Plan — `exercise/techniques`

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> **Depth: `exhaustive`** (set in `STATUS.yaml`). This is a load-bearing leaf — it is where the seed
> Gemini doc is most wrong, so the gold layer (Phase D) is verified adversarially: N independent
> skeptics try to refute every "superior" claim, majority-vote, dissent recorded. See
> `domains/_shared/sessions/depth-profiles.md`. Re-engagement contract:
> `domains/_shared/sessions/extend-playbook.md`.

## Context

Why this leaf exists: this is the **set-structure / intensity-technique** layer — *how* the reps in a
set are arranged once volume, load, and proximity-to-failure (the `programming` knobs) are fixed.
It covers reverse-pyramid (RPT), crescent/ascending pyramid, straight sets (double-progression),
drop sets, rest-pause, myo-reps, supersets, and cluster sets. For each structure the corpus must serve:
**mechanism** (which motor units it recruits and how it accumulates fatigue), **fatigue_cost**,
**best_for** (compound-strength vs isolation-hypertrophy vs time-efficiency), **contraindications**
(esp. anything grip-loaded or failure-on-compound that the lifter must avoid), and **evidence_grade**.

It exists primarily as the **corrective leaf for the seed doc**. The Gemini deep-research doc correctly
notes that volume-equated pyramid / RPT / straight sets yield statistically similar hypertrophy, then
slides into calling RPT "far superior" — conflating *equal growth* with *better*. This leaf's `claims`
rows split that conflation everywhere it appears:

- the **evidence/effect claim** — what volume-equated RCTs and reviews actually show (high grade: T0/T1);
- the **practical/mechanistic claim** — why you'd still pick a structure (fatigue-management, time-
  efficiency, skill/load on the bar, joint sparing) — explicitly *lower* grade (T2/T3).

The corpus must be able to answer: "Does RPT grow more muscle than straight sets?" → *equivalent
(T0/T1), with a fatigue-management advantage (T2)*; "Do drop sets build more muscle?" → *equivalent
when volume-equated; they win on time-efficiency only*; "Which structure for a failure-prone compound
with a grip caveat?" → straight sets with RIR buffer, intensity techniques quarantined to isolation.

How it composes: it **draws on** `programming` (volume-equating, RIR/failure, %1RM, rest) — a set
structure is only meaningful relative to a fixed weekly-volume and proximity-to-failure target, so
every `claims` row here is stated "volume-equated" and cross-links to the matching `training_variables`
row. It **draws on** `movements` (a structure attaches to an exercise: RPT on a fixed-core compound,
myo-reps/drop sets on a high-SFR isolation) and `anatomy` indirectly (intensity techniques on small
single-joint muscles vs large compounds). It **underpins** `routine`: the generator picks a set
structure per slot — RPT on the fixed cores, double-progression straight sets as the default,
myo-reps/drop sets to buy volume on isolations under time pressure — and each choice cites a row here.
It hard-links to `constraints`: any structure that drives a compound to failure or raises grip/crush
load is flagged against the lifter's **left-pinky jam** and **failure-on-compounds** history.
Cross-domain edges are wired in Phase E *as discovered*, not deferred.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the `exercise` domain-specific tables in `schema.exercise.sql`.

This leaf fills, with `exhaustive` row targets:

| Table | What this leaf puts there | Row target |
|---|---|---|
| `set_structures` | one row per structure + named sub-variant (RPT, crescent/ascending pyramid, full triangle pyramid, straight-set double-progression, drop set, mechanical drop set, rest-pause, myo-reps, antagonist superset, agonist/pre-exhaust superset, compound superset, cluster set, plus partials/lengthened-partials as an intensity technique if in-scope) — each with `family`, `mechanism`, `fatigue_cost`, `best_for`, `contraindications`, `evidence_grade`, `source_ids` | **14–20** |
| `claims` | the gold layer: every "X is superior" assertion split into an effect claim + a practical claim, each with `verdict` (supported/equivalent/disputed/refuted), `nuance` (the recorded dissent), `evidence_grade`, `agreement_score`, `affected_ids` → the `set_structures` rows, supporting/contradicting `source_ids` | **18–28** |
| `studies` | richer metadata for each primary paper cited (pyramid RCTs, drop-set/rest-pause/myo-rep systematic reviews, the seed doc's reference-chased papers): `design`, `n_subjects`, `training_status`, `duration_weeks`, `key_finding`, `effect_summary`, `citation` | **15–25** (one per primary study source) |
| `sources` | tiered source list for this leaf (Phase A) — T0 reviews/metas, T1 RCTs, T2 consensus authorities, T3 mechanistic/practitioner | **25–45** |
| `documents` | fetched + parsed full text / abstracts for the above (Phase B) | ~= sources fetched |
| `concepts` | glossary entries for technique terms (RPT, double-progression, myo-reps, rest-pause, mechanical drop set, cluster, pre-exhaust, "effective reps"/stimulating-reps model) | **12–18** |
| `relationships` | typed edges (Phase E): structure→`evidenced-by`→source, structure→`best-for`→exercise-class, structure→`contraindicated-by`→constraint, structure→`alternative-to`→structure, claim→`refines`→claim | **30–50** |

`failure_modes`, `commands`, `config_keys` are largely out-of-scope for this leaf (they belong to
`routine`/debugging-style leaves); leave empty unless a clean fit appears.

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — the seed Gemini doc's
technique section + its cited papers, the authority sites' technique pages (SBS/MASS, Schoenfeld,
Helms/3DMJ, RP, Henselmans, MacroFactor/Nuckols), and PubMed/PMC for the specific RCTs and reviews;
(2) **Plan** agent(s) design the extraction — which sources map to which `set_structures`/`claims`
rows and what each adversarial refutation prompt looks like; (3) `AskUserQuestion` only on real forks
(e.g. include partials/lengthened-partials here vs. defer to `programming`? include supersets/clusters
or keep to the seed's set; the answer below is the working assumption); (4) write this PLAN +
`STATUS.yaml`; (5) `ExitPlanMode`.

The irreducible work is the **gold layer (Phase D)** — the conflation-splitting. Everything before it
is mechanical (find URLs, fetch, parse). Meta-research exists to spend the expensive adversarial layer
on the right papers, especially the *volume-equated* ones (the only ones that can adjudicate "grows
more muscle"). A structure-vs-structure study that does **not** equate volume is evidence about volume,
not about the structure — flag and down-weight those during planning.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to set structures / intensity techniques.

Candidate source **categories** and named authorities (multi-modal sweep, not one angle):

- **Pyramid / load-arrangement RCTs (T0/T1).** The canonical volume-equated pyramid-vs-RPT-vs-straight
  comparisons — *Schoenfeld et al.* constant-vs-variable / pyramid loading studies; *Angleri, Ugrinowitsch
  & Libardi (2017)* "crescent pyramid vs traditional" trained-men RCT; any ascending-vs-descending load RCTs.
  These are the spine of the "equivalent hypertrophy" verdict.
- **Drop-set systematic reviews + RCTs (T0/T1).** *Coleman et al.* drop-set meta/review; *Schoenfeld &
  Grgic* drop-set commentary; *Fink et al.* drop-set vs normal RCTs; *Ozaki et al.* low-load + drop-set
  work; practitioner syntheses (*Brook Bush*) as T2/T3 mechanism. Target verdict: equal hypertrophy
  volume-equated, time-efficiency win.
- **Rest-pause / cluster-set evidence (T0/T1/T2).** *Prestes et al.* rest-pause RCT; cluster-set
  reviews (*Tufano et al.*) — note cluster sets are mostly a power/velocity-maintenance tool, not a
  hypertrophy edge; record that scoping carefully.
- **Myo-reps / "effective reps" model (T2/T3).** *Borge Fagerli* (originator) + the stimulating-reps /
  effective-reps mechanistic model (SBS/MASS critiques of it). Effect grade is low — flag as
  mechanistic/practitioner, not RCT-proven superior.
- **Superset / pre-exhaust evidence (T1/T2/T3).** Antagonist-superset acute studies (work-density,
  performance maintenance); *pre-exhaust* studies showing it does **not** preferentially shift muscle
  activation as folklore claims (refutation candidate); time-efficiency reviews (*Iversen et al.*,
  *Weakley et al.* on supersets for training efficiency).
- **Expert-consensus authorities (T2).** Stronger By Science + MASS (Nuckols, Helms, Zourdos); Schoenfeld
  *Science and Development of Muscle Hypertrophy*; Helms/3DMJ; RP/Israetel; Henselmans. Use for the
  *practical* claims and to corroborate verdicts, never to override a volume-equated RCT.
- **Mechanistic / practitioner (T3).** Motor-unit recruitment + size-principle explainers, fatigue
  models, "stimulating reps near failure" — supplies `mechanism` text for `set_structures`.
- **Reference-chase the seed.** Reference-chase the Gemini doc's technique-section citations **one hop**;
  every primary paper it leans on for "RPT superior" gets pulled and re-read against its own data.

Tasks:
- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` (or a leaf-local `sources.yaml`).
- [ ] For each: `tier` (T0–T3), `license_note`, `parser`. Skim once; drop redundancy.
- [ ] `exhaustive` width: full sweep across all six categories above + multi-hop reference-chasing on
      the pyramid/drop-set primaries until dry; do not stop at the seed doc's citation list.
- [ ] **Acceptance / Verify:** `uv run python -m ingest list --domain exercise --subdomain techniques`
      shows **25–45** rows; every structure in scope has ≥1 candidate primary source; every "superior"
      claim has at least one *volume-equated* source attached or is explicitly marked "no equated
      evidence — practical only"; eyeball pass for off-topic drift.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain exercise --subdomain techniques` → fills `sources`/`documents`,
      caches raw under `_db/raw/exercise/techniques/`.
- [ ] `uv run python -m ingest load --domain exercise` (close the motherduck MCP first — it holds a read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Acceptance / Verify:** doc count ≈ sources fetched; mean length sane (abstracts short, reviews
      long); spot-check 3 random docs render as clean markdown; the pyramid + drop-set primaries are
      present and full-text (not paywall stubs) — if stubbed, capture abstract + methods + results table
      at minimum, since the *volume-equating* detail lives in the methods.

## Phase C — Extract → entity tables

Goal: structured rows for `set_structures`, `studies`, and `concepts`.

- [ ] Extract `set_structures` (14–20 rows). For each: `id` `exercise.tech.<slug>`, `family`
      (`pyramid` | `straight-set` | `intensity-technique`), `mechanism` (motor-unit / size-principle /
      fatigue-accumulation, in one or two sentences), `fatigue_cost` (low/moderate/high), `best_for`
      (compound-strength | isolation-hypertrophy | time-efficiency | power-maintenance), explicit
      `contraindications` (call out grip-load / crush-grip / failure-on-compound where they apply),
      `evidence_grade`, `source_ids`.
- [ ] Extract `studies` (15–25) — one row per primary paper: `design`, `n_subjects`, `training_status`
      (only `trained`/`recreational` count for the load-bearing verdicts), `duration_weeks`,
      `key_finding`, **`effect_summary` recording whether volume was equated** and the measured outcome.
- [ ] Extract `concepts` (12–18) — glossary for each technique + the "effective/stimulating reps" model.
- [ ] Land via JSON in `extract/<table>.json`, then `ingest load`.
- [ ] **Acceptance / Verify:** counts within the order-of-magnitude above; every `set_structures` row
      resolves to ≥1 `source_id`; every `studies.effect_summary` states equated-or-not; no `best_for`
      asserts a hypertrophy edge that isn't backed downstream by a `claims` row.

## Phase D — Gold layer → verified facts (the irreducible work) — ADVERSARIAL

Goal: the `claims` layer — every "structure X is superior" assertion split into an **effect claim**
(volume-equated literature, high grade) and a **practical claim** (fatigue/time/skill, lower grade),
each with `verdict`, `nuance` (recorded dissent), `evidence_grade`, `agreement_score`, cites.

Seed claims to forge and adversarially test (non-exhaustive — every "superior" in the seed doc gets
this treatment):

1. *"RPT grows more muscle than straight sets / pyramids."* → expected **equivalent** (T0/T1, volume-
   equated); `nuance`: advantage is fatigue-management / heavy-set-while-fresh, not growth (T2).
2. *"Crescent/ascending pyramid is superior to traditional pyramid for hypertrophy."* → expected
   **equivalent** (Angleri 2017, trained men); practical claim about warmup/joint-readiness is T3.
3. *"Drop sets build more muscle than straight sets."* → expected **equivalent volume-equated**;
   `nuance`: win is **time-efficiency** (same growth in less time / fewer total sets) — T1/T0 reviews.
4. *"Rest-pause builds more muscle than straight sets."* → expected **equivalent / disputed**; mostly
   time-efficiency; thin trained-subject evidence.
5. *"Myo-reps are superior."* → expected **disputed**; rests on the effective-reps model (T3
   mechanistic), little direct volume-equated RCT support; record as practical/time-efficiency.
6. *"Cluster sets grow more muscle."* → expected **refuted/disputed for hypertrophy**; they preserve
   power/velocity (their real use), not a documented hypertrophy edge.
7. *"Pre-exhaust supersets shift the stimulus onto the target muscle."* → expected **refuted** (EMG/
   activation studies don't support the folklore); antagonist supersets' real benefit is **work density /
   time-efficiency** (separate, supported claim).
8. *Practical cross-cutting:* "Failure belongs on isolation, not compounds" and "intensity techniques
   (drop/rest-pause/myo-reps) are for high-SFR isolations, not grip-loaded or failure-prone compounds"
   → **supported** practical claims (T2), and the hooks into `constraints` (pinky / compound-failure).

Adversarial protocol (`exhaustive`):
- [ ] For **each** claim, spawn **3–5 independent skeptic agents**, each prompted to *refute* it against
      the literature — specifically to find (a) a volume-equated study showing a real difference, or
      (b) a confound (volume not equated, untrained subjects, acute-only, EMG≠growth) that voids the
      cited support.
- [ ] **Majority-vote:** a claim becomes a trusted fact only if a majority fail to refute. Set
      `agreement_score` = fraction of verifiers that did NOT refute. Survivors → `supported`/`equivalent`;
      non-survivors kept with `disputed`/`refuted` — **never silently dropped**.
- [ ] Record the dissent verbatim in `nuance` (e.g. "metas show equivalent hypertrophy when volume is
      matched; advantage is fatigue-management"). Keep `supporting_source_ids` and
      `contradicting_source_ids` both populated wherever a real disagreement exists.
- [ ] Enforce the **conflation guard:** no `claims` row may assert a hypertrophy edge from a non-volume-
      equated or untrained-subject study; such evidence may only support a *practical* claim. Effect
      claim and practical claim are separate rows linked by a `relationships` edge (`refines`).
- [ ] **Acceptance / Verify:** sample 5 facts re-derive from their cited sources; every "superior"
      assertion in the seed doc has a corresponding split pair (effect + practical) in `claims`; no
      orphan "X is better" without a `verdict` and `agreement_score`; the RPT and drop-set headline
      claims explicitly read `equivalent` on the effect axis.

## Phase E — Relationships → typed graph

- [ ] Wire edges: `set_structure --evidenced-by--> source`; `set_structure --best-for--> exercise-class`
      (RPT→fixed-core compound, myo-reps/drop→high-SFR isolation); `set_structure --contraindicated-by-->
      constraint` (intensity-technique-on-compound → failure-on-compound; any grip-loaded variant →
      left-pinky-jam); `set_structure --alternative-to--> set_structure`; `claim --refines--> claim`
      (practical refines effect); `claim --governs--> set_structure`.
- [ ] Cross-domain: link each `claims` row to the `programming` `training_variables` row it is stated
      relative to (volume, RIR), and to the `movements` exercise-classes its `best_for` names.
- [ ] **Acceptance / Verify:** a graph walk from `exercise.tech.reverse-pyramid` reaches ≥3 sensible hops
      (→ effect claim → programming volume var → movements fixed-core compound, or → constraint).

## On completion

- [ ] Update `STATUS.yaml` (each phase → `done`, `updated:` date) and append a session entry to `PROGRESS.md`
      noting which seed-doc claims were split, which "superior" assertions were downgraded to
      `equivalent`/`disputed`/`refuted`, and any source gaps (e.g. a structure with only practical evidence).

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- `domains/exercise/programming/` — sibling leaf; its `training_variables` rows are the volume/RIR
  anchors every claim here is "equated" against. Copy its `extract/*.json` shape once it exists.
- `domains/exercise/movements/` — exercise-class targets for `best_for` edges.
- The seed Gemini doc — primary reference-chase target; its technique section is the to-correct surface.

## Open questions

- **Scope of intensity techniques:** include partials / lengthened-partials and supersets/cluster sets
  here, or split lengthened-partials into `programming` (ROM) and keep this leaf to the seed's set?
  Working assumption: keep supersets + clusters here (they are set *structures*); treat lengthened-
  partials as a `programming`/`movements` ROM topic and only cross-reference.
- **Cluster sets verdict framing:** record as power/velocity-maintenance (their evidenced use) with an
  explicit "no hypertrophy edge documented" `claims` row, rather than omitting — confirm during Phase D.
- **Myo-reps grade floor:** how hard to mark the effective-reps model — `disputed` vs `equivalent`?
  Resolve by the adversarial vote, not in advance.
