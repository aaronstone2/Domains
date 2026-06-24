# Plan — `exercise/programming`

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> **depth: `exhaustive`** (set in `STATUS.yaml`) — full source sweep + multi-hop reference-chasing,
> every in-scope variable extracted, and the gold layer verified with 3–5 independent refuters per
> claim (majority-vote, dissent recorded). See `domains/_shared/sessions/depth-profiles.md`. The
> re-engagement contract is `domains/_shared/sessions/extend-playbook.md`.

## Context

Why this leaf exists: `programming` is the **dose layer** of the corpus — it owns the numeric knobs
the generator turns when it writes a prescription: **how much** (volume: sets/muscle/week, per-session
ceiling, the junk-volume tail), **how hard** (intensity as %1RM and goal-specific rep ranges), **how
often** (frequency per muscle/week), **how close to failure** (proximity-to-failure / RIR, and the
distinct cost of training *to* failure), **how to grow it over time** (the progressive-overload
hierarchy: load > volume > density), and **how to wave and recover it** (periodization: mesocycle
volume-ramping toward MRV, deloads, autoregulation). It fills `training_variables` — every row a
*scoped, cited, parameterized* knob (scope × goal × population, with min/max/recommended + unit +
evidence_grade) — and the `claims` it must defend. The corpus must answer, with a citation and an
honest verdict: *"How many sets of back per week for an intermediate chasing hypertrophy?"*, *"Does
the last set near failure add growth, or just fatigue?"*, *"Is 2× frequency better than 1× at matched
volume?"*, *"What does a deload actually do?"* — and crucially, never let a **practical** advantage
(less fatigue, more time-efficiency) masquerade as an **effect** advantage (more growth). This leaf is
where the domain's core methodological commitment lives or dies.

How it composes: `programming` is one of the two upstream **fact suppliers** to the `routine`
generator (the other being `movements`). The generator reads `training_variables` to set every cell's
set count, rep range, RIR, and weekly/per-session frequency, and reads `claims` to justify each choice
and to fire the methodological guardrails (e.g. "failure belongs on isolation, keep an RIR buffer on
compounds"). It **draws on** `anatomy` for the muscle list that volume landmarks are scoped to
(weekly-sets.back vs .side-delts differ), and it is **drawn on by** `techniques` (set structures are
*delivery mechanisms* for a volume/intensity/proximity dose this leaf parameterizes — RPT only makes
sense against an intensity+RIR knob) and by `constraints` (the per-session ceiling and failure-cost
claims interact with the lifter's recovery and the pinky-jam grip ceiling). Cross-domain edges into
`anatomy`/`movements`/`techniques` are wired in Phase E **as discovered**, not deferred.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the domain-specific tables in `domains/exercise/schema.exercise.sql`.

This leaf fills (row targets at **exhaustive** depth):

| Table | Fills | Row target | Notes |
|---|---|---|---|
| `training_variables` | **primary** | **≈90–140** | The parameterized knobs. See decomposition below. Each row scoped `global`/`muscle`/`lift-type` × goal × population, with `min_value`/`max_value`/`recommended` + `unit` + `evidence_grade` + `source_ids`. |
| `claims` | **primary (gold)** | **≈30–45** | Each a recommendation split into an **effect** claim and a **practical/mechanistic** claim where they diverge (the core rule). `verdict` ∈ {supported, equivalent, disputed, refuted}, with `nuance`, `agreement_score`, `evidence_grade`. |
| `studies` | supporting | **≈25–40** | Per-paper metadata (design, n, training_status, duration_weeks, key_finding, effect_summary) for the T0/T1 sources backing the load-bearing variables/claims. Keyed to `sources`. |
| `sources` | shared | **≈40–70** | Authorities + metas + RCTs (Phase A). |
| `documents` | shared | per-source | Fetched/parsed text + FTS (Phase B). |
| `concepts` | light | **≈15–25** | Glossary anchors: MEV/MAV/MRV, RIR, junk volume, density, mesocycle, deload, autoregulation, %1RM, effective reps, fractional/SRA. |
| `relationships` | gold edges | **≈40–80** | `evidenced-by`, `scoped-to-muscle`, `governs`, `depends-on`, `antagonizes`/`tradeoff` (Phase E). |
| `commands`, `config_keys`, `failure_modes` | n/a | 0 | Not this leaf (debugging-style tables; `failure_modes` is unused by the evidence-style exercise domain). |

**`training_variables` decomposition** (the ~90–140 budget, by `key` × scope):

- **`weekly_sets`** (scope=`muscle`, the largest block): one row per major muscle group × goal
  (hypertrophy, strength) × population (novice, intermediate, trained). With ~10–12 muscle groups and
  the hypertrophy/intermediate cell as the anchor, this is the bulk — landmarks MV/MEV/MAV/MRV captured
  as `min_value`(MEV)/`max_value`(MRV)/`recommended`(MAV band). **≈40–60 rows.**
- **`session_sets`** (scope=`muscle` or `global`): per-session set ceiling per muscle before junk
  volume / diminishing per-session returns (drives the frequency split). **≈8–12 rows.**
- **`rep_range`** + **`intensity_pct1rm`** (scope=`goal`/`lift-type`): strength (~1–6 reps, ≥80–85%),
  hypertrophy (~5–30 reps to-near-failure, the "effective rep range"), endurance (~15–30+). Split by
  compound vs isolation where it matters. **≈12–18 rows.**
- **`rir`** / proximity-to-failure (scope=`goal`/`lift-type`): hypertrophy 0–3 RIR, strength 1–5 RIR;
  compound vs isolation modifier; the explicit failure-cost row. **≈8–12 rows.**
- **`frequency`** (scope=`muscle`/`global`): sessions/muscle/week, by goal × population; derived from
  weekly-sets ÷ session-ceiling. **≈8–12 rows.**
- **`rest_seconds`** (scope=`lift-type`): compound vs isolation, hypertrophy vs strength. **≈6–8 rows.**
- **periodization knobs** (scope=`global`): mesocycle length (wk), per-week volume increment toward
  MRV, deload frequency/magnitude, autoregulation deltas. **≈8–14 rows.**

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — sitemaps, ToCs, the
authorities' canonical posts/papers; (2) **Plan** agent(s) design the per-leaf extraction — which
sources, which `training_variables` cells, what the refutation prompt for each claim looks like;
(3) `AskUserQuestion` on high-leverage forks (scope, depth, goal-priority); (4) write this PLAN +
`STATUS.yaml`; (5) `ExitPlanMode`.

The irreducible work is the **gold layer (Phase D)**. Everything before it is mechanical (find URLs,
fetch, parse). The meta-research exists to protect the expensive layer from being spent on the wrong
sources. For *this* leaf the highest-leverage meta-decision is **which numbers are load-bearing**: the
hypertrophy/intermediate `weekly_sets` band, the proximity-to-failure dose-response, and the frequency
equivalence are the three places a wrong citation poisons the whole routine — spend verifier budget
there, not on uncontested rest-interval rows.

**Leaf-specific meta-research notes:**

- **Where the canonical numbers live:** the volume dose-response sits in Schoenfeld/Krieger meta-work
  and its critiques (Baz-Valle, Pelland/Nuckols re-analysis showing the curve flatter and rising past
  ~20 sets with caveats); the failure question sits in **Refalo et al. 2023/2024** proximity-to-failure
  meta-regressions (hypertrophy *and* strength split out) plus Robinson/Pelland; frequency sits in
  **Schoenfeld/Grgic/Krieger** frequency metas (the headline: at matched volume, frequency is roughly a
  wash for growth, a modest plus for strength). Anchor each load-bearing variable to a **T0 meta**, then
  triangulate with **T2 syntheses** (MASS, SBS) that have already reconciled the conflicting metas.
- **De-conflation is the deliverable, not a footnote.** For every "X beats Y" recommendation in the
  seed Gemini doc, plan *two* claim rows up front (effect + practical). Budget Phase D verifiers to
  attack the **effect** claim specifically ("show me the volume-equated study where it grows *more*").
- **Reference-chase the seed doc's 51 citations one hop out** (exhaustive), de-dupe against the
  authorities found by-name, and tier. Expect heavy overlap with `techniques` sources — share, don't
  duplicate, in `sources.yaml`.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to this leaf.

- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` (tag `subdomain: programming`).
- [ ] For each: `tier` (T0–T3 = evidence/authority grade), `license_note`, `parser`. Skim once; drop redundancy.
- [ ] **Width = exhaustive:** full sweep across all four sweep modes, multi-hop reference-chasing until dry.

Candidate source **categories** + named authorities (Phase A targets — NOT fetched in this planning pass):

- **T0 — meta-analyses / systematic reviews (the load-bearing layer):**
  - *Volume dose-response:* Schoenfeld, Ogborn & Krieger (2017) weekly-sets meta; Baz-Valle et al.
    volume reviews; Pelland/Nuckols et al. dose-response re-analysis; Krieger set-volume meta.
  - *Proximity-to-failure / RIR:* **Refalo, Helms et al.** proximity-to-failure meta-regression
    (hypertrophy and strength); Grgic failure-vs-non-failure meta; Robinson/Pelland effective-reps work.
  - *Frequency:* Schoenfeld/Grgic/Krieger frequency metas; Grgic frequency-and-strength.
  - *Intensity / load:* Schoenfeld high-vs-low-load hypertrophy meta; Lopez et al. load-and-outcomes
    network meta; strength-specific %1RM dose-response.
  - *Periodization:* Williams et al. periodization-vs-non meta; Grgic autoregulation/APRE reviews.
- **T1 — RCTs in trained subjects:** volume-equated set-number RCTs (e.g. Schoenfeld 2019 1/3/5 sets),
  RIR/failure RCTs (Lacerda, Carroll, Helms-style), frequency RCTs (Yue, Schoenfeld 1×vs3×), deload/
  taper studies. Captured into `studies` with n / training_status / duration.
- **T2 — expert consensus / synthesis (the reconcilers):**
  - **Stronger By Science** (Greg Nuckols) — volume, frequency, failure, periodization articles.
  - **MASS Research Review** (Helms / Nuckols / Zourdos) — the running re-analysis of the above metas.
  - **Helms — *The Muscle & Strength Pyramids* (Training)** — the canonical hierarchy (adherence →
    volume/intensity/frequency → progression → ...). Maps almost 1:1 onto the overload hierarchy.
  - **RP / Mike Israetel** — **MEV/MV/MAV/MRV** landmark framework and per-muscle volume tables; the
    `weekly_sets` min/max/recommended scaffolding comes from here, *graded against the T0 metas.*
  - **Menno Henselmans (Bayesian Bodybuilding)** — frequency, failure, volume critiques.
- **T3 — mechanistic / high-quality practitioner:** effective-reps / motor-unit recruitment explainers,
  SRA-curve and fatigue-management mechanism pieces, well-sourced blog explainers used only to source
  the *practical/mechanistic* half of a split claim (never the effect half).
- **Seed:** reference-chase the Gemini deep-research doc's 51 citations one hop out.

- [ ] **Verify:** `uv run python -m ingest list --domain exercise --subdomain programming` shows N rows; eyeball pass — every load-bearing variable has ≥1 T0/T1 candidate.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain exercise --subdomain programming` → fills `sources`/`documents`, caches raw under `_db/raw/exercise/programming/`.
- [ ] `uv run python -m ingest load --domain exercise` (close the motherduck MCP first — it holds a read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Verify:** doc count + mean length match expectations; spot-check 3 docs render as clean markdown; confirm the Refalo / Schoenfeld-volume / frequency metas parsed with their numeric tables intact (these are the numbers we extract).

## Phase C — Extract → entity tables

Goal: structured rows for the lookup-able entities — here, the parameterized knobs.

- [ ] Extract `training_variables` into `extract/training_variables.json`, one row per scope×key×goal×population cell (see decomposition). Every numeric cell carries `unit`, `evidence_grade`, and resolvable `source_ids`. Use Israetel landmarks as scaffolding **only when graded against a T0 meta**; where they disagree, record the meta value and note the divergence in `description`.
- [ ] Extract `studies` into `extract/studies.json` for each T0/T1 source (design, n_subjects, training_status, duration_weeks, key_finding, effect_summary, citation).
- [ ] Extract `concepts` (MEV/MAV/MRV, RIR, junk volume, density, deload, autoregulation, effective reps, SRA).
- [ ] Land via JSON, then `ingest load`.
- [ ] **Verify:** counts within the depth-profile order-of-magnitude (≈90–140 variables, ≈25–40 studies); every `weekly_sets` muscle scope resolves to a muscle id that exists in `anatomy` (or is flagged for that leaf); sampled rows have resolvable `source_ids`; no row has `evidence_grade=meta-analysis` without a T0 `source_id`.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: the queryable, **evidence-graded** `claims` layer — the de-conflated recommendations a human
couldn't safely pull from one search.

- [ ] Author each recommendation as **one or two `claims` rows**, applying the **KEY METHODOLOGICAL
  RULE**: where an effect and a practical/mechanistic story diverge, split them. Examples this leaf
  MUST land (each with `verdict`, `nuance`, `evidence_grade`, `agreement_score`, `affected_ids`,
  supporting/contradicting `source_ids`):
  - *Volume:* "More weekly sets → more hypertrophy" → **supported but dose-response with diminishing
    returns** (effect, T0); separate practical row on the **junk-volume tail / MRV** and per-session
    ceiling (T2/T3). Strength volume is far less dose-sensitive than hypertrophy (split by goal).
  - *Proximity-to-failure:* "Train closer to failure for more growth" → **small positive effect of
    proximity for hypertrophy, plateauing by ~0–2 RIR; little/none for strength** (effect, T0 Refalo);
    separate practical row: **failure raises fatigue/recovery cost disproportionately → reserve it for
    isolation, keep an RIR buffer on compounds** (mechanistic/T2/T3). Do **not** let the fatigue
    argument inflate the growth claim.
  - *Frequency:* "Higher frequency builds more muscle" → **equivalent for hypertrophy at matched
    volume; modest strength benefit** (effect, T0); practical row: higher frequency is a *vehicle to
    distribute volume under a per-session ceiling*, not an independent grower (T2).
  - *Intensity:* "Heavy is necessary for hypertrophy" → **equivalent growth across ~30–85% 1RM when
    taken near failure** (effect, T0); but **load is goal-specific for strength** (≥~80% for max
    strength) (effect, T0) — two different claims, not one.
  - *Overload hierarchy:* "Add weight to grow" → progressive overload is necessary but the **lever is
    primarily volume/effort accumulation; load is one of several valid progression channels**
    (load > volume > density is a *practitioner ordering*, not an effect ranking) — grade honestly.
  - *Periodization:* "Periodization beats non-periodized" → **small benefit for strength, unclear/likely
    minimal for hypertrophy at matched volume; deloads manage fatigue, not growth per se** (effect vs
    practical split).
- [ ] **Verification = exhaustive:** for every claim, spawn **3–5 independent skeptic agents**, each
  prompted to **refute** it against the literature (specifically: "find the volume-equated / RIR-matched
  / frequency-matched study where the *effect* claim fails"). Keep only **majority-survivors**; set
  `agreement_score` = fraction of verifiers that did **not** refute; **record the dissent verbatim** in
  `nuance`. A claim that fails the majority is kept with `verdict='disputed'`/`'refuted'`, never dropped.
  Load-bearing claims (volume band, proximity-to-failure, frequency) get the full 5 verifiers; uncontested
  rows (rest intervals) get 3.
- [ ] **Adversarial focus = the conflation trap:** every verifier is explicitly told to flag any claim
  that uses a *practical* benefit (fatigue, time, skill) to support an *effect* (growth/strength) verdict.
  That is the failure mode this leaf exists to prevent.
- [ ] **Verify:** sample claims re-derive from their cited sources; the effect/practical split is present
  wherever the seed doc conflated them; contradictions recorded (`contradicting_source_ids` populated),
  not silently dropped; no `claims` row asserts `supported` for growth on the strength of fatigue/time alone.

## Phase E — Relationships → typed graph

- [ ] Wire `evidenced-by` (claim/variable → source), `scoped-to-muscle` (`weekly_sets` → `anatomy.muscles`),
  `governs` (claim → the `training_variables` / `set_structures` it constrains), `depends-on`
  (frequency → session-ceiling → weekly-sets), and `tradeoff`/`antagonizes` (proximity-to-failure ↑
  growth-per-set vs ↑ fatigue-cost) edges — within this leaf and **across** to `anatomy` (muscle scopes),
  `movements` (default_rep_range/default_rir on exercises trace to these variables), `techniques`
  (set structures *deliver* a dose defined here), and `constraints` (session ceiling × recovery,
  failure-cost × the pinky/grip ceiling).
- [ ] **Verify:** a graph walk from `weekly_sets.back.hypertrophy.intermediate` reaches ≥3 sensible hops
  (→ `muscle:back` → exercises that train it → the claim that grades its volume → its T0 source).

## On completion

- [ ] Update `STATUS.yaml` (phases → `done`, `updated:` date) and append a session entry to `PROGRESS.md`.
- [ ] Hand-off note for `routine`: the three knobs the generator reads first are `weekly_sets` (per
  muscle), `session_sets` (the split driver), and the `rir`/failure-cost claim (the compound-vs-isolation
  guardrail). Flag any muscle whose `weekly_sets` row is T2/T3-only (un-meta'd) so the generator can mark
  that prescription lower-confidence.

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- `domains/_shared/sources.yaml` — shared source registry; **many programming sources overlap
  `techniques` and `movements`** (Nuckols/SBS, MASS, Helms, Schoenfeld). Add once, tag subdomains.
- Sibling leaves under `exercise/` — copy their `extract/*.json` shape once authored. `techniques`
  is the closest cousin (also claims-heavy, same authorities) — share the refutation-prompt scaffold.
- `domains/_shared/sessions/depth-profiles.md` (the verification dial) and `extend-playbook.md`
  (resume contract).

## Open questions

- **Goal priority for the lifter:** hypertrophy-primary with a strength floor, or balanced? Sets which
  `goal` cells are load-bearing vs nice-to-have (the hypertrophy/intermediate `weekly_sets` band is the
  default anchor unless told otherwise). Resolve via `AskUserQuestion` in meta-research; does NOT block
  Phase A.
- **Population anchor:** confirm the lifter is `intermediate` (years trained, near-MRV tolerance) so the
  recommended-band rows target the right population.
- **Where Israetel landmarks and the T0 metas disagree** (notably the upper volume tail / MRV and very
  high-volume responders): record both, grade the meta higher, and surface the divergence as a `disputed`
  claim rather than picking a number silently.
- **Units convention** for `intensity_pct1rm` rep-range rows where the source gives reps-to-failure, not
  %1RM — store both `unit` variants or normalize? Decide before Phase C to keep the table queryable.
