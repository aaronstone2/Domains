// BashrcBlock — idempotent marker-based replace of the bootstrap-managed
// section in ~/.bashrc. The legacy bash used awk for this; we use plain
// string ops + a single read/write pair.
//
// Markers (BASHRC_MARKER_BEGIN / _END from types.ts) are the same as the
// legacy script for backward compat: re-running the new bootstrap on a box
// that has the legacy block will replace it cleanly.

import * as fs from "node:fs/promises";

import { BASHRC_MARKER_BEGIN, BASHRC_MARKER_END } from "./types.ts";
import type { Runner } from "./runner.ts";

export interface BashrcWriteOptions {
  readonly path: string;
  readonly content: string;
  readonly runner: Runner;
}

/**
 * Replace (or append) the bootstrap-managed block in the target file.
 *
 * - If the file already has both markers: replace text between them (inclusive
 *   of markers) with the new block. Idempotent re-runs produce no diff if the
 *   content is unchanged.
 * - If the file is missing the markers: append the block at end.
 * - If the file doesn't exist: create it with just the block.
 *
 * The block is wrapped automatically with the markers — pass JUST the body in
 * `content`.
 */
export async function writeBashrcBlock(opts: BashrcWriteOptions): Promise<void> {
  const wrapped = `${BASHRC_MARKER_BEGIN}\n${opts.content.trim()}\n${BASHRC_MARKER_END}\n`;

  let existing = "";
  try {
    existing = await fs.readFile(opts.path, "utf8");
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code !== "ENOENT") throw err;
  }

  let next: string;
  if (existing.includes(BASHRC_MARKER_BEGIN) && existing.includes(BASHRC_MARKER_END)) {
    next = replaceBetweenMarkers(existing, wrapped);
  } else if (existing === "") {
    next = wrapped;
  } else {
    // Append; ensure exactly one blank line before the block
    const trimmed = existing.replace(/\n*$/, "");
    next = `${trimmed}\n\n${wrapped}`;
  }

  if (next === existing) {
    return; // no-op
  }
  await opts.runner.writeFile(opts.path, next);
}

/** Read the current managed block (without markers). Returns "" if absent. */
export async function readBashrcBlock(path: string): Promise<string> {
  let raw: string;
  try {
    raw = await fs.readFile(path, "utf8");
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code === "ENOENT") return "";
    throw err;
  }
  const start = raw.indexOf(BASHRC_MARKER_BEGIN);
  const end = raw.indexOf(BASHRC_MARKER_END);
  if (start < 0 || end < 0 || end < start) return "";
  const body = raw.slice(start + BASHRC_MARKER_BEGIN.length, end);
  return body.trim();
}

/** Remove the managed block entirely. No-op if not present. */
export async function removeBashrcBlock(opts: {
  readonly path: string;
  readonly runner: Runner;
}): Promise<void> {
  let raw: string;
  try {
    raw = await fs.readFile(opts.path, "utf8");
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code === "ENOENT") return;
    throw err;
  }
  const start = raw.indexOf(BASHRC_MARKER_BEGIN);
  const end = raw.indexOf(BASHRC_MARKER_END);
  if (start < 0 || end < 0 || end < start) return;
  const before = raw.slice(0, start).replace(/\n+$/, "");
  const after = raw.slice(end + BASHRC_MARKER_END.length).replace(/^\n+/, "");
  const next = `${before}\n${after}`.replace(/\n{3,}/g, "\n\n");
  await opts.runner.writeFile(opts.path, next);
}

// ---- internals ----

function replaceBetweenMarkers(file: string, wrappedBlock: string): string {
  const start = file.indexOf(BASHRC_MARKER_BEGIN);
  const end = file.indexOf(BASHRC_MARKER_END);
  // include trailing newline of the end marker line
  const endLineBreak = file.indexOf("\n", end + BASHRC_MARKER_END.length);
  const endIdx = endLineBreak < 0 ? file.length : endLineBreak + 1;
  const before = file.slice(0, start).replace(/\n+$/, "\n");
  const after = file.slice(endIdx).replace(/^\n+/, "");
  return `${before}${wrappedBlock}${after === "" ? "" : `\n${after}`}`;
}
