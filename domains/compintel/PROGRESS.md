# compintel — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`. Per-leaf logs roll up into this file.

## 2026-06-26 — A–E: live competitive-intelligence (Wave 1, exercises the temporal layer)

4-agent Explore sweep (graph-db-viz / workflow-agents / lowcode-internal / data-schema) →
**66 dated competitor moves** + **8 leading signals**, every move carrying a real `observed_date`
(2024-06 → 2026-06) and source URL. Loaded to `compintel.changes` / `compintel.signals`; each move's
URL registered as a `secondary` source.

**Temporal layer exercised.** Moves span 24 months of changelogs/pricing/funding/acquisitions — the
first corpus data with a real time axis (`ingest snapshot` + `diff` can now show wedge erosion over
time, not just a snapshot).

**Wedge-erosion graph: 78 `erodes` edges** (change → the `market.feature` it touches, only to features
that actually exist). The wedge surfaces under most pressure:
- `canvas` — **15 dated moves** (n8n Canvas UI v1.30, Retool multipage, Node-RED 5.0, ToolJet, Gephi
  0.11, Cytoscape WebGL, yFiles) — spatial/canvas-first editing is converging across rivals.
- `nodes-agent-type` — **13 moves** (n8n AI Agent node, Zapier agent versions/templates, Flowise
  AgentFlow V2, Airtable Hyperagent, Retool Agents, Memgraph MCP) — the agent-visibility wedge is a
  contested arms race, not open space.
- `canvas-pan-zoom` (7, GPU/WebGL rendering floor +30-40×), `data-binding` (7), `ai-assist` (5).

**3 synthesized strategic claims** — read off the loaded moves, **honestly marked
`verdict='speculative'`, `evidence_grade='changelog-derived'`, `claim_type='predictive'`** (never
asserted as fact): canvas-convergence, agent-node arms-race, graph-viz GPU-floor. These feed Wave-3
re-evaluation and the Wave-4 red-team's live falsifier watch (a future competitor move that ships a
wedge feature fires the falsifier).

`ingest verify` (3 predictive-standard claims) + `embed` (3 vectors) run. Honesty preserved: predictive
competitive claims stay speculative; nothing inflates the MetroGraph wedge.
