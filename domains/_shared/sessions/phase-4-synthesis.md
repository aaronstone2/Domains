# Phase 4 — Cross-domain synthesis

> **2 sessions.** Run after Phase 3 has covered at least leaves 1–8 in priority order (devbox, docker/engine, linux/primitives + networking + debugging, docker/networking + compose + runtime).

## How to start this session

Open Claude Code in `C:\Users\adsto\git\domains`. Paste this file or say: *"Run domains/_shared/sessions/phase-4-synthesis.md."*

## Read first
- [`PREAMBLE.md`](./PREAMBLE.md)
- All leaf-level `PROGRESS.md` files to see where each domain stands
- `meta.all_concepts`, `meta.all_failure_modes`, `meta.all_commands` row counts: `duckdb _db/knowledge.duckdb -c "SELECT domain, count(*) FROM meta.all_failure_modes GROUP BY 1"`

## Goal

The corpus has thousands of entities. This phase **wires them into chains** so the harness can answer:

> "Container exits with code 137" → `docker.failure_modes.container_oom_killed` → caused-by → `linux.concepts.cgroup_memory_limit` → surfaced-by → `linux.commands.dmesg` → fixed-by → `docker.config_keys.compose_mem_limit`

That's a 4-hop chain across 3 domains. Every Devin failure-mode should reduce to a Linux/Docker primitive in ≤4 hops. **This is the "explain the why" muscle the interview tests.**

## Plan-mode meta-research (Phases 1–5)

### Phase 1 — Initial Understanding (Explore agents)

Launch 2 Explore agents:
1. **Survey the existing relationships graph.** Query `meta.all_relationships`: what rel_types exist, what's the average out-degree per concept, where are the dense hubs vs. dangling nodes?
2. **Survey "Devin failure-mode → Linux/Docker primitive" candidate chains.** From `devin.failure_modes`, identify the 20–30 most likely failure-modes a support engineer would actually see (drawn from `docs.devin.ai/admin/common-issues`, status page incidents, MCP-related failures). For each, hypothesize the chain.

### Phase 2 — Design (Plan agent)

Design the synthesis approach:
- **4.1 Cross-domain failure-mode linking.** For each pair (failure_mode_A, failure_mode_B) where one *causes* or *surfaces* another, insert a `relationships` row with rel_type `causes` / `surfaces-in` / `co-occurs-with`. Source: cite the doc that established the link.
- **4.2 Devin→primitive chains.** For each Devin failure-mode, walk to a Linux/Docker primitive. Insert intermediate rows where they're missing (this often surfaces gaps in Phase 3).
- **Memory MCP graph.** Build the *conceptual* graph in the memory MCP: ~hundreds of nodes (the "skeleton" — not every entity, just the load-bearing ones). The SQL `relationships` table holds the bulk; the graph holds the spine.

### Phase 3 — Review

Confirm:
- Which Devin failure-modes you picked as the priority chains (top 20–30).
- Whether to also build a *symptom → command* index for the harness's `harness symptom` to use as a fast path.

### Phase 4 — Final Plan

Write `domains/_shared/sessions/PHASE-4-PLAN.md` listing the chains to build, the rel_types to use, the memory-graph nodes to create.

### Phase 5 — `ExitPlanMode`

## Execute

```sql
-- Examples of relationship inserts
INSERT INTO docker.relationships (from_id, to_id, rel_type, source_id) VALUES
  ('docker.fm.container_oom_killed', 'linux.concept.cgroup_memory_limit',  'caused-by',   'kernel-docs-cgroup-v2'),
  ('docker.fm.container_oom_killed', 'linux.command.dmesg',                'surfaced-by', 'man7-dmesg-1'),
  ('docker.fm.container_oom_killed', 'docker.config_key.compose_mem_limit','fixed-by',    'docker-compose-spec-gh');
```

```javascript
// Memory MCP graph nodes — only load-bearing concepts
mcp__memory__create_entities([
  { name: "cgroup_memory_limit", entityType: "linux-primitive", observations: ["The cgroup v2 memory.max controls hard memory limit; OOM-killer fires when exceeded."] },
  { name: "container_oom_killed", entityType: "docker-failure-mode", observations: ["Container exit code 137 = SIGKILL from OOM."] },
  // ...
]);
mcp__memory__create_relations([
  { from: "container_oom_killed", to: "cgroup_memory_limit", relationType: "caused-by" },
  // ...
]);
```

## Verification

- [ ] Pick 5 random Devin failure-modes; query a 3-hop walk from each → at least 3 of 5 reach a Linux/Docker primitive.
- [ ] `meta.all_relationships` count grew non-trivially (target: +20% over Phase 3 totals).
- [ ] Memory MCP graph has 100–500 nodes (no more — that's the spine, not the bulk).
- [ ] `harness chain <devin.fm.id>` (after Phase 5 implements it) returns a sensible chain.

## When this is done

Move to [`phase-5-harness.md`](./phase-5-harness.md). The corpus is now ready to be queried by an interactive tool.
