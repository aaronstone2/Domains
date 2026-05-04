// Module: verify-mcp — JSON-RPC initialize handshake against the harness MCP
// server. Confirms the MCP boots and registers tools.

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

export const verifyMcpModule: InstallerModule = {
  id: "verify-mcp",
  description: "JSON-RPC initialize handshake against the harness MCP server",
  tags: ["repo", "verify", "mcp"],

  shouldRun(): boolean {
    return true;
  },

  async isInstalled(): Promise<boolean> {
    return false; // always re-run
  },

  async install(ctx: InstallContext): Promise<void> {
    const cmd = `printf '%s\\n' '${INITIALIZE_REQUEST}' | pnpm --filter @domains/harness-mcp --silent start 2>/dev/null | head -1`;
    const result = await ctx.runner.run(cmd, {
      cwd: ctx.config.repoDir,
      allowFailure: true,
      timeoutMs: 30_000,
    });
    if (!result.stdout.includes('"jsonrpc"') || !result.stdout.includes('"result"')) {
      throw new Error(
        `MCP initialize did not return a valid JSON-RPC response. Got: ${result.stdout.slice(0, 200)}`,
      );
    }
    ctx.logger.ok("MCP initialize handshake succeeded");
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    try {
      await this.install(ctx);
      return { ok: true, message: "MCP server boots + handshakes" };
    } catch (err) {
      return { ok: false, message: (err as Error).message };
    }
  },
};
