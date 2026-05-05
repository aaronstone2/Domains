// Workspace-root detection.
//
// THE BUG THIS FIXES: when bootstrap is invoked via `pnpm --filter
// @domains/bootstrap start`, pnpm changes cwd to packages/bootstrap before
// running the script. Then process.cwd() returns the package dir, NOT the
// repo root. Every path-based check (_db/knowledge.duckdb, node_modules/.pnpm,
// pnpm harness ask) breaks because it looks under packages/bootstrap/...
// instead of the actual repo root.
//
// Fix: walk up from process.cwd() looking for `pnpm-workspace.yaml` (the
// definitive marker of a pnpm workspace root). Fall back to process.cwd()
// if not found (e.g. running outside any workspace).
//
// This is defense-in-depth — the trampoline also bypasses pnpm --filter
// by calling tsx directly. Both fixes coexist.

import * as fs from "node:fs";
import * as path from "node:path";

const WORKSPACE_MARKERS = [
  "pnpm-workspace.yaml",
  // .git is the last-resort marker; we only fall through to it if the
  // pnpm-workspace.yaml is somehow absent.
  ".git",
];

/**
 * Walk up from `startDir` (default: process.cwd()) looking for the workspace
 * root. The first directory containing any of WORKSPACE_MARKERS wins.
 *
 * Returns the absolute path to the workspace root, or `startDir` if no marker
 * was found before hitting the filesystem root.
 */
export function findWorkspaceRoot(startDir: string = process.cwd()): string {
  let current = path.resolve(startDir);
  const root = path.parse(current).root;
  while (current !== root) {
    for (const marker of WORKSPACE_MARKERS) {
      const candidate = path.join(current, marker);
      if (fs.existsSync(candidate)) return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break; // hit fs root
    current = parent;
  }
  return path.resolve(startDir); // fallback — caller may complain
}
