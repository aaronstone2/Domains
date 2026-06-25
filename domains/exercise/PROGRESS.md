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

### Corpus state after Session 5
`exercise.muscles` 58 · `movement_patterns` 27 · `exercises` 209 · `substitutions` 292 · plus 57
ingested docs + BM25 FTS. Remaining: `programming` + `techniques` (A→D), Phase D `claims`
(anatomy/programming/techniques), `constraints` (pinky + equipment profile), `routine` generator.
Small gap-fills: 17 primary-mover-zero muscles (mostly stabilizers; adductors/ext-rotators/serratus
worth a few exercises), 1 stray exercise source ref, 9 blocked T0–T2 sources (PMC-mirror patch).
