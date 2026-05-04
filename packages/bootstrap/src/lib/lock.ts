// Concurrent-run lock. Prevents two simultaneous `bootstrap install`
// invocations from interleaving apt-get / pnpm install / bashrc writes
// (the I in ACID).
//
// Strategy: PID file at /tmp/domains-bootstrap.lock. On acquire:
//   1. If file doesn't exist: create with our PID, return.
//   2. If file exists: read the PID inside.
//      a. If that PID is alive (kill -0), refuse to start; tell user how to
//         override.
//      b. If that PID is dead (stale lock from a crashed previous run),
//         silently take over.
// On release: delete the file (best-effort).
//
// Why not flock(2)? It's POSIX-only and Node doesn't expose it without a
// native dep. PID file is portable, debuggable (`cat /tmp/domains-...lock`),
// and survives the failure modes that matter for this use case.

import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";

const LOCK_PATH = path.join(os.tmpdir(), "domains-bootstrap.lock");

export class LockHeldError extends Error {
  readonly holderPid: number;
  constructor(pid: number) {
    super(
      `Another bootstrap is running (pid ${pid}, lock at ${LOCK_PATH}). ` +
        `If you're sure that pid is not actually running:\n` +
        `  rm ${LOCK_PATH}\n` +
        `Then re-run.`,
    );
    this.name = "LockHeldError";
    this.holderPid = pid;
  }
}

export interface LockHandle {
  /** Release the lock. Idempotent; safe to call in finally. */
  release(): Promise<void>;
  /** PID we wrote into the lock file. */
  readonly pid: number;
  /** Path of the lock file (for debugging). */
  readonly path: string;
}

/**
 * Acquire the bootstrap lock or throw LockHeldError if held.
 *
 * @throws LockHeldError if another live bootstrap holds the lock
 */
export async function acquireLock(): Promise<LockHandle> {
  const myPid = process.pid;

  // Fast path: lock file doesn't exist yet.
  let writtenByUs = false;
  try {
    // wx flag = create-only, fail if exists. Atomic via filesystem.
    await fs.writeFile(LOCK_PATH, String(myPid), { flag: "wx" });
    writtenByUs = true;
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code !== "EEXIST") throw err;
  }

  if (!writtenByUs) {
    // Existing lock — read PID and check liveness.
    const content = (await fs.readFile(LOCK_PATH, "utf8")).trim();
    const otherPid = Number.parseInt(content, 10);
    if (Number.isFinite(otherPid) && otherPid > 0 && isPidAlive(otherPid)) {
      throw new LockHeldError(otherPid);
    }
    // Stale lock — overwrite with our PID. Race window between unlink + create
    // is acceptable; multiple concurrent bootstraps doing the same recovery
    // would cost at most a few wasted apt-get installs (idempotent anyway).
    await fs.writeFile(LOCK_PATH, String(myPid));
  }

  return {
    pid: myPid,
    path: LOCK_PATH,
    release: async () => {
      // Best-effort delete. Don't throw on failure — caller is in a finally.
      try {
        const content = (await fs.readFile(LOCK_PATH, "utf8")).trim();
        if (Number.parseInt(content, 10) === myPid) {
          await fs.unlink(LOCK_PATH);
        }
      } catch {
        // ignore
      }
    },
  };
}

function isPidAlive(pid: number): boolean {
  try {
    // signal 0 doesn't actually send a signal; just checks process existence.
    process.kill(pid, 0);
    return true;
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    // ESRCH = no such process. EPERM = exists but we can't signal it (still alive).
    return e.code === "EPERM";
  }
}
