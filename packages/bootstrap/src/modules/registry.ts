// Registry — single source of truth for module ordering AND grouping into
// install phases. Phases get a sub-banner during install so the output reads
// as a guided tour ("System packages... Runtimes... Shell config... Verify...").
//
// To add a new module: write src/modules/<name>.ts, import here, append to
// the right phase. The orchestrator (src/index.ts) iterates PHASES in order.

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

export interface Phase {
  readonly name: string;
  readonly description: string;
  readonly modules: readonly InstallerModule[];
}

export const PHASES: readonly Phase[] = [
  {
    name: "System packages",
    description: "Apt installs that bring the box up to interview-ready state",
    modules: [aptCoreModule, aptOptionalModule, aptDockerModule, aptK8sModule, aptAwsModule],
  },
  {
    name: "Runtimes",
    description: "Node.js, pnpm, Claude Code CLI",
    modules: [nodeModule, pnpmModule, claudeCodeModule],
  },
  {
    name: "Shell + secrets",
    description: "Productivity tools, bash config (safety functions), API key provisioning",
    modules: [
      ezaModule,
      zoxideModule,
      atuinModule,
      dockerCompletionModule,
      bashrcModule,
      seedHistoryModule,
      anthropicKeyModule,
    ],
  },
  {
    name: "Repo + verify",
    description: "Workspace deps, knowledge graph, end-to-end smoke tests",
    modules: [pnpmInstallModule, knowledgeGraphModule, verifyHarnessModule, verifyMcpModule],
  },
];

/** Flat list (used by --module=, list, verify subcommands). */
export const ALL_MODULES: readonly InstallerModule[] = PHASES.flatMap((p) => p.modules);

export function findModule(id: string): InstallerModule | undefined {
  return ALL_MODULES.find((m) => m.id === id);
}

/** Find which phase a module belongs to (used for sub-banner labeling). */
export function phaseOf(moduleId: string): Phase | undefined {
  return PHASES.find((p) => p.modules.some((m) => m.id === moduleId));
}
