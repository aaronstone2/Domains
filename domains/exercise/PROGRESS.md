# exercise — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## Session 0 — 2026-06-24 — Domain bootstrap + engine generalization — DONE

Refocused the corpus engine from interview-prep onto exercise science, and generalized it to be
extensible-as-hell first.

**Engine upgrades (reusable across all future domains):**

- **Auto-discovered domains** — `paths.discover_domains()` scans `domains/` (drops a new folder →
  registered everywhere). Removed the hardcoded `DOMAIN_SCHEMAS` tuple; `k8s` (folderless) correctly
  dropped, `linux`/`firecracker`/`ecs`/`exercise` picked up.
- **Per-domain schema extensions** — `init-db` applies an optional `domains/<d>/schema.<d>.sql` on top
  of the shared base schema. `paths.domain_schema_extension()` + `load.init_db()`.
- **Auto-generated cross-domain wiring** — `init-db` regenerates `queries/cross_domain.sql` (meta.all_*
  views) and `queries/fts_index.sql` from the live domain list; no hand-maintained domain lists.
- **Status manifests** — `pnpm leaf add` now writes `STATUS.yaml` (depth + per-phase state) for
  deterministic resume. `pnpm domain add` now writes a domain README + PROGRESS.
- **Depth profiles + extend playbook** — `_shared/sessions/depth-profiles.md` (scout/standard/exhaustive,
  the verification dial) and `_shared/sessions/extend-playbook.md` (the re-engagement contract). The
  generic `PLAN.template.md` was de-debugging-fied (Phase D = "gold layer", not "failure-modes").

**Exercise domain scaffold:**

- `domains/exercise/` + `schema.exercise.sql` (9 tables: muscles, movement_patterns, exercises,
  substitutions, training_variables, set_structures, claims, studies, constraints).
- 6 leaves scaffolded: anatomy, movements, programming, techniques, constraints, routine.

**Verified:**

- `ingest init-db` succeeded. `exercise` schema has 16 tables (7 base + 9 extension); schemas present:
  devin, docker, ecs, exercise, firecracker, linux, methodology, meta (k8s gone — no folder).
- `cross_domain.sql` + `fts_index.sql` regenerated to include `exercise`; meta views compile.
- `pnpm typecheck` green for cli + harness. CLI leaf scaffolder dogfooded for all 6 leaves.

**Known issue (pre-existing, non-blocking):** the harness's native `duckdb` node dep won't compile
(Node 25, no MSVC). Corpus is fully usable via the duckdb CLI + motherduck MCP. Harness can migrate to
`@duckdb/node-api` (prebuilt binaries) when its exercise commands are built.

**Next:** deepen the 6 leaf PLAN/README (in progress this session). Then per-leaf Phase A source sweep
(exhaustive), starting with `anatomy` + `movements`. Equipment inventory needed before `routine`.

## Session 1 — 2026-06-24 — Phase A survey (anatomy + movements) — DONE

Exhaustive multi-modal source sweep (7 discovery agents across distinct search angles → 2 per-leaf
consolidation/dedup/tier passes), merged deterministically into `domains/_shared/sources.yaml`.

| Leaf | Sources | T0 | T1 | T2 | T3 | redistribute-ok | reference-only | unknown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `anatomy` | 35 | 1 | 8 | 11 | 15 | 19 | 16 | 0 |
| `movements` | 85 | 3 | 14 | 29 | 39 | 16 | 68 | 1 |

- **Validated:** all 120 load via the pydantic `Source` model (`ingest list --domain exercise` → 120).
- 1 duplicate URL auto-skipped during merge. Per-leaf provenance (with tier/license rationale +
  coverage_notes) saved to `domains/exercise/<leaf>/extract/sources.json`.
- `anatomy` is weighted T1/T2 (OpenStax/LibreTexts CC-BY anatomy + StatPearls + EMG/moment-arm PMC for
  the contested claims). `movements` came in broad (85 vs 28–50 target) and skews T3/reference-only
  (ExRx/MuscleWiki/practitioner pages) — fine at registry stage; Phase B will fetch in tier order.
- STATUS for both leaves: `meta_research: done`, `a_survey: done`.

**Next:** Phase B (ingest → documents + FTS). Suggest fetching T0–T2 first (redistribute-ok freely
ingested; reference-only ingested to the private corpus, cite-only), then T3 selectively.

## Session 2 — 2026-06-24 — Phase B ingest, tier-gated T0–T2 (anatomy + movements) — DONE

Fetched + loaded the T0–T2 tier (66 sources) → **57 documents** in `exercise.documents`, BM25 FTS built.

| Leaf | T0–T2 ingested | blocked | T3 deferred | avg chars | thin (<800) |
|---|---:|---:|---:|---:|---:|
| `anatomy` | 19 / 20 | 1 | 15 | 43,234 | 0 |
| `movements` | 38 / 46 | 8 | 39 | 49,171 | 0 |

- **FTS verified:** "soleus gastrocnemius knee angle" → top-5 are the exact gastroc-vs-soleus PMC papers;
  "lifting straps grip deadlift" → the straps-bench-pull study + SBS grip/deadlift guides. Retrieval is sound.
- Content is rich (avg ~43–49k chars, 0 thin/nav-junk docs).

**Pipeline fixes landed this session (reusable across all domains):**
1. **`--max-tier` filter** on `ingest list`/`fetch` (`_TIER_RANK`) — enables tier-gated ingest (T0–T2 first).
2. **Browser User-Agent** in `fetch.py` — the bot UA was getting 403'd by journal/blog hosts; recovered
   3 of the first 13 failures (oregonstate, a humankinetics EMG, the 38k-char lifting-straps systematic review).
3. **Upsert FK fix** in `load.py` — `INSERT OR REPLACE` (delete+reinsert) violated the
   `documents.source_id → sources.id` FK on any re-load; switched to in-place `ON CONFLICT DO UPDATE`.
   Validated by re-loading 54→57 with no FK error.

**Deferred to a Phase-1.5 gap-patch (9 still-blocked T0–T2 — hard paywalls / Cloudflare, need PMC mirror or playwright):**
`exercise-anatomy-tandf-triceps-overhead-hypertrophy`, `exercise-movements-{peerj-moment-arm-model,
emg-pec-nonuniform, sysrev-varying-exercises, trial-varying-exercises, straps-deadlift,
straps-deadlift-females, straps-latpulldown, startingstrength-hook-vs-straps}`. Several EMG/sys-review
papers likely have open-access PMC versions — swap the publisher URL → PMC and re-fetch.

**Next:** Phase C extraction — `anatomy.muscles` (the every-muscle backbone, freezes `muscle.id`) then
`movements.{movement_patterns, exercises, substitutions}` from the 57 ingested docs.

## Session 3 — 2026-06-24 — Phase C: `anatomy.muscles` — DONE (muscles)

Dumped 19 anatomy docs to gitignored `anatomy/raw/scratch/`, ran 6 region specialists (back /
chest-shoulder / arms-forearms / core / legs-upper / legs-lower) → merge pass that dedups, freezes
the `exercise.muscle.<slug>` id namespace, wires antagonists, and runs a completeness check.

**Result: 58 muscles** loaded into `exercise.muscles` (`extract/muscles.json` committed).

| group | n | group | n | group | n |
|---|--:|---|--:|---|--:|
| back | 8 | forearms | 6 | hamstrings | 3 |
| shoulders | 8 | core | 5 | hip-flexors | 3 |
| arms | 7 | quads | 4 | adductors | 2 |
| calves | 6 | glutes | 3 | chest | 2 / shins 1 |

**Verified:** 13 biarticular muscles all carry `length_bias` (gastroc knee-extended, soleus mono,
rectus-femoris hip-extended, hamstrings hip-flexed, biceps/triceps long heads, finger-flexors
wrist-extended); **0 dangling antagonist_ids, 0 unresolved source_ids**; `exercise.muscle.finger-flexors`
("crush-grip group") present = the **pinky-gate anatomy endpoint**. Merge collapsed 3 rotator-cuff
duplicates + canonicalized the deltoid head ids (back vs shoulder agent naming clash) and repaired all
cross-refs. No completeness gaps; deep/minor muscles folded into parent `heads[]`/notes per granularity rule.

**Extension-table load:** muscles.json → `exercise.muscles` via `read_json_auto` + `INSERT BY NAME`
(the base `ingest load` only handles sources/documents; extension tables load via duckdb directly —
a generic `load --table` command is a future engine nicety).

`anatomy` STATUS: `c_extract: partial` (muscles done + id frozen; `concepts` + Phase D `claims` pending).

**Next:** Phase C `movements` — `movement_patterns` → `exercises` (movers cite the now-frozen muscle ids)
→ `substitutions`. This is the largest extraction (target ~120–200 exercises). Then the contested-anatomy
`claims` (Phase D) can reuse the EMG papers already ingested.

## Session 4 — 2026-06-25 — Phase C: `movements` patterns + exercises — DONE (lib)

Dumped 38 movements docs + the 58 frozen muscle ids to scratch. Workflow: 1 pattern-taxonomy agent +
11 category specialists (chest / back-vertical / back-horizontal / shoulders / biceps-triceps /
forearms-grip / quads / hamstrings-hinge / glutes / calves / core) → all succeeded. The final
LLM merge agent **looped on schema-validation** of the 210×22-field payload (session-limit interruption
+ a fragile single giant structured output) — stopped it and recovered deterministically: pulled the 11
cached category results from the run journal and **merged/validated/normalized in Python**.

**Result: 27 movement_patterns + 209 exercises** loaded (`extract/movement_patterns.json`, `exercises.json`).

**Verified:** 0 invalid mover refs (every primary/secondary mover resolves to `exercise.muscles`); 0 unknown
`movement_pattern_id`; 48 fixed-core / 161 dynamic-accessory; **130 exercises carry `grip_pattern_tags`**
(pinky-gate join populated); 1 stray source ref (minor). Patterns by load: horizontal-push 20, horizontal-pull
19, vertical-pull 18, hip-hinge 13, spinal-flexion 13, plantarflexion-knee-straight 12, ...

**Gap notes (Phase 1.5 candidates):** 17 muscles are primary-mover of zero exercises — mostly true
stabilizers (rotator cuff, serratus, popliteus, anconeus, plantaris, TFL), but adductors
(`adductor-longus-brevis`) and shoulder external rotators (`teres-minor`/`subscapularis`) and
`serratus-anterior` could use 1–2 dedicated exercises.

**Lesson applied:** avoid one giant single-agent structured-output merge; prefer bounded per-group agents
+ deterministic Python merge. C2 (substitutions) will follow that pattern.

`movements` STATUS: `c_extract: partial` (patterns + exercises done; `substitutions` next).

## Session 5 — 2026-06-25 — Phase C: `movements.substitutions` — DONE

8 bounded pattern-group agents (push/pull/quads/posterior/delts/arms/grip/calves-core) emitted swap
edges; recovered from the run journal + merged/validated in Python (lesson from Session 4 applied — no
giant single-agent merge).

**Result: 292 substitution edges** loaded (`extract/substitutions.json`): 221 `equipment-unavailable`
+ 71 `injury-spare` (grip-bypass). 0 dropped, 0 dangling, 0 self-loops; avg equivalence 0.76.

**Coverage guarantee met:** only **1/83** machine/cable/smith exercises lacks an equipment swap; only
**1/40** high-grip exercises lacks a grip-bypass. The no-machine-swap + pinky grip-bypass requirements
are now realized data.

`movements` STATUS: `c_extract: done` (patterns + exercises + substitutions); `e_relationships: partial`.

## Session 6 — 2026-06-25 — programming + techniques A→C — DONE

- **Phase A:** swept + merged 111 sources (programming 69 incl. 32 T0 metas + 13 T1 RCTs; techniques 42).
- **Phase B:** ingested T0–T2 → programming 50 docs, techniques 25 docs (31 paywalled blocked; load-bearing
  metas came via PMC/SportRxiv/repository mirrors). Corpus now 132 docs + FTS.
- **Phase C:** 6 variable-agents + 1 set-structure agent (bounded; journal recovery + Python merge) →
  **103 training_variables** (frequency 19, weekly_sets 18, rir 15, rest 14, load 13, overload 12, rep_range 5,
  session_sets 3, meso 2, deload 2; grades: 53 meta-analysis / 32 expert / 16 RCT / 2 mechanistic) +
  **13 set_structures** (RPT, pyramids, drop/rest-pause/myo-reps/cluster, supersets). 0 unresolved citations.

programming + techniques STATUS: `c_extract: done`. Next: Phase D `claims` (adversarial verification).

## Session 7 — 2026-06-26 — Phase D: adversarially-verified `claims` — DONE

3 generators produced 22 contested claims (across programming/techniques/contested-anatomy). The full
3-refuter-per-claim design (80 agents) hit the session rate-limit twice; recovered the 22 candidates from
the journal and ran a **lean verification** (6 agents × ~4 claims, steelman both sides + the effect-vs-practical
rule). Loaded into `exercise.claims` (`techniques/extract/claims.json`).

**Verdict distribution (the payoff): 9 disputed · 6 equivalent · 5 refuted · 2 supported** (avg agreement
0.27; grades 14 meta-analysis / 6 RCT / 2 mechanistic). The deep-research doc's "X is superior" claims were
systematically downgraded with the dissent recorded — frequency & advanced-techniques → equivalent at matched
volume; rest-pause/volume-monotonicity/hip-thrust-glute/lengthened-partials → disputed (one flagged a corpus
evidence-gap honestly). This is the auditable evidence base the whole project exists to produce.

anatomy/programming/techniques STATUS: `d_gold: done`.

**Note:** the rigorous 3-independent-refuter version can be re-run later to upgrade agreement_scores; the lean
pass already enforces the effect-vs-practical separation.

## Session 8 — 2026-06-26 — Completion pass (no deferrals) — DONE

Closed every deferral/optional/gap so all 4 research leaves are fully `done`:
- **G1 full ingest:** all tiers fetched → **168 docs** (was 132). 63 hard-paywalled = cite-only (mostly
  duplicate-of-record; OA mirror already ingested). All `b_ingest: done`.
- **G2 muscle gap-fill:** +5 patterns, +24 exercises (rotator cuff ER/IR, serratus, adductors, abduction,
  ankle) + 2 synergists patched as secondaries → **0 muscles untrained** (every muscle ≥1 primary-or-secondary).
- **G3 concepts:** **81-concept glossary** (principles/mechanisms/metrics/phenomena/methods/myths). anatomy `c_extract: done`.
- **G4 movements claims:** +24 regional-bias/exercise-selection claims (steelman + effect-vs-practical) → **46 claims**. movements `d_gold: done`.
- **G5 relationships:** deterministic projection from typed columns → **2291 edges** (assists 858, targets 463,
  substitutes 302, governs 275, instance-of 233, antagonist-of 160). All `e_relationships: done`.
- **Swap top-up:** +10 auto-derived swaps for the new exercises → **302 substitutions**.

**G6 validation (final):** 0 dangling movers / patterns / substitutions; 0 untrained muscles; 0 training_vars
or claims without a source; 0 dangling concept sources. **3 documented exceptions** (not gaps): `dead-hang`
(a grip exercise — bypass would defeat it), `full-can-raise` + `scapular-dip` (unique-primary accessories with
no same-pattern same-prime-mover sibling). Claims verdicts: 17 disputed / 15 supported / 8 refuted / 6 equivalent.

## Session 9 — 2026-06-26 — Rigorous Phase D (3-vote) — DONE

Re-ran the gold layer with the rigor that twice tripped the rate-limit — but via a token-efficient
**diverse-skeptic-panel**: 3 independent lenses (volume-equation / outcome-not-proxy / trained-subject-quality)
each judging all 46 claims, then 3-vote synthesis. 10 agents, no limit hit (vs ~184 for per-claim-3-refuter).

**Hardening (lean → rigorous):** supported 15→7 · equivalent 6→5 · disputed 17→15 · refuted **8→19**.
17 verdicts changed, almost all downgrades — the panel demoted regional-bias claims resting on EMG/activation
rather than measured growth (incline→upper-pec, deep-squat→leg-growth → disputed; hip-thrust glute-superiority,
drop-sets-more-muscle → **refuted**). `agreement_score` is now a true 3-vote tally (0.0: 26 claims, 0.33: 13, 0.67: 7).

OA-mirror chase for the 31 blocked load-bearing T0/T1 primaries: in progress.

## Session 10 — 2026-06-26 — Multi-gym equipment profiles + 290 Revolution — DONE

Added **per-gym equipment profiles** (user request: tie equipment to specific gyms, store many) with a
properly **typed load algebra** (user pushed back on the first text-field draft — rightly). Schema:
`exercise.gyms` + `exercise.gym_equipment` (loading_model ∈ arithmetic|discrete|plate-loaded|bodyweight|none,
with min/max/increment_lb, bar_weight_lb, weights_lb[], station, corpus_equipment, available, est) +
`exercise.gym_plates` (denomination → pair_count). A `gym_loadable` VIEW enumerates every achievable weight
per implement (plate-loaded bars derive min/inc/max from gym_plates). Profiles live as JSON in
`exercise/routine/gyms/<id>.json`; a new gym = a new file.

**Algebra now queryable:** max DB (75), nearest settable load to a target (47→45), barbell membership
(makes 95, not 92.5), implements that hit exactly 50 lb, cross-gym capability queries. `est=true` flags the
values still to measure (selectorized stack ranges, kettlebell weights, exact plate counts).

**First profile: `gym.290-revolution-drive-somerville`** (default) — commercial-grade Precor + Escape apartment
gym, inventoried from 28 photos (ffmpeg HEIC→JPG, 4 vision agents → synthesis). 47 equipment rows / 38 available:
Precor selectorized (lat-pulldown/seated-row, leg-ext/curl, multi-press), Precor **FTS Glide** functional trainer
(+ cuffs that work for wrist → **pinky/wrist grip-bypass confirmed**), Precor Smith, half-rack + Olympic bar +
plates (2.5-55), DBs **5-75/5**, fixed bars 20-60/10, kettlebells/corebags, benches (incline yes, decline no),
VKR/dip, extensive cardio. **Absent:** leg-press, hack, pec-deck, preacher, calf-machine, 45/GHD back-extension, bands.

**Coverage @ 290 Revolution:** 233 exercises → **198 directly doable**, 35 need substitution; after adding 13
band→cable/cuff swaps (+absent-machine swaps), **33/35 have a swap edge**. Remaining 3 = 2 heuristic
false-positives (bodyweight/DB, actually doable) + 1 band-only (tibialis raise). Effective coverage ≈ full.
Back-extension absence covered by free-weight hinge (RDL/good-morning) + loaded carries (KB/corebag/DB) — fits the
lower-back priority without a GHD. Substitutions now 315.

## Session 11 — 2026-06-26 — Constraints + ROUTINE generated (THE deliverable) — DONE

- **constraints leaf:** upgraded the table to typed trigger columns (provoking_patterns / joint_stress / grip_tags +
  red_flags + intake_questions). Authored a **41-entry general contraindication library** (5 regional clinical agents:
  shoulder/elbow-wrist/low-back/hip-knee/ankle-neck-systemic) + encoded Mark's **5 active personal constraints**
  (lower-back = priority weak-point build; shoulder painless-crepitus; wrist tendinopathy; TMJ cue; left-pinky temporary).
  Matching verified: pinky flags 89 grip-loaded exercises, shoulder 5 (overhead only), wrist 12 (direct wrist), back 0
  (priority, not a gate), TMJ 0 (cue). All `done`.
- **routine generator:** extracted a brief (215 available-at-290 exercises by muscle + volume/loading/claims/load-algebra),
  ran architect → 3 session-designers → mesocycle → assembled **`domains/exercise/routine/ROUTINE.md`**.

**Result: a balanced 6-day PPL×2 + dynamic mesocycle**, every exercise with real achievable loads (DB 5-75, Olympic
plate-loaded, Smith, Precor selectorized), sets×reps×RIR×rest, set-structure (used for time-efficiency NOT 'more growth'),
per-exercise constraint accommodations, and **citations to the verified claims** — including citing refuted claims to say
what NOT to lean on (hip-thrust-superiority, incline-region-targeting). 42 exercise slots, **0 hallucinated** (all resolve
to corpus ids). Lower-back/core prioritized; heavy hinge Wed→Thu-rest; autoregulation for the variable sport load.

### THE VISION IS REALIZED
The queryable algebra of verified training facts (anatomy → movements → programming → techniques, A→E, adversarially
verified) + a typed equipment load-algebra + a general+personal constraints layer → **generated a personalized,
evidence-cited, constraint-routed, gym-specific routine.** Regenerable on any input change. Future domains
(nutrition / assessment-DEXA / recovery / health) are scoped in `_shared/ROADMAP.md`.

### RESEARCH LAYER COMPLETE (all 4 leaves A→E done)
**58 muscles · 32 patterns · 233 exercises · 302 substitutions · 103 training_variables · 13 set_structures ·
46 verified claims · 81 concepts · 2291 relationships · 168 docs + FTS · 231 sources.**
Known scope limits (accepted): 63 paywalled sources are cite-only (mirrors used for load-bearing); Phase D
used a lean 6-agent verification (the rigorous 3-independent-refuter pass can re-run to sharpen agreement_scores);
a few near-duplicate concepts. **Remaining: `constraints` (pinky + equipment profile) + `routine` generator** —
both need the lifter's gym equipment inventory.

### Corpus state after Session 5
`exercise.muscles` 58 · `movement_patterns` 27 · `exercises` 209 · `substitutions` 292 · plus 57
ingested docs + BM25 FTS. Remaining: `programming` + `techniques` (A→D), Phase D `claims`
(anatomy/programming/techniques), `constraints` (pinky + equipment profile), `routine` generator.
Small gap-fills: 17 primary-mover-zero muscles (mostly stabilizers; adductors/ext-rotators/serratus
worth a few exercises), 1 stray exercise source ref, 9 blocked T0–T2 sources (PMC-mirror patch).
