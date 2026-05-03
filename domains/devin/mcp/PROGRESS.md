# `devin/mcp` — PROGRESS log

Per-leaf log; rolls up into `domains/devin/PROGRESS.md`.

## Phase 3 — Structured extraction (Session 1, 2026-05-02) — DONE

**Output rows:** 43 concepts / 15 commands / 69 config_keys (targets ~30/~15/~50 — exceeded concepts and config_keys).

**Source coverage:** all 5 mcp docs. Database-toolbox README (65 KB) read in two halves — covered 22+ DB integrations and the universal Docker image pattern. Metabase MCP server README + 4 mcp docs read end-to-end.

**Source-id integrity:** all references resolve.

**Highlights:**
- 3 transports catalogued (STDIO/SSE/HTTP) with fields per transport.
- Devin MCP server (mcp.devin.ai) tool catalog: 15 tools spanning repos, sessions, playbooks, knowledge, schedules, integrations.
- DeepWiki MCP server (mcp.deepwiki.com) tool catalog: 3 public-only tools.
- Universal Database Toolbox image + `--prebuilt` (12 DBs) vs `--tools-file` (10+ DBs) modes.
- Metabase MCP — 4 tool-loading flags (essential/all/read/write), API-key vs username/password auth.
- Marketplace credentials catalog: Datadog, Slack, Supabase, Figma, Stripe, Zapier, Airtable, Docker Hub, SonarQube, Netlify, Pulumi, Heroku, CircleCI, Cortex, Square, HubSpot, Redis, Google Maps, Firecrawl, Elasticsearch, Postgres, Plaid, Replicate, Grafana, Pinecone, Snyk, Parallel.

## Phase 4 candidates

- MCP transport disconnect (stdio EOF, SSE 503).
- Tool-call timeout.
- Schema mismatch (server lists tools client doesn't expect).
- Database-toolbox connection-string typo.
- Query-allowlist regex blocking legitimate query.
- OAuth flow stuck (admin-only auth required).
- Pinecone external-embedding indexes not supported.

## Phase 5 candidates

- mcp.mcp-server ↔ devbox.devbox-runtime (where MCP servers run)
- mcp.mcp-transport-sse ↔ linux/networking SSE/HTTP semantics
- mcp.database-toolbox ↔ docker/engine (containerized)
- mcp.mcp-tool ↔ devin/api session-tool-call payload
- mcp.devin-mcp-server (mcp.devin.ai) ↔ all api commands
