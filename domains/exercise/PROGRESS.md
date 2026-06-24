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
