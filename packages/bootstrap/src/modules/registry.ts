// Registry — single source of truth for module ordering. The orchestrator
// runs modules in this order. Earlier modules can fail without aborting later
// ones (per-module error isolation in src/index.ts).
//
// Order matters: e.g. `node` before `pnpm` (which uses npm), `pnpm` before
// `pnpm-install`, `pnpm-install` before any `verify-*` module that needs
// harness deps in node_modules.

import { aptCoreModule } from "./apt-core.ts";
import { aptOptionalModule } from "./apt-optional.ts";
import { aptDockerModule } from "./apt-docker.ts";
import { aptK8sModule } from "./apt-k8s.ts";
import { aptAwsModule } from "./apt-aws.ts";
import { nodeModule } from "./node.ts";
import { pnpmModule } from "./pnpm.ts";
import { claudeCodeModule } from "./claude-code.ts";
import { ezaModule } from "./eza.ts";
import { zoxideModule } from "./zoxide.ts";
import { atuinModule } from "./atuin.ts";
import { seedHistoryModule } from "./seed-history.ts";
import { dockerCompletionModule } from "./docker-completion.ts";
import { bashrcModule } from "./bashrc.ts";
import { anthropicKeyModule } from "./anthropic-key.ts";
import { pnpmInstallModule } from "./pnpm-install.ts";
import { knowledgeGraphModule } from "./knowledge-graph.ts";
import { verifyHarnessModule } from "./verify-harness.ts";
import { verifyMcpModule } from "./verify-mcp.ts";

import type { InstallerModule } from "../lib/types.ts";

export const ALL_MODULES: readonly InstallerModule[] = [
  // System packages first (apt-core includes `age`, required by anthropic-key)
  aptCoreModule,
  aptOptionalModule,
  aptDockerModule,
  aptK8sModule,
  aptAwsModule,

  // Runtimes second
  nodeModule,
  pnpmModule,
  claudeCodeModule,

  // Tools (need apt-core for curl, etc.)
  ezaModule,
  zoxideModule,
  atuinModule,

  // Shell config (writes ~/.bashrc, depends on tools above for the init lines
  // it generates — though it's safe even if a tool failed; the bashrc gates
  // each init on `command -v <tool>`)
  dockerCompletionModule,
  bashrcModule,
  seedHistoryModule,

  // Provision the Anthropic key from the encrypted file (if present in the
  // repo + user has SSH key + age binary). Runs BEFORE pnpm-install so
  // verify-harness/--launch downstream can pick up the key from disk.
  anthropicKeyModule,

  // Repo-level
  pnpmInstallModule,
  knowledgeGraphModule,

  // End-to-end checks
  verifyHarnessModule,
  verifyMcpModule,
];

export function findModule(id: string): InstallerModule | undefined {
  return ALL_MODULES.find((m) => m.id === id);
}
