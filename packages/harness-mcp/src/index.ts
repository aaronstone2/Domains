#!/usr/bin/env -S npx tsx
// MCP server wrapping the @domains/harness CLI as native MCP tools so Claude
// Code can call ask/lookup/playbook/etc. as first-class tool calls instead of
// shelling out to `! pnpm harness ask "<symptom>"`.
//
// V3 architecture: in-process. The harness module exposes a setOut(stream)
// hook that swaps its writer (defaults to process.stdout for CLI use). MCP
// server creates a Writable that buffers chunks, calls setOut(buffer) before
// each tool call, runs the command in-process, restores. ~50ms per call vs
// ~1500ms in the V1 spawn approach.
//
// Why this works (where naive stdout-patching didn't): the harness writes via
// a CONFIGURABLE writer, not process.stdout directly. The MCP SDK keeps using
// real process.stdout for JSON-RPC protocol writes. No interleaving, no race.
//
// Stdio transport — Claude Code spawns this server when listed in .mcp.json.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { Writable } from "node:stream";
import { commands } from "@domains/harness/commands";
import { setOut, resetOut } from "@domains/harness/output";

// Enable long-lived DB connection for the harness; without this each tool
// call opens+closes a duckdb connection and rapid sequential calls collide
// on the Windows file lock. Set BEFORE first command import side-effects.
process.env["HARNESS_KEEPALIVE"] = "1";

function stripAnsi(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/\x1b\[[0-9;]*m/g, "");
}

// Serial mutex: harness uses a module-global writer (setOut), so concurrent
// in-flight calls would step on each other if MCP processed requests in
// parallel. This chain enforces one-at-a-time even if the SDK lets handlers
// overlap.
let inFlight: Promise<unknown> = Promise.resolve();

async function runHarness(subcommand: string, args: string[]): Promise<string> {
  const cmd = commands[subcommand];
  if (!cmd) {
    return `harness: unknown subcommand "${subcommand}". Available: ${Object.keys(commands).join(", ")}`;
  }

  // Wait for prior call to finish before claiming the writer.
  const prev = inFlight;
  let releaseSlot!: () => void;
  inFlight = new Promise<void>((r) => { releaseSlot = r; });
  try {
    await prev;
  } catch { /* prior failures don't block us */ }

  // Force NO_COLOR so the harness's output module skips ANSI escapes.
  const origNoColor = process.env["NO_COLOR"];
  process.env["NO_COLOR"] = "1";

  // In-memory capture writer. Harness commands call setOut/println; their
  // writes land in chunks here, NOT in process.stdout (which the MCP SDK
  // owns for the JSON-RPC protocol).
  const chunks: string[] = [];
  const captureStream = new Writable({
    write(chunk: Buffer | string, _enc, cb): void {
      chunks.push(typeof chunk === "string" ? chunk : chunk.toString());
      cb();
    },
  });
  setOut(captureStream);

  // Some commands call process.exit on error (usage strings). Intercept so
  // the MCP server doesn't die mid-request.
  let exitCode: number | null = null;
  const origExit = process.exit.bind(process);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (process as any).exit = (code?: number): never => {
    exitCode = code ?? 0;
    throw new Error("__harness_exit__");
  };

  try {
    await cmd(args);
  } catch (err) {
    if (!(err instanceof Error && err.message === "__harness_exit__")) {
      chunks.push(`\n[runHarness caught: ${err instanceof Error ? err.message : String(err)}]\n`);
    }
  } finally {
    resetOut();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (process as any).exit = origExit;
    if (origNoColor === undefined) delete process.env["NO_COLOR"];
    else process.env["NO_COLOR"] = origNoColor;
    releaseSlot();
  }

  let out = stripAnsi(chunks.join(""));
  if (exitCode !== null && exitCode !== 0) {
    out += `\n[harness ${subcommand} exited ${exitCode}]`;
  }
  return out || `[harness ${subcommand} produced no output]`;
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
  { name: "domains-harness", version: "0.2.0" },
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
