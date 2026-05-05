// Module: apt-optional — eBPF / perf / kernel-headers tooling.
//
// Skipped under --minimal. Some kernels don't have a matching linux-headers
// package — failures here are treated as warnings, not errors.
//
// Optimization: after a failed attempt, writes a stamp keyed by kernel version
// so repeated bootstraps don't waste ~2s retrying apt on the same kernel.
// isInstalled uses native Node.js checks (no subprocess spawns).

import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const STAMP_FILE = ".apt-optional-attempted";
const BINS = ["bpftrace", "btop", "sysbench"] as const;

/** Check if a binary exists on PATH using native fs.access (no subprocess). */
async function binExists(name: string): Promise<boolean> {
  const dirs = (process.env["PATH"] ?? "").split(":");
  for (const dir of dirs) {
    try {
      await fs.access(path.join(dir, name), fs.constants.X_OK);
      return true;
    } catch { /* next */ }
  }
  return false;
}

export const aptOptionalModule: InstallerModule = {
  id: "apt-optional",
  description: "Optional heavy apt packages (eBPF tooling, perf, btop, sysbench)",
  narrative: "eBPF + perf for kernel-level tracing (bpftrace, off-CPU profiling, perf-record)",
  tags: ["apt", "optional"],

  shouldRun(config): boolean {
    return process.platform === "linux" && !config.minimal;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // Fast native check: any of the target binaries present → installed.
    for (const bin of BINS) {
      if (await binExists(bin)) return true;
    }
    // Stamp check: already tried on this kernel? Use os.release() (no subprocess).
    const stamp = path.join(ctx.home, STAMP_FILE);
    try {
      const saved = (await fs.readFile(stamp, "utf8")).trim();
      return saved === os.release();
    } catch {
      return false;
    }
  },

  async install(ctx: InstallContext): Promise<void> {
    const kernel = os.release();

    // Pre-check: if linux-headers aren't installed AND the directory doesn't
    // exist in /usr/src, the kernel is non-standard (common on DevBoxes).
    // Skip the expensive apt-get (~2s). Uses native fs — no subprocess.
    const headersDir = `/usr/src/linux-headers-${kernel}`;
    try {
      await fs.access(headersDir);
    } catch {
      // Headers dir missing — check if the package is even available via dpkg
      // (15ms vs 1s for apt-cache).
      const dpkgCheck = await ctx.runner.run(
        `dpkg-query -W -f='\${Status}' linux-headers-${kernel} 2>/dev/null`,
        { allowFailure: true },
      );
      if (!dpkgCheck.stdout.includes("install ok installed")) {
        ctx.logger.warn(
          `linux-headers-${kernel} not available — skipping eBPF/perf install (non-standard kernel)`,
        );
        await fs.writeFile(path.join(ctx.home, STAMP_FILE), kernel + "\n").catch(() => {});
        return;
      }
    }

    const pkgs: string[] = [
      "bpfcc-tools", `linux-headers-${kernel}`,
      "bpftrace",
      "linux-tools-common", "linux-tools-generic", `linux-tools-${kernel}`,
      "btop", "sysbench",
    ];
    const result = await ctx.runner.run(
      `DEBIAN_FRONTEND=noninteractive apt-get install -y ${pkgs.join(" ")}`,
      { sudo: true, stream: true, allowFailure: true },
    );
    if (result.code !== 0) {
      ctx.logger.warn(
        "some optional packages failed (often linux-headers for an unsupported kernel) — non-fatal",
      );
    }
    // Write stamp so we skip on next run (even if install partially failed).
    await fs.writeFile(path.join(ctx.home, STAMP_FILE), kernel + "\n").catch(() => {});
  },

  async verify(_ctx: InstallContext): Promise<VerifyResult> {
    const present: string[] = [];
    for (const bin of BINS) {
      if (await binExists(bin)) present.push(bin);
    }
    return {
      ok: present.length > 0,
      message: present.length > 0 ? `installed: ${present.join(", ")}` : "no optional binaries present",
    };
  },
};
