# strategy — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## 2026-06-26 — Wave 3: wedge re-evaluation overlay (the keystone)

The strategy domain reads the whole cross-domain algebra READ-ONLY and never mutates another domain's
verdicts. Wave 3 builds **`strategy.wedge_reeval`** — for each of the **13 market wedge claims** that now
carry cross-domain evidence, an honest ceiling grade overlaid on (never written back to) market's verdict.

**Layer 5 (`ingest reason`) first:** new committed rule `cross-domain-proxy-lift.yaml` derived **13
edges** back into the market graph (8 `empirically_grounded_by` from hci, 5 `proxy_supported_by` from
voc), provenance-stamped `derived=TRUE`, and **honestly skips any claim with an hci `contradicts` edge**
— contested claims are not silently lifted.

**The re-eval result (honest, capped):**
- **6 → supported-by-proxy** (the ceiling): e.g. `wayfinding-in-schematic-maps-transfers`, `progressive-
  disclosure-unlocks-schema-acquisition`, `information-foraging-predicts-metro-map-adoption`,
  `direct-manipulation-outperforms-conversation` — all were market-**refuted** on pure-secondary grounds,
  now lifted *because real mined/empirical evidence backs them* — but no higher.
- **4 → contested** (hci contradicts): `mixed-initiative-requires-visualization`, `visual-affordances-
  enable-interaction-without-training` — mixed empirical signal, NOT lifted.
- **3 → weak-proxy**: incl. the boldest bet `schematic-maps-outperform-force-directed-database-
  exploration` — only weak proxy support; the literature is split.

**`pending_experimental = TRUE for all 13`** — derived from the empty voc dormant-intake, this is the
mechanized honesty cap: the synthesis can NEVER upgrade a wedge claim to experimental grade. Each row
names the specific MetroGraph study (`needed_experiment`) that alone could lift it — these become Wave-4
roadmap items, not assumed inputs.

## 2026-06-26 — Wave 4: prescriptive synthesis + multi-render + red-team (capstone)

Built read-only from the whole cross-domain algebra; nothing mutates another domain (market.claims diff
since the prior snapshot = 0/0/0, proving the C5 guard).

**Prescriptive engine — `strategy.recommendations` (8).** priority_score is DERIVED by query over each
rec's cited claims' confidence x impact / effort — it recomputes when facts change, never hand-set.
Ranked: run-the-missing-layout-study (0.35) > defend-canvas-wedge-as-contested (0.17) > Postgres-first-
integration (0.16) > ship-wedge-features (0.11) > ship-enterprise-compliance-baseline. **4 are
`is_experiment=TRUE`** — the needed-but-missing MetroGraph studies, emitted as roadmap items (never
assumed satisfied).

**Multi-render family — `render_blocks` (7) + `artifact_blocks` (16).** One cited block per metric/claim
(SOM $37.6M/$93.6M/$226.3M, LTV:CAC 2.6x/8.5x/28x, valuation 9.5-37.4x, the lead wedge, the enterprise
gate, Postgres integration, canvas erosion), each resolving to exactly one claim_id/source_id with a
self-auditing verdict glyph (modeled/proxy/contested/speculative). Four artifacts (investor-deck,
strategy-memo, battlecard:neo4j, board-update) project from the shared blocks — no artifact restates a
number.

**Standing red-team — `red_team_findings` (3, all firing).** Falsifiers wired to live compintel temporal
signals: the canvas-commoditized falsifier FIRED on Node-RED 5.0 (2026-06-09); the agent-arms-race
countermove FIRED on Zapier agent templates (2026-02-01); the layout-unproven falsifier (fatal) flags
that metro-superiority is only weak-proxy.

**Acceptance — all 3 end-to-end tests pass:** (1) a refuted wedge claim reaches supported-by-proxy +
pending-experimental + auto-emits its validation experiment; (2) one metric across 3 artifacts resolves
to an identical claim_id/source_id (non-divergence); (3) a red-team falsifier wired to a compintel signal
fires on a real dated competitor move. Corpus snapshotted to committed parquet (`2026Q2-strategy-os`,
102 tables).
