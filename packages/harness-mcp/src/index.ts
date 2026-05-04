#!/usr/bin/env -S npx tsx
// MCP server wrapping the @domains/harness CLI as native MCP tools so Claude
// Code can call ask/lookup/playbook/etc. as first-class tool calls instead of
// shelling out to `! pnpm harness ask "<symptom>"`.
//
// V1 strategy: spawn the harness CLI for each tool call and return cleaned
// stdout. Trades ~700ms per call for zero code duplication and perfect parity
// with the CLI experience the user knows from `cheat`.
//
// Stdio transport — Claude Code spawns this server when listed in .mcp.json,
// pipes JSON-RPC over stdin/stdout, and the user sees tool calls in the UI.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here: string = dirname(fileURLToPath(import.meta.url));
const repoRoot: string = resolve(here, "..", "..", "..");

// Strip ANSI escape sequences — claude shows tool results in its own UI and
// raw escapes are noise.
function stripAnsi(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/\x1b\[[0-9;]*m/g, "");
}

// Run `pnpm harness <subcommand> <args...>` from the repo root and return the
// cleaned stdout. Uses spawn(shell:true) for cross-platform compat — Windows
// needs shell:true to invoke pnpm.cmd, Linux/macOS handles either way.
function runHarness(subcommand: string, args: string[]): Promise<string> {
  return new Promise((resolveP) => {
    const cmd = `pnpm harness ${[subcommand, ...args].map((a) => JSON.stringify(a)).join(" ")}`;
    const child = spawn(cmd, {
      cwd: repoRoot,
      env: { ...process.env, NO_COLOR: "1" },
      shell: true,
    });
    let out = "";
    let err = "";
    child.stdout?.on("data", (d: Buffer) => { out += d.toString(); });
    child.stderr?.on("data", (d: Buffer) => { err += d.toString(); });
    child.on("close", (code) => {
      const cleanOut = stripAnsi(out);
      if (code === 0) {
        resolveP(cleanOut);
      } else {
        const cleanErr = stripAnsi(err);
        resolveP(`harness ${subcommand} exited ${code}\n${cleanOut}\n${cleanErr}`.trim());
      }
    });
    child.on("error", (e) => {
      resolveP(`harness ${subcommand} spawn error: ${e.message}`);
    });
  });
}

const TOOLS: Tool[] = [
  {
    name: "ask",
    description:
      "PRIMARY entry point. One-shot symptom → top failure mode + talk-track + diagnostic steps + fix steps + citations. Use this whenever a user describes a symptom, error message, or 'help me debug X' situation. Returns a polished structured runbook. Examples of input: 'OOMKilled in pod logs', 'kubectl drain hangs on PDB', 'container exits 125', 'Devin can't reach internal service'.",
    inputSchema: {
      type: "object",
      properties: {
        symptom: {
          type: "string",
          description: "The symptom, error message, or natural-language description of the problem",
        },
      },
      required: ["symptom"],
    },
  },
  {
    name: "lookup",
    description:
      "Browse-mode search across the corpus. Returns up to 8 failure modes (ranked by keyword match strength × confidence), plus matching commands, concepts, and BM25-indexed documentation snippets. Use when `ask` doesn't find the right top match and you want to see the full candidate set. Input: free-text query.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Free-text search query" },
      },
      required: ["query"],
    },
  },
  {
    name: "playbook",
    description:
      "Render a specific failure mode runbook by id. Returns full META, talk-track, diagnostic steps with `expected` outcomes, fix steps with `validate`/`rollback` annotations, and source citations. Use when you already know the fm-id (e.g. from a prior `ask` or `lookup`). Examples: 'docker.fm.exit-137-oomkilled', 'k8s.fm.dns-pod-search-too-many', 'devin.fm.session-cant-reach-internal-svc'.",
    inputSchema: {
      type: "object",
      properties: {
        fm_id: { type: "string", description: "Failure mode id (e.g. 'docker.fm.exit-137-oomkilled')" },
      },
      required: ["fm_id"],
    },
  },
  {
    name: "concept",
    description:
      "Show a concept's definition + relationship edges. Use to understand a primitive (cgroups, OOM-killer, iptables NAT) before recommending fixes that depend on it.",
    inputSchema: {
      type: "object",
      properties: {
        concept_id: { type: "string", description: "Concept id (e.g. 'linux.primitives.cgroup-v2')" },
      },
      required: ["concept_id"],
    },
  },
  {
    name: "related",
    description:
      "Walk the relationship graph outward from a node (concept, command, failure mode) up to depth N (default 2, max 4). Useful for cross-domain inference: 'what k8s concepts are linked to this Linux primitive?'.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "Starting node id" },
        depth: { type: "number", description: "Walk depth, 1-4 (default 2)", default: 2 },
      },
      required: ["id"],
    },
  },
  {
    name: "cite",
    description:
      "Look up a source by id — returns title, URL, tier (T1/T2), license note. Use when you want to give the user the canonical doc URL for a recommendation.",
    inputSchema: {
      type: "object",
      properties: {
        source_id: { type: "string", description: "Source id (e.g. 'k8s-resource-management')" },
      },
      required: ["source_id"],
    },
  },
  {
    name: "stats",
    description:
      "Corpus inventory + failure-mode quality grades. Returns counts per domain (sources/documents/concepts/commands/config_keys/failure_modes/relationships) and the % of failure modes that are 'thin' (<3 diag or <2 fix steps). Use to understand what's available before answering.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "capture",
    description:
      "Run a curated diagnostic-bundle against the live system and return the captured output. Bundles: oom, network-egress, dns, systemd-unit, k8s-pending, docker-state, perf-stalls, devin-vpn. Pass `--list` for the catalog, or `--from-fm <fm-id>` to synthesize a bundle from any failure mode's diagnostic steps. SIDE EFFECT: actually executes shell commands on the host.",
    inputSchema: {
      type: "object",
      properties: {
        bundle_or_flag: { type: "string", description: "Bundle name, '--list', or '--from-fm <fm-id>'" },
      },
      required: ["bundle_or_flag"],
    },
  },
];

const server = new Server(
  { name: "domains-harness", version: "0.1.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, () => {
  return { tools: TOOLS };
});

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  const a = (args ?? {}) as Record<string, unknown>;
  let output: string;

  switch (name) {
    case "ask":
      output = await runHarness("ask", [String(a["symptom"] ?? "")]);
      break;
    case "lookup":
      output = await runHarness("lookup", [String(a["query"] ?? "")]);
      break;
    case "playbook":
      output = await runHarness("playbook", [String(a["fm_id"] ?? "")]);
      break;
    case "concept":
      output = await runHarness("concept", [String(a["concept_id"] ?? "")]);
      break;
    case "related":
      output = await runHarness("related", [String(a["id"] ?? ""), String(a["depth"] ?? "2")]);
      break;
    case "cite":
      output = await runHarness("cite", [String(a["source_id"] ?? "")]);
      break;
    case "stats":
      output = await runHarness("stats", []);
      break;
    case "capture":
      output = await runHarness("capture", [String(a["bundle_or_flag"] ?? "")]);
      break;
    default:
      output = `Unknown tool: ${name}`;
  }

  return {
    content: [{ type: "text", text: output }],
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);
// Server runs until stdin closes.
