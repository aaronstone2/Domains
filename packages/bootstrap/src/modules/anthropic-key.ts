// Module: anthropic-key — provision the Anthropic API key on disk by
// decrypting the repo's encrypted file using the user's SSH key.
//
// THE PATTERN: at one-time setup, the user encrypts their sk-ant-... with
// their SSH public key (`age -R ~/.ssh/id_ed25519.pub --encrypt`). The
// resulting ciphertext lives at <repo>/_secrets/anthropic-key.age and is
// safe to commit even to a public repo (nothing without the SSH PRIVATE
// key can decrypt it).
//
// At install time on any box that has BOTH:
//   - the user's SSH private key at ~/.ssh/id_ed25519 (or id_rsa)
//   - the `age` binary on PATH (installed by apt-core)
// this module decrypts the file and writes the plaintext key to
// ~/.config/domains/anthropic-key (chmod 600, parent dir 700) using the
// shared atomic-write helper.
//
// Result: `git clone && ./bootstrap.sh install` is zero-paste on any box
// where the user already has their SSH key.
//
// To create the encrypted file the FIRST time:
//   pnpm bootstrap key encrypt    # interactive: prompts for the key, writes _secrets/anthropic-key.age
// (or do it manually:
//   age -R ~/.ssh/id_ed25519.pub -o _secrets/anthropic-key.age <<< "sk-ant-..."  )

import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";

import { configFilePath, persistKey } from "../lib/secrets.ts";
import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const ENCRYPTED_REPO_PATH = "_secrets/anthropic-key.age";

/**
 * Find the user's SSH private key. Returns the first that exists from a
 * priority-ordered list of conventional paths.
 */
async function findSshPrivateKey(home: string): Promise<string | undefined> {
  const candidates = [
    path.join(home, ".ssh", "id_ed25519"),
    path.join(home, ".ssh", "id_ecdsa"),
    path.join(home, ".ssh", "id_rsa"),
  ];
  for (const c of candidates) {
    try {
      await fs.access(c, fs.constants.R_OK);
      return c;
    } catch {
      // try next
    }
  }
  return undefined;
}

export const anthropicKeyModule: InstallerModule = {
  id: "anthropic-key",
  description:
    "Decrypt _secrets/anthropic-key.age with user's SSH key → ~/.config/domains/anthropic-key (chmod 600)",
  tags: ["secrets"],

  shouldRun(config): boolean {
    // Only meaningful on Linux (relies on age + ssh-key conventions).
    if (process.platform !== "linux") return false;
    // Only run if the encrypted file actually exists in the repo.
    // The orchestrator's isInstalled check requires the encrypted file present.
    void config;
    return true;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    const enc = path.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    // No encrypted file → nothing for this module to do.
    try {
      await fs.access(enc);
    } catch {
      return true; // "installed" in the sense of "no work to do"
    }
    // Encrypted file exists. Are we already provisioned?
    try {
      await fs.access(configFilePath());
      return true;
    } catch {
      return false;
    }
  },

  async install(ctx: InstallContext): Promise<void> {
    const enc = path.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    try {
      await fs.access(enc);
    } catch {
      ctx.logger.skip(
        `${ENCRYPTED_REPO_PATH} not present in repo — nothing to decrypt. ` +
          `Create it with: pnpm bootstrap key encrypt`,
      );
      return;
    }

    if (!(await ctx.runner.commandExists("age"))) {
      throw new Error("age binary not found on PATH (should have been installed by apt-core)");
    }

    const sshKey = await findSshPrivateKey(ctx.home);
    if (sshKey === undefined) {
      throw new Error(
        "no SSH private key found at ~/.ssh/id_ed25519, id_ecdsa, or id_rsa. " +
          "Either add one (ssh-keygen -t ed25519), or set ANTHROPIC_API_KEY directly.",
      );
    }

    ctx.logger.info(`decrypting ${ENCRYPTED_REPO_PATH} using ${sshKey}`);
    const result = await ctx.runner.run(`age --decrypt -i ${shQuote(sshKey)} ${shQuote(enc)}`, {
      allowFailure: true,
    });
    if (result.code !== 0) {
      throw new Error(
        `age decryption failed (exit ${result.code}). The encrypted file may not be encrypted ` +
          `for this SSH key. To re-encrypt: pnpm bootstrap key encrypt. stderr: ${result.stderr.trim()}`,
      );
    }
    const key = result.stdout.trim();
    if (!key.startsWith("sk-ant-")) {
      throw new Error(
        `decrypted content does not look like an Anthropic key (no sk-ant- prefix). ` +
          `Did you encrypt the right thing?`,
      );
    }
    await persistKey(key);
    ctx.logger.ok(`provisioned ${configFilePath()} (chmod 600) from encrypted file`);
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const enc = path.join(ctx.config.repoDir, ENCRYPTED_REPO_PATH);
    try {
      await fs.access(enc);
    } catch {
      return { ok: true, message: "no encrypted key file (skipped)" };
    }
    try {
      const stat = await fs.stat(configFilePath());
      // eslint-disable-next-line no-bitwise
      if ((stat.mode & 0o077) !== 0) {
        return {
          ok: false,
          message: `${configFilePath()} has unsafe perms ${(stat.mode & 0o777).toString(8)} (want 600)`,
        };
      }
      return { ok: true, message: `${configFilePath()} present + chmod 600` };
    } catch {
      return { ok: false, message: `${configFilePath()} missing` };
    }
  },

  /** Snapshot existing key file (if any) so failed install can roll back. */
  async snapshotState(): Promise<unknown> {
    try {
      const content = await fs.readFile(configFilePath(), "utf8");
      return { existed: true, content };
    } catch {
      return { existed: false };
    }
  },

  async rollback(ctx: InstallContext, state: unknown): Promise<void> {
    const s = state as { existed: boolean; content?: string };
    if (!s.existed) {
      try {
        await fs.unlink(configFilePath());
      } catch {
        // ignore
      }
      return;
    }
    if (s.content !== undefined) await persistKey(s.content.trim());
    ctx.logger.warn(`rolled back ${configFilePath()} to pre-install state`);
  },
};

void os; // referenced for future use; lint-quiet

function shQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}
