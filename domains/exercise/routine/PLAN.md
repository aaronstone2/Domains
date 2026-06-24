# Plan — `exercise/routine` (the generator)

> Per-leaf research plan. Open this in a plan-mode session **inside the leaf directory** and run the
> meta-research ritual before executing. Track machine-readable phase state in `STATUS.yaml` and the
> narrative log in `PROGRESS.md` next to this file.
>
> Set **depth** (`scout` | `standard` | `exhaustive`) in `STATUS.yaml` — it governs how wide each
> phase fans out and how hard the gold layer (Phase D) is verified. See
> `domains/_shared/sessions/depth-profiles.md`. The re-engagement contract (how a future session
> resumes this leaf) is `domains/_shared/sessions/extend-playbook.md`.
>
> **Depth: `standard`.** This leaf is a SYNTHESIS / GENERATOR leaf, not a source sweep. Its phases are
> inverted relative to the research leaves: A/B/C are *near-degenerate* (it consumes already-ingested
> sibling tables rather than fetching the web), and the weight lands on **D (assemble + verify the
> routine)** and **E (the traceability graph that makes every prescribed cell cite a fact)**. "Standard"
> here means: one spot-check pass over the gap analysis and one adversarial self-consistency pass over
> the emitted routine — not the 3–5-skeptic refutation gauntlet the exhaustive research leaves run
> (those already paid that cost for the `claims` this leaf merely *cites*).

## Context

Why this leaf exists: `routine` is the **generator** — it turns the corpus into the actual deliverable:
a Push/Pull/Legs routine that hits **every** muscle, gates every exercise through the lifter's real
equipment and injuries, and **cites a fact for every cell**. It does not discover new training facts;
it *composes* the five research/personal leaves into two runnable artifacts and proves each prescription
back to a `claims` / `training_variables` / `set_structures` row. The corpus must be able to serve, from
this leaf: "give me a static PPL loop for my equipment," "which muscles am I under-volumed on,"
"swap this exercise off a missing machine / off my pinky," and "why is this set/rep/RIR prescribed —
show the evidence." The leaf is the place where the domain's methodological commitment is *cashed out*:
because every cell links to a verdict-bearing claim, the routine inherits the corpus's separation of
"equal growth" from "better in practice" instead of re-flattening it into prose.

How it composes: `routine` runs **LAST** and depends on **all five** upstream leaves plus the lifter's
**equipment inventory** (captured into `constraints` before this leaf runs):
`anatomy` (`muscles`) is the coverage backbone the gap analysis runs against; `movements` (`exercises`,
`movement_patterns`, `substitutions`) is the exercise pool and the swap graph; `programming`
(`training_variables`) supplies the volume/intensity/frequency/RIR knobs; `techniques` (`set_structures`)
supplies the periodization primitives (reverse-pyramid on cores, straight sets / myo-reps on accessories);
`constraints` gates the pool (pinky + equipment) and injects substitutes; `claims` is the evidence layer
every prescription cites. Phase E wires the *traceability* edges (`prescribes`, `cited-by`, `closes-gap`,
`gated-by`) that let `why <claim>` and `routine` walk from a cell to its evidence. No cross-domain links
are expected; this leaf is inward-facing within `exercise`.

## Target tables

Base (every domain): `sources`, `documents`, `concepts`, `commands`, `config_keys`, `failure_modes`,
`relationships`. Plus the domain-specific tables in `domains/exercise/schema.exercise.sql`.

This leaf **writes few rows and reads many** — it is mostly a consumer. Targets at depth `standard`:

| Table | Role for this leaf | Rough rows | Notes |
|---|---|---|---|
| `relationships` | **primary output** — the traceability graph | ~120–200 | `prescribes` (routine-cell → exercise), `cited-by` (cell → claim/variable/structure), `closes-gap` (cell → muscle), `gated-by` (cell → constraint), `substitutes-for` (echoed from `movements`). This is where the leaf's work lands. |
| `commands` | the exercise harness consumer surface | ~5 | `substitute`, `muscle`, `gaps`, `routine`, `why` — one row each, with synopsis + example. |
| `concepts` | generator-level concepts | ~8–12 | `gap-analysis`, `fixed-core-vs-dynamic-accessory`, `RPT-core`, `accessory-rotation`, `volume-waving`, `deload`, `mesocycle`, `grip-bypass`, `PPL-split`, `coverage-completeness`. |
| `config_keys` | the generator's tunable inputs | ~6–10 | `equipment_inventory`, `days_per_week`, `mesocycle_weeks`, `accessory_rotation_weeks`, `target_volume_source`, `deload_trigger`. Document the knobs the lifter sets, not facts. |
| `claims` | **read-only** (consumed, not written) | 0 new | This leaf MUST NOT mint training-science claims — those are owned by `programming`/`techniques`. It may add at most a small number of *generator-design* assertions (e.g. "PPL @ 6 days hits each muscle ~2×/wk") flagged `evidence_grade=mechanistic` and clearly scoped as routine-construction, not effect claims. Prefer to cite, not coin. |
| `failure_modes` | generator self-check failures | ~6–10 | The routine's own defect catalog: "a muscle under MEV after assembly," "a gated exercise still scheduled," "a cell with no citing fact," "antagonist imbalance," "weekly frequency <2× for a muscle," "deload omitted." Symptom → diagnostic query → fix. |

The two **emitted artifacts** (static PPL loop + dynamic mesocycle) are *renders* of the above, not new
tables — they materialize as `extract/routine.static.json` and `extract/routine.mesocycle.json`, each cell
carrying the `relationships` ids that prove it. (If a future depth bump wants them first-class, add a
`routine_cells` table then; at `standard` they stay as rendered artifacts.)

## Meta-research (before executing — do NOT skip)

Plan-mode ritual: (1) **Explore** agents (1–3, parallel) map the territory — sitemaps, ToCs, repo
trees, the authorities; (2) **Plan** agent(s) design the per-leaf extraction — which sources, which
tables, what verification looks like; (3) `AskUserQuestion` on high-leverage forks (scope, depth);
(4) write this PLAN + `STATUS.yaml`; (5) `ExitPlanMode`.

The irreducible work is the **gold layer (Phase D)**. Everything before it is mechanical (find URLs,
fetch, parse). The meta-research exists to protect the expensive layer from being spent on the wrong
sources.

**For THIS leaf the ritual is re-pointed inward.** There is almost nothing to fetch. The Explore agents
do not crawl the web — they **survey the corpus**: confirm the four research leaves + `constraints` are
`done` in their `STATUS.yaml`, count the rows actually present (`muscles`, `exercises`, `substitutions`,
`training_variables`, `set_structures`, `claims`, `constraints`), and surface any holes (a muscle with no
exercise, an exercise with no citing claim, a constraint with no substitute path). The Plan agent designs
the **assembly algorithm + verification queries**, not a source list. The high-leverage `AskUserQuestion`
forks are about the *lifter*, not the literature: confirm **equipment inventory**, **days/week**, and
**mesocycle length** — these are blocking inputs, captured to `config_keys` before assembly. Do not run
this leaf until the upstream leaves report `done` and the inventory is on file.

## Phase A — Survey → `sources`

Goal: a complete, deduplicated, tiered source list scoped to this leaf.

- [ ] **Near-degenerate for a generator leaf.** Add no new web sources. Instead, register the *inputs* as
      a leaf-local `inputs.yaml`: the upstream leaf tables consumed + their `STATUS.yaml` phase, and the
      lifter's equipment inventory / preferences captured into `constraints`/`config_keys`.
- [ ] If a real gap is found upstream (e.g. a needed substitution that `movements` never minted), do **not**
      paper over it here — file it as an Open Question and (if blocking) bounce the upstream leaf. This leaf
      cites facts; it does not invent them.
- [ ] **Verify:** every consumed leaf is `done`; `equipment_inventory` is set in `config_keys`; the corpus
      row counts are non-trivial (`muscles` ≥ all major heads, every machine-dependent `exercise` has a
      `substitutions` row, every load-bearing `training_variables`/`claims` row resolves to a `source_id`).

## Phase B — Ingest → `documents` + FTS

- [ ] **Skipped — no new documents.** This leaf fetches nothing; `documents`/FTS are untouched. Record in
      `PROGRESS.md` that B is intentionally a no-op for the generator and proceed.
- [ ] (Only if equipment inventory arrived as a free-text note worth full-text search: drop it under
      `_db/raw/exercise/routine/` and let the normal loader pick it up — otherwise nothing here.)
- [ ] **Verify:** no orphan docs were created; the consumed FTS index built by upstream leaves is present
      and queryable (smoke `harness search "reverse pyramid"`).

## Phase C — Extract → entity tables

Goal: the small set of generator-owned rows — the harness surface and the tunable knobs — that the
synthesis in Phase D will reference.

- [ ] Extract `commands` (the 5 consumer commands), `concepts` (generator vocabulary),
      `config_keys` (the lifter-tunable inputs), and the `failure_modes` self-check catalog into
      `extract/<table>.json`, then `ingest load`. Copy `extract/*.json` shape from a sibling leaf.
- [ ] Capture the equipment inventory + any new constraints into the `constraints`/`config_keys` rows the
      assembler reads (if not already landed by the `constraints` leaf).
- [ ] **Verify:** counts in the depth-profile order-of-magnitude (≈5 commands, ≈8–12 concepts, ≈6–10
      config keys, ≈6–10 failure modes); every `commands` row has a runnable example; every `concept`
      that asserts a training fact instead cites a `claims` id rather than restating it.

## Phase D — Gold layer → verified facts (the irreducible work)

Goal: the two emitted artifacts + the proof that they are correct. For this leaf the "gold layer" is not
new claims — it is the **assembled routine and the verification that it is complete, gated, and cited.**

Assembly (the generator algorithm, run as queries over the corpus):

1. **Gap analysis** — join `muscles` against Σ(`exercises` × prescribed sets) under the candidate split;
   flag any muscle below its MEV/target weekly sets from `training_variables`. Expect the lifter's known
   **back + core** shortfall to surface; the assembler must add hinge/row/loaded-core volume to close it.
2. **Constraint gating** — drop or swap any exercise whose `grip_demand`/`joint_stress`/`triggers` match an
   active `constraint` (the **left-pinky jam** on grip-load / hanging / crush-grip), injecting the
   `substitutions` the `constraints`/`movements` leaves prescribed (cable wrist cuffs, straps, machine
   variants). Equipment gating likewise: prune anything needing absent equipment, swap in the equivalent.
3. **Assemble the PPL loop** — fixed cores get `set_structures.reverse-pyramid` + compound RIR buffers from
   `training_variables`; dynamic accessories get straight sets / myo-reps and a rotation tag. Failure goes
   on isolation, not compounds (cite the relevant `claims` row).
4. **Emit two artifacts:**
   - **Static loop** → `extract/routine.static.json`: a ready-to-run PPL week, every cell = {exercise, sets,
     rep range, RIR, structure} + the `relationships` ids proving it.
   - **Dynamic mesocycle** → `extract/routine.mesocycle.json`: RPT on fixed cores, **4–6 wk accessory
     rotation**, **volume waving** week-to-week, scheduled **deload** — each week/cell still fully cited.

Verification (this is the irreducible part, sized to `standard`):

- [ ] **Coverage check (spot-check):** re-run the gap analysis on the *final* assembled routine and confirm
      **no muscle is left under target** — especially back + core. This is the single mandatory spot-check.
- [ ] **Adversarial self-consistency pass (one skeptic):** spawn one agent whose job is to **break the
      emitted routine** — find (a) a cell that cites no fact, (b) a scheduled exercise that an active
      constraint should have gated, (c) an exercise needing equipment the inventory lacks, (d) a claim
      *mis-cited* (a "better" prescription leaning on an "equivalent"-verdict claim — the conflation the
      domain exists to prevent), (e) an antagonist or frequency imbalance. Every defect it finds is logged
      to `failure_modes` and fixed; survivors are recorded. (At `exhaustive` this would be the 3–5-skeptic
      gauntlet; at `standard`, one disciplined pass + the coverage check.)
- [ ] **Citation completeness:** assert every cell in both artifacts resolves to ≥1 `relationships` edge
      into `claims`/`training_variables`/`set_structures`; zero uncited cells is a hard gate.
- [ ] **Verify:** a sampled prescription re-derives from its cited fact (open the claim, confirm the cell's
      sets/RIR/structure are what that fact supports, and that an "equivalent"-verdict fact is never used to
      justify a "superior" framing); the pinky and equipment constraints are demonstrably honored.

## Phase E — Relationships → typed graph

This is the second-heaviest phase for the generator: the edges are *the* deliverable's audit trail.

- [ ] Wire, for every routine cell: `prescribes` (cell → `exercises`), `cited-by` / `evidenced-by`
      (cell → `claims` | `training_variables` | `set_structures`), `closes-gap` (cell → `muscles` it covers),
      `gated-by` / `substitutes-for` (cell → `constraints` and the swapped-in exercise). Echo the
      `substitutes` edges from `movements` so `substitute <ex>` walks without re-querying that leaf.
- [ ] **Verify:** a graph walk from any routine cell reaches ≥3 sensible hops
      (cell → exercise → primary muscle → governing volume claim), and the inverse walk
      (`why <claim>` → every cell that cites it) returns the expected cells. A walk from a muscle node
      reaches the cell(s) that close its gap.

## On completion

- [ ] Update `STATUS.yaml` (phase → `done`, `updated:` date) and append a session entry to `PROGRESS.md`.
- [ ] Confirm the five harness commands run against the loaded corpus and return cited output:
      `harness substitute <ex> [--no-<equip>]`, `harness muscle <m>`, `harness gaps`,
      `harness routine [--equipment ...]`, `harness why <claim>`.
- [ ] The two artifacts exist, every cell is cited, and the coverage + gating checks pass.

## Reuse map (look here before writing code)

- `domains/_shared/ingest/` — fetch, extract, load utilities (here used only for `load`, not `fetch`).
- **Sibling leaves are the data source, not a shape reference** — read `anatomy`, `movements`,
  `programming`, `techniques`, `constraints` extract outputs; this leaf joins them. Copy
  `extract/*.json` *shape* from any sibling for the few tables it writes (`commands`, `concepts`,
  `config_keys`, `failure_modes`, `relationships`).
- `packages/cli/` (`@domains/cli`) — the harness command surface (`substitute`, `muscle`, `gaps`,
  `routine`, `why`) is implemented here once the data exists; see CLI internals in the root `CLAUDE.md`.
  Note: native `duckdb` node dep may not build on this machine — query via duckdb CLI / motherduck MCP
  until the harness moves to `@duckdb/node-api`.

## Open questions

- **Equipment inventory** (machines actually available; are cable cuffs / lifting straps owned?) —
  blocking input, must be on file in `constraints`/`config_keys` before assembly. The substitution choices
  depend on it.
- **Days/week and mesocycle length** — 6-day PPL (each muscle ~2×/wk) vs 3-day? Mesocycle 4 vs 6 wk before
  deload? Captured to `config_keys`.
- **Deload trigger** — fixed calendar (every 4–6 wk) vs autoregulated (performance/RIR drift)? Default to
  calendar at `standard`; note autoregulation as a future bump.
- **Static-vs-dynamic boundary** — confirm which lifts the lifter wants as 8–12-wk fixed cores vs 4–6-wk
  rotating accessories (drives `fixed_or_dynamic` reads from `exercises`).
- Should the emitted routine become a first-class `routine_cells` table on a depth bump, or stay a rendered
  artifact? (Defer; `standard` keeps it rendered.)
