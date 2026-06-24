# Plan — `exercise/anatomy`

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> Depth for this leaf: **exhaustive** (set in `STATUS.yaml`). This leaf is the coverage backbone — the
> "hit EVERY muscle" gap-analysis the whole generator depends on runs against the rows produced here,
> so it gets the full sweep and adversarial verification. See
> `domains/_shared/sessions/depth-profiles.md`. The re-engagement contract is
> `domains/_shared/sessions/extend-playbook.md`.

## Context

Why this leaf exists: `anatomy` is the **enumeration of every trainable muscle and muscle head** the
training program must stimulate, plus the kinesiology that makes each one *targetable*. It is the
domain's coverage axis: the routine generator can only assert "every muscle is hit" if there exists a
complete, canonical muscle list to check against. The corpus must answer, from these rows: *what are
all the muscles I have to train?*; *what does muscle X do (actions/planes/joints)?*; *is it biarticular,
and at what joint-angle is it placed under stretch?* (so an exercise can bias its long-length —
e.g. gastrocnemius is loaded knee-**straight**, soleus knee-**bent**; rectus femoris stretches
hip-extended/knee-flexed; the hamstrings as hip-extensors vs knee-flexors); *what is its antagonist?*
(so push/pull balance and antagonist-paired supersets resolve). This leaf carries **no programming
opinion** — it is descriptive anatomy/kinesiology only; the load-bearing "should" claims live in
`programming`/`techniques`. Its one strong correctness bar is *completeness*: an anatomical gap here
silently becomes an untrained muscle in the final routine.

How it composes: `anatomy` is the **root** of the leaf dependency graph (`anatomy → movements →
routine`). `movements` references `muscles.id` from its `primary_muscle_ids` / `secondary_muscle_ids`
arrays, so the muscle id namespace (`exercise.muscle.<name>`) is **frozen here** and every downstream
leaf depends on it being stable and complete. `routine` runs its muscle-coverage / volume gap-analysis
by left-joining prescribed sets back onto this table. `constraints` uses `antagonist_ids` and
`length_bias` indirectly (e.g. grip-bypass reasoning touches forearm flexors/extensors enumerated here).
Cross-domain links are wired in Phase E as discovered — chiefly the `targets` edge muscle↔exercise and
the `antagonist-of` edge muscle↔muscle.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the domain-specific tables in `domains/exercise/schema.exercise.sql`.

This leaf fills (depth = exhaustive → "all tables + every named entity in-scope"):

| Table | What this leaf writes | Row target |
|---|---|---|
| `muscles` | One row per trainable muscle **or distinct head** that warrants independent programming: `name`, `muscle_group`, `region`, `heads[]`, `primary_actions[]`, `planes[]`, `joints_crossed[]`, `biarticular`, `length_bias`, `antagonist_ids[]`, `notes`, `source_ids[]`. | **~55–75 rows** (see enumeration below) |
| `relationships` | `antagonist-of` (muscle↔muscle), `synergist-of` / `part-of` (head→parent group where a head row coexists with a group row), and `region-member` groupings. (`targets` muscle↔exercise edges are *authored in `movements`*, not here, but the muscle endpoints are defined here.) | ~60–100 edges |
| `concepts` | Kinesiology vocabulary the other leaves reuse: the six anatomical **actions** per joint, the three **planes**, **biarticular / active vs passive insufficiency**, **length-tension / regionalization**, **antagonist pairing**. | ~15–25 |
| `sources` / `documents` | The anatomy/kinesiology references behind every row (Phase A/B). | ~12–25 sources |
| `studies` | Only where a *contested anatomical claim* leans on a specific paper (e.g. regional hypertrophy / architecture EMG/MRI studies — biceps long vs short, the four-headed biceps femoris debate, hamstring regional activation). Most rows cite textbook/atlas sources, not `studies`. | ~5–12 |
| `claims` | The handful of **genuinely contested anatomical facts** (not programming claims): e.g. "the lat has functionally independent regions you can bias by arm path", "rectus femoris is a poor knee-extender at long hip angles (active insufficiency) so it needs hip-extended work", "the soleus is trainable largely independently of gastroc via knee flexion". Programming-laden claims belong to other leaves. | **~6–12 rows** |

Tables this leaf does **not** fill: `exercises`, `movement_patterns`, `substitutions`,
`training_variables`, `set_structures`, `constraints`.

### Enumeration to land in `muscles` (the completeness contract)

Grouped by region; each entry is a row (a head is its own row when it earns independent programming).
This list **is** the acceptance target — Phase D verifies nothing in a standard kinesiology muscle
list is missing from it.

- **BACK / posterior chain:** latissimus dorsi, teres major, teres minor, rhomboids (major+minor),
  trapezius — upper, trapezius — middle, trapezius — lower, levator scapulae, erector spinae
  (iliocostalis/longissimus/spinalis as a group, optionally split), serratus posterior (note-level),
  infraspinatus, supraspinatus, subscapularis (rotator cuff). *(Serratus anterior sits at the
  scapula — grouped chest/shoulder by convention; placed once, cross-noted.)*
- **CHEST:** pectoralis major — clavicular (upper), pectoralis major — sternocostal (mid/lower),
  pectoralis major — abdominal/costal head (note or row), pectoralis minor, serratus anterior.
- **SHOULDERS:** deltoid — anterior, deltoid — lateral/middle, deltoid — posterior. (Rotator cuff
  listed under BACK above; cross-noted to shoulders.)
- **ARMS — elbow flexors/extensors:** biceps brachii — long head, biceps brachii — short head,
  brachialis, coracobrachialis (note-level), triceps brachii — long head, triceps brachii — lateral
  head, triceps brachii — medial head, anconeus (note-level).
- **FOREARMS:** brachioradialis, wrist flexors (flexor carpi radialis/ulnaris, palmaris longus —
  as a functional group), wrist extensors (extensor carpi radialis longus/brevis, extensor carpi
  ulnaris — group), pronator teres/supinator (note-level), finger flexors (flexor digitorum
  superficialis/profundus — **grip/crush group, flagged for the left-pinky constraint**).
- **CORE:** rectus abdominis, external oblique, internal oblique, transversus abdominis,
  quadratus lumborum (QL). *(Erector spinae already under BACK; cross-noted as a core/anti-extension
  antagonist.)*
- **LEGS — quads:** rectus femoris (biarticular), vastus lateralis, vastus medialis, vastus
  intermedius. **Hamstrings:** biceps femoris — long head, biceps femoris — short head (note: short
  head is monoarticular), semitendinosus, semimembranosus. **Glutes:** gluteus maximus, gluteus
  medius, gluteus minimus. **Adductors:** adductor magnus (+longus/brevis, gracilis, pectineus as a
  functional adductor group). **Hip flexors:** iliopsoas (psoas major + iliacus), tensor fasciae latae
  (TFL) — note-level. **Calves / lower leg:** gastrocnemius (biarticular — knee-straight bias), soleus
  (knee-bent bias), tibialis anterior, fibularis/peroneals (note-level), tibialis posterior (note-level).

(Note-level entries may be folded into a parent group row rather than getting a standalone id, at the
extractor's discretion — but the parent row must carry them in `notes`/`heads[]` so nothing is lost.)

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — Kenhub's muscle index /
A–Z, Physiopedia's muscle category tree, ExRx muscle directory, the muscle list in a standard
kinesiology text's table of contents; goal is to build the *master muscle checklist* the extraction
will be measured against. (2) **Plan** agent(s) lock the `muscles.id` namespace
(`exercise.muscle.<slug>`), decide the head-vs-group split rule (a head gets its own row iff a
real exercise can bias it independently — clavicular pec, three delts, biceps heads, gastroc vs soleus,
upper/mid/lower traps — otherwise fold into the parent), and design the field-by-field extraction map.
(3) `AskUserQuestion` on the only real fork: **granularity** — do we split erector spinae / forearm
flexor-extensor groups / adductors into individual muscles, or keep functional groups? (Default:
functional groups except where a head is independently trainable.) (4) write this PLAN + `STATUS.yaml`;
(5) `ExitPlanMode`.

The irreducible work here is **completeness verification** (Phase D adversarial gap-finding), not claim
adjudication — this leaf has few contested claims. The meta-research exists to make sure the master
checklist the gap-analysis runs against is itself complete before we trust it.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list of **anatomy/kinesiology** references — enough to
cite every field of every muscle row, with at least two independent authorities behind any contested
fact.

- [ ] Add per-leaf entries to `domains/_shared/sources.yaml` under subdomain `anatomy`.
- [ ] Candidate source **categories** + named authorities (tier them on capture):
  - **Anatomy reference atlases / encyclopedias (T2):** Kenhub (muscle pages: origin/insertion/action/
    innervation), Physiopedia (muscle category + per-muscle pages), TeachMeAnatomy, Gray's Anatomy /
    Anatomy & Physiology open texts (e.g. OpenStax A&P muscle chapters).
  - **Exercise-science muscle directories (T2/T3):** ExRx.net muscle directory (muscle → exercises),
    Muscle & Motion (functional/biomechanical explainers), Strength & conditioning kinesiology texts
    (Neumann *Kinesiology of the Musculoskeletal System*; Hamilton/Luttgens *Kinesiology*; *NSCA
    Essentials* muscle anatomy chapter).
  - **Primary literature, only for the contested anatomical claims (T0/T1):** regional hypertrophy /
    muscle-region activation studies (e.g. biceps long-vs-short, triceps long-head at stretch, lat
    regionalization, hamstring biceps-femoris-long vs semitendinosus EMG/MRI, rectus femoris
    architecture). These back `claims`, not the descriptive rows.
- [ ] For each: `tier` (T0–T3 = evidence/authority grade), `license_note` (Kenhub/Muscle&Motion are
      proprietary — store metadata + our own paraphrase, not copied figures; OpenStax is CC-BY),
      `parser`. Skim once; drop redundancy (two atlases agreeing on origin/insertion is one citation,
      not two).
- [ ] Width = **exhaustive**: full sweep across all of the above + reference-chase the kinesiology-text
      muscle list one hop until the master checklist stops gaining new muscles.
- [ ] **Verify:** `uv run python -m ingest list --domain exercise --subdomain anatomy` shows N rows;
      eyeball that every region (back/chest/shoulders/arms/forearms/core/legs) has ≥1 anchor authority.

## Phase B — Ingest → `documents` + FTS

- [ ] `uv run python -m ingest fetch --domain exercise --subdomain anatomy` → fills
      `sources`/`documents`, caches raw under `_db/raw/exercise/anatomy/<id>.html`.
- [ ] `uv run python -m ingest load --domain exercise` (close the motherduck MCP first — it holds a
      read lock).
- [ ] Rebuild FTS: `duckdb _db/knowledge.duckdb < domains/_shared/queries/fts_index.sql`.
- [ ] **Verify:** doc count + mean length match expectations; spot-check 3 muscle pages (one big mover,
      one small/heads case, one leg muscle) render as clean markdown with origin/insertion/action intact.

## Phase C — Extract → entity tables

Goal: one `muscles` row per in-scope muscle/head, every field filled, every row source-cited.

- [ ] Extract `muscles` → `extract/muscles.json` following the schema column order; then `ingest load`.
      Per row, fill: `id` (`exercise.muscle.<slug>`), `name`, `muscle_group`, `region`, `heads[]`,
      `primary_actions[]` (canonical action vocabulary — flexion/extension/abduction/adduction/
      internal-rotation/external-rotation/plantarflexion/dorsiflexion/etc.), `planes[]`,
      `joints_crossed[]`, `biarticular`, `length_bias` (the **stretch-position** note — the field that
      makes a muscle targetable: gastroc knee-straight, soleus knee-bent, rectus femoris hip-extended/
      knee-flexed, long-head triceps shoulder-flexed, hamstrings hip-flexed at the knee-extended end),
      `antagonist_ids[]`, `notes`, `source_ids[]`.
- [ ] Land `concepts` (planes, actions, biarticular, active/passive insufficiency, length-tension,
      regionalization, antagonist pairing) so downstream leaves reference one canonical definition.
- [ ] **Verify:** row count within **~55–75**; every row has ≥1 resolvable `source_id`; every
      `antagonist_ids[]` entry resolves to a real `muscles.id` (no dangling antagonist); every
      biarticular muscle has a non-null `length_bias`.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: for THIS leaf the gold layer is **(a) completeness** and **(b) the few contested anatomical
claims** — verified adversarially because depth = exhaustive.

- The "fact" here is unusual: the primary verified artifact is the **master muscle checklist itself**
  (is the enumeration complete?), plus a small `claims` set for the genuinely-disputed anatomy.
- [ ] **Completeness gold (the headline):** spawn **3–5 independent skeptic agents**, each handed a
      *different* canonical muscle list (Kenhub index, Physiopedia tree, ExRx directory, a kinesiology
      text's muscle list, Gray's/OpenStax) and prompted to **find a trainable muscle/head our `muscles`
      table is missing or mis-grouped**. Any muscle ≥1 skeptic flags is adjudicated: add it, fold it
      with a `notes` justification, or record why it's out of scope (e.g. deep intrinsic spinal muscles
      not independently trainable). The gap-analysis the routine generator runs is only trustworthy
      once a majority of skeptics fail to find a missing muscle.
- [ ] **Claims gold:** for each contested anatomical `claims` row (lat regionalization; rectus femoris
      active insufficiency at long hip angles; soleus-vs-gastroc independence via knee flexion; biceps
      long-vs-short head bias by grip/arm path; triceps long-head needing overhead stretch; biceps
      femoris-long vs semitendinosus regional bias), spawn **3–5 skeptics each prompted to refute**
      against the literature. Keep majority-survivors with `verdict` (supported/equivalent/disputed/
      refuted), record dissent in `nuance`, set `evidence_grade` + `agreement_score`, cite
      supporting/contradicting `source_ids`. Apply the **methodological rule**: a regionalization
      *exists/EMG-differs* claim (mechanistic/measurement, T2/T3) is kept **separate** from any
      *you-should-train-it-separately* programming implication (which is deferred to `movements`/
      `programming`, not asserted here).
- [ ] **Verify:** sampled muscle rows re-derive their action/plane/length-bias from cited sources;
      every `claims` row has both supporting and (where they exist) contradicting `source_ids`;
      no contested claim is silently dropped — disputes are recorded with `disputed` verdict.

## Phase E — Relationships → typed graph

- [ ] Wire, exhaustively (depth = exhaustive → "exhaustive in- and cross-domain edges"):
  - `antagonist-of` for every muscle pair (biceps↔triceps, quads↔hamstrings, pecs↔mid-traps/rhomboids/
    rear-delt, anterior↔posterior delt, tib-anterior↔calves, abs↔erectors, hip-flexors↔glutes,
    wrist-flexors↔wrist-extensors).
  - `part-of` / `head-of` from each head row to its parent group (clavicular pec → pec major; the three
    delt heads → deltoid; biceps/triceps heads; gastroc/soleus → triceps surae; the vasti + rectus
    femoris → quadriceps).
  - `region-member` groupings (region → muscles) so the coverage query can roll up by region.
  - Stub the **cross-leaf** `targets` endpoints (muscle ← exercise) so `movements` can attach to a
    stable id, but author those edges in `movements`.
- [ ] **Verify:** a graph walk from a seed (e.g. `exercise.muscle.gastrocnemius`) reaches ≥3 sensible
      hops (gastroc → antagonist tibialis-anterior → region lower-leg → soleus → triceps-surae group).

## On completion

- [ ] Update `STATUS.yaml` (phases → `done`, `updated:` date) and append a session entry to
      `PROGRESS.md` noting final muscle row count, any folded/out-of-scope muscles, and which `claims`
      ended `disputed`.
- [ ] Announce to downstream: the `exercise.muscle.<slug>` id namespace is **frozen**; `movements` may
      now reference it. Flag the grip/crush finger-flexor group as the muscle endpoint the
      `constraints` left-pinky logic keys off.

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities.
- `domains/exercise/schema.exercise.sql` — the `muscles` column contract (authored here first, so no
  sibling has an `extract/*.json` shape to copy yet — **this leaf sets the precedent** for the others).
- `domains/_shared/sessions/{depth-profiles,extend-playbook}.md` — depth dial + resume contract.

## Open questions

- **Granularity fork** (resolve in meta-research `AskUserQuestion`): split erector spinae into
  iliocostalis/longissimus/spinalis, forearm flexors/extensors into named muscles, and the adductor
  group into magnus/longus/brevis/gracilis/pectineus — or keep functional groups? Default = functional
  groups, with a standalone row only where a real exercise biases a part independently.
- Is `serratus anterior` / rotator cuff in *programming scope* for a hypertrophy PPL, or
  enumerate-only? (Enumerate now; let `routine` decide whether to prescribe direct work.)
- Confirm the canonical `primary_actions[]` vocabulary so `movements` can match exercises to muscles by
  action without string drift (freeze the verb list as a `concepts` entry).
- Does any contested regional-hypertrophy claim need a `studies` row, or do textbook citations suffice?
  (Decide per claim in Phase D; prefer T0/T1 for anything load-bearing on the routine.)
