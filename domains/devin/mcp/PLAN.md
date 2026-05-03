# Plan — `devin/mcp`

> Per-leaf plan. P1 (sources + ingest) done at the domain level — see `domains/devin/PROGRESS.md` Session 1.1. This file describes Phase C (extraction, this session) and the deferred D/E layers.

## Context

**Why this leaf exists.** Devin uses Model Context Protocol (MCP) to mount tool servers into the agent's context — both Anthropic-shipped and customer-built. The MCP marketplace catalogs vetted servers; the cognitionai/database-toolbox is a notable Cognition-built server with deep configuration surface (DB connection schemas, query allowlists, schema-introspection knobs). **Failure modes here surface as MCP server crashes mid-session, transport disconnects (SSE / stdio), tool-call timeout, schema mismatch between server-declared tools and Devin's expectations, and database-toolbox connection-string misconfigurations.**

**How it composes upward.** MCP servers run inside DevBox (devin/devbox runtime). MCP tool calls are surfaced through the session API (devin/api). MCP server connection-strings are stored in devin/integrations as credentials. Underneath, MCP depends on stdio and HTTP/SSE transports (linux/networking).

## Inputs already available (P1 deliverables)

- 5 documents in `devin.documents` filtered by `subdomain = 'mcp'`. Total ~106,335 chars; mean ~21,267 chars (densest leaf per doc).
- Headline sources: `cognitionai-database-toolbox-readme` (65 KB — heavy config surface), `devin-docs-mcp-marketplace` (20 KB), 3 other mcp-related docs.

## Phase A — Survey ✅ done by P1

5 sources catalogued. The MCP marketplace listing covers many community servers we haven't ingested individually — that's correct scoping (the marketplace doc itself enumerates them).

## Phase B — Document ingest ✅ done by P1

All 5 docs in `devin.documents`. database-toolbox is `redistribute-ok` (Apache-2.0); mcp-marketplace is `reference-only`.

## Phase C — Structured extraction (THIS SESSION)

**Goal:** rows in `devin.concepts/commands/config_keys` tagged `devin.mcp.*`.

- [ ] **Concepts pass.** Target ~30 rows. `kind` values: `protocol | server | transport | tool | resource | feature`. Concepts to capture: `mcp-protocol`, `mcp-server`, `mcp-transport-stdio`, `mcp-transport-sse`, `mcp-tool`, `mcp-resource`, `mcp-prompt`, `mcp-marketplace`, `database-toolbox`, `database-connection`, `query-allowlist`, `schema-introspection`, `read-only-mode`, `dry-run-mode`, `mcp-server-listing`, `marketplace-vetting`, `custom-mcp-server`, etc.
- [ ] **Commands pass.** Target ~15 rows. MCP server install/configure/list/test commands; database-toolbox CLI invocations.
- [ ] **Config keys pass.** Target ~50 rows (database-toolbox README is config-heavy). `scope` values: `mcp-server | database-toolbox | postgres | mysql | sqlite | bigquery | snowflake | databricks | mcp-transport`. Capture every connection-string param, query-allowlist regex, dry-run-mode flag, retry/timeout setting documented in the database-toolbox README.

## Phase D — Failure-modes (DEFERRED to horizontal P4)

Seed candidates:
- MCP transport disconnect (stdio EOF, SSE 503).
- MCP tool-call timeout (server slow to respond).
- Schema mismatch (server lists tools the client doesn't expect).
- database-toolbox connection-string typo → connection-refused.
- database-toolbox query-allowlist regex blocking a legitimate query.

## Phase E — Relationships (DEFERRED to horizontal P5)

- mcp.mcp-server ↔ devbox.devbox-runtime (mcp servers run inside DevBox)
- mcp.mcp-transport-sse ↔ linux/networking SSE/HTTP semantics
- mcp.database-toolbox ↔ docker/engine (often containerized)
- mcp.mcp-tool ↔ devin/api session-tool-call payload

## Reuse map

- `domains/_shared/schema.sql`, methodology examples, motherduck MCP, memory MCP.

## Open questions

- Should individual marketplace MCP servers (e.g., metabase-mcp-server which we ingested as `redistribute-ok` MIT) get their own concept rows? Yes — represented as `kind=server` rows under `devin.mcp.<server-name>`, citing the marketplace listing + the server's README if ingested.
