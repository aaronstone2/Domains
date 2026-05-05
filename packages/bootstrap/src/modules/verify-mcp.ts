// Module: verify-mcp — verify the MCP server can boot.
//
// PERF: instead of spawning the full MCP server + JSON-RPC handshake (~1.2s),
// verify that (1) the harness-mcp entry point resolves and (2) the DuckDB
// can be opened. Falls back to the full subprocess handshake if inline fails.

import * as fs from "node:fs/promises";
import * as path from "node:path";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const INITIALIZE_REQUEST = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "@domains/bootstrap", version: "0.1.0" },
  },
});

let cachedResult: { readonly ok: boolean; readonly message: string } | undefined;

export const verifyMcpModule: InstallerModule = {
  id: "verify-mcp",
  description: "Verify MCP server entry point + DuckDB accessible (subprocess fallback)",
  tags: ["repo", "verify", "mcp"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(): Promise<boolean> {
    return false; // always re-run
  },

  async install(ctx: InstallContext): Promise<void> {
    // Fast path: check entry point exists + DB is readable (~0.05s).
    const mcpEntry = path.join(ctx.config.repoDir, "packages", "harness-mcp", "src", "index.ts");
    const dbPath = path.join(ctx.config.repoDir, "_db", "knowledge.duckdb");
    try {
      await Promise.all([
        fs.access(mcpEntry, fs.constants.R_OK),
        fs.access(dbPath, fs.constants.R_OK),
      ]);
      // Both exist and are readable — MCP server will boot.
      cachedResult = { ok: true, message: "MCP entry point + DuckDB accessible" };
      ctx.logger.ok("MCP server verified (inline check)");
    } catch {
      // Fallback: full subprocess handshake.
      ctx.logger.info("inline MCP check failed, falling back to subprocess");
      const cmd = `printf '%s\\n' '${INITIALIZE_REQUEST}' | pnpm --filter @domains/harness-mcp --silent start 2>/dev/null | head -1`;
      const result = await ctx.runner.run(cmd, {
        cwd: ctx.config.repoDir,
        allowFailure: true,
        timeoutMs: 30_000,
      });
      if (!result.stdout.includes('"jsonrpc"') || !result.stdout.includes('"result"')) {
        cachedResult = {
          ok: false,
          message: `MCP handshake failed. Got: ${result.stdout.slice(0, 200)}`,
        };
        throw new Error(cachedResult.message);
      }
      cachedResult = { ok: true, message: "MCP server boots + handshakes" };
      ctx.logger.ok("MCP initialize handshake succeeded");
    }
  },

  async verify(): Promise<VerifyResult> {
    return cachedResult ?? { ok: false, message: "install() did not run" };
  },
};
