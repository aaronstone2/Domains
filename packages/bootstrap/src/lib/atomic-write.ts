// Atomic file write — write-to-tmp + rename + fsync. The D in ACID.
//
// Why this matters: ~/.bashrc gets written in install(); if the process
// crashes (OOM, signal 9, power loss) mid-write, the file is truncated and
// the next shell launch fails to source it. With write-to-tmp + rename we
// have at-most-one of: old content present, new content present. Never
// half-written.
//
// We also fsync the parent directory (POSIX requirement for the rename
// to be durable across power loss). Best-effort; filesystem may not
// support it.
//
// File mode: optional. Default 0o644 for files, 0o755 for parent dirs we
// auto-create. Pass mode: 0o600 for secrets.

import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as crypto from "node:crypto";

export interface AtomicWriteOptions {
  /** File mode (default 0o644). Use 0o600 for secrets. */
  readonly mode?: number;
  /** Best-effort fsync after rename. Default true. */
  readonly fsync?: boolean;
}

/**
 * Write `content` to `targetPath` atomically. Either the new content is
 * fully present after this returns, or the previous content is intact.
 * Never a partial write.
 */
export async function atomicWrite(
  targetPath: string,
  content: string | Buffer,
  opts: AtomicWriteOptions = {},
): Promise<void> {
  const mode = opts.mode ?? 0o644;
  const dir = path.dirname(targetPath);
  await fs.mkdir(dir, { recursive: true });

  // Tmp filename: same dir (so rename is atomic — must be on same fs) +
  // unique suffix to avoid colliding with concurrent writers.
  const tmpName = `.${path.basename(targetPath)}.${process.pid}.${crypto.randomBytes(6).toString("hex")}.tmp`;
  const tmpPath = path.join(dir, tmpName);

  // Write to tmp + fsync the file content.
  const fh = await fs.open(tmpPath, "w", mode);
  try {
    await fh.writeFile(content);
    if (opts.fsync !== false) {
      await fh.sync();
    }
    await fh.chmod(mode); // re-apply in case umask widened
  } finally {
    await fh.close();
  }

  // Atomic rename. POSIX guarantees this is atomic when src and dst are on
  // the same filesystem (which they are — same dir).
  await fs.rename(tmpPath, targetPath);

  // Best-effort fsync the parent dir so the rename is durable across power
  // loss. Some filesystems / platforms don't support open-ing a dir; ignore
  // failures.
  if (opts.fsync !== false) {
    try {
      const dh = await fs.open(dir, "r");
      try {
        await dh.sync();
      } finally {
        await dh.close();
      }
    } catch {
      // ignore — non-POSIX FS or platform limitation
    }
  }
}

/**
 * Read existing content (or undefined) and write new content atomically only
 * if it differs. Returns true if a write happened, false if no-op.
 */
export async function atomicWriteIfChanged(
  targetPath: string,
  content: string,
  opts: AtomicWriteOptions = {},
): Promise<boolean> {
  let existing: string | undefined;
  try {
    existing = await fs.readFile(targetPath, "utf8");
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code !== "ENOENT") throw err;
  }
  if (existing === content) return false;
  await atomicWrite(targetPath, content, opts);
  return true;
}
