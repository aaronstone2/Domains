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
