// Module: apt-optional — eBPF / perf / kernel-headers tooling.
//
// Skipped under --minimal. Some kernels don't have a matching linux-headers
// package — failures here are treated as warnings, not errors.

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

export const aptOptionalModule: InstallerModule = {
  id: "apt-optional",
  description: "Optional heavy apt packages (eBPF tooling, perf, btop, sysbench)",
  narrative: "eBPF + perf for kernel-level tracing (bpftrace, off-CPU profiling, perf-record)",
  tags: ["apt", "optional"],

  shouldRun(config): boolean {
    return process.platform === "linux" && !config.minimal;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // Use bpftrace as the canary — it's the most useful and most distinctive.
    return await ctx.runner.commandExists("bpftrace");
  },

  async install(ctx: InstallContext): Promise<void> {
    const kernel = (await ctx.runner.capture("uname -r")).trim();
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
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const present: string[] = [];
    for (const bin of ["bpftrace", "btop", "sysbench"]) {
      if (await ctx.runner.commandExists(bin)) present.push(bin);
    }
    return {
      ok: present.length > 0,
      message: present.length > 0 ? `installed: ${present.join(", ")}` : "no optional binaries present",
    };
  },
};
