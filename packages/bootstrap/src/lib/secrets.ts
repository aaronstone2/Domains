// Secrets — Anthropic API key resolution with layered fallback.
//
// We never put a key in the code or in the repo. Resolution order (first hit
// wins):
//   1. --anthropic-key=... CLI flag
//   2. $ANTHROPIC_API_KEY env var (← what Devin Secrets injects automatically)
//   3. ~/.config/domains/anthropic-key file (chmod 600 enforced)
//   4. Interactive hidden prompt (only if TTY)
//   5. Throw NoAnthropicKeyError
//
// When the key arrives via #1 or #2 and #3 is empty, we offer to persist it
// to the config file so subsequent runs work zero-arg. Persistence is
// opt-in via prompt.
//
// We never log the raw key — `mask()` returns `sk-ant-…XXXX` for display.

import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as os from "node:os";
import * as readline from "node:readline";

import type { Logger } from "./log.ts";

export class NoAnthropicKeyError extends Error {
  constructor() {
    super(
      "No Anthropic API key found. Provide one of:\n" +
        "  - flag:  --anthropic-key=sk-ant-...\n" +
        "  - env:   export ANTHROPIC_API_KEY=sk-ant-...\n" +
        "  - file:  ~/.config/domains/anthropic-key (chmod 600)\n" +
        "  - or run interactively (TTY required) and the bootstrap will prompt.",
    );
    this.name = "NoAnthropicKeyError";
  }
}

export class InvalidAnthropicKeyError extends Error {
  constructor(reason: string) {
    super(`Anthropic key looks invalid: ${reason}. Got: ${reason}`);
    this.name = "InvalidAnthropicKeyError";
  }
}

const KEY_PATH = path.join(os.homedir(), ".config", "domains", "anthropic-key");

/**
 * Resolve the Anthropic key. Throws if not found and no TTY available.
 * Mutates nothing on disk by default; pass offerPersist=true to ask the user
 * whether to save a flag/env-supplied key for later runs.
 */
export async function loadAnthropicKey(opts: {
  readonly fromFlag: string | undefined;
  readonly logger: Logger;
  readonly interactive?: boolean;
  readonly offerPersist?: boolean;
}): Promise<{ readonly key: string; readonly source: KeySource }> {
  // 1. CLI flag (explicit, wins)
  if (opts.fromFlag !== undefined && opts.fromFlag !== "") {
    validateKey(opts.fromFlag);
    if (opts.offerPersist === true) {
      await maybeOfferPersist(opts.fromFlag, "flag", opts.logger);
    }
    return { key: opts.fromFlag, source: "flag" };
  }

  // 2. Environment
  const fromEnv = process.env["ANTHROPIC_API_KEY"];
  if (fromEnv !== undefined && fromEnv !== "") {
    validateKey(fromEnv);
    if (opts.offerPersist === true) {
      await maybeOfferPersist(fromEnv, "env", opts.logger);
    }
    return { key: fromEnv, source: "env" };
  }

  // 3. Config file
  const fromFile = await readFromConfigFile();
  if (fromFile !== undefined) {
    validateKey(fromFile);
    return { key: fromFile, source: "file" };
  }

  // 4. Interactive prompt
  if (opts.interactive !== false && process.stdin.isTTY === true) {
    opts.logger.info(`No key found in flag/env/file. Prompting (input hidden)...`);
    const typed = await promptHidden("Anthropic API key: ");
    if (typed === "") throw new NoAnthropicKeyError();
    validateKey(typed);
    if (opts.offerPersist === true) {
      await maybeOfferPersist(typed, "prompt", opts.logger);
    }
    return { key: typed, source: "prompt" };
  }

  throw new NoAnthropicKeyError();
}

export type KeySource = "flag" | "env" | "file" | "prompt";

/** Mask a key for log/display: `sk-ant-…XXXX` (last 4). */
export function mask(key: string): string {
  if (key.length < 8) return "***";
  return `${key.slice(0, 7)}…${key.slice(-4)}`;
}

/**
 * Persist a key to ~/.config/domains/anthropic-key with chmod 600.
 * Atomic write (write-to-tmp + rename) so a crash mid-write cannot leave
 * a half-written secret. Parent dir is forced to mode 700 so other users
 * cannot list it.
 */
export async function persistKey(key: string): Promise<void> {
  const { atomicWrite } = await import("./atomic-write.ts");
  const dir = path.dirname(KEY_PATH);
  await fs.mkdir(dir, { recursive: true, mode: 0o700 });
  // Re-chmod the dir in case mkdir didn't apply the mode (umask interaction)
  await fs.chmod(dir, 0o700).catch(() => undefined);
  await atomicWrite(KEY_PATH, `${key}\n`, { mode: 0o600 });
}

/** Returns the on-disk key if file exists and perms are sane. */
export async function readFromConfigFile(): Promise<string | undefined> {
  try {
    const stat = await fs.stat(KEY_PATH);
    // eslint-disable-next-line no-bitwise -- POSIX mode bitmask check
    const worldOrGroupReadable = (stat.mode & 0o077) !== 0;
    if (worldOrGroupReadable) {
      throw new Error(
        `~/.config/domains/anthropic-key has unsafe permissions (${(stat.mode & 0o777).toString(8)}). ` +
          "Run: chmod 600 ~/.config/domains/anthropic-key",
      );
    }
    const content = await fs.readFile(KEY_PATH, "utf8");
    const trimmed = content.trim();
    return trimmed === "" ? undefined : trimmed;
  } catch (err) {
    const e = err as NodeJS.ErrnoException;
    if (e.code === "ENOENT") return undefined;
    throw err;
  }
}

/** Path to the config file (used in error messages and the persist prompt). */
export function configFilePath(): string {
  return KEY_PATH;
}

// -- internals --

function validateKey(key: string): void {
  if (!key.startsWith("sk-ant-")) {
    throw new InvalidAnthropicKeyError("missing sk-ant- prefix");
  }
  if (key.length < 30) {
    throw new InvalidAnthropicKeyError("too short to be a real key");
  }
  if (/\s/.test(key)) {
    throw new InvalidAnthropicKeyError("contains whitespace");
  }
}

async function maybeOfferPersist(key: string, source: string, logger: Logger): Promise<void> {
  if (process.stdin.isTTY !== true) return; // non-interactive: don't prompt
  const onDisk = await readFromConfigFile();
  if (onDisk === key) return; // already persisted, no need to ask
  const answer = (await prompt(`Save key from ${source} to ${KEY_PATH} (chmod 600)? [y/N]: `))
    .trim()
    .toLowerCase();
  if (answer === "y" || answer === "yes") {
    await persistKey(key);
    logger.ok(`saved key to ${KEY_PATH} (${mask(key)})`);
  } else {
    logger.skip(`not persisting key (${mask(key)} from ${source})`);
  }
}

function prompt(question: string): Promise<string> {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

async function promptHidden(question: string): Promise<string> {
  // Hide stdin echo for the duration of the prompt. Works on POSIX TTYs.
  process.stdout.write(question);
  const stdin = process.stdin;
  if (stdin.setRawMode === undefined) {
    // Fallback: visible prompt (rare; only on non-TTY paths)
    return prompt("");
  }
  stdin.setRawMode(true);
  stdin.resume();
  return await new Promise<string>((resolve) => {
    let buf = "";
    const onData = (chunk: Buffer): void => {
      const s = chunk.toString("utf8");
      for (const ch of s) {
        if (ch === "\n" || ch === "\r" || ch === "") {
          process.stdout.write("\n");
          stdin.setRawMode?.(false);
          stdin.pause();
          stdin.removeListener("data", onData);
          resolve(buf);
          return;
        }
        if (ch === "") {
          // Ctrl-C
          stdin.setRawMode?.(false);
          stdin.pause();
          process.exit(130);
        }
        if (ch === "" || ch === "\b") {
          // Backspace
          buf = buf.slice(0, -1);
          continue;
        }
        buf += ch;
      }
    };
    stdin.on("data", onData);
  });
}
