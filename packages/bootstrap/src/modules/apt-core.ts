// Module: apt-core — always-installed packages every interview-day diagnostic
// scenario assumes are present. This is the BIG safety net: if any of these is
// missing, the user gets cryptic errors mid-interview.
//
// Distinct from apt-optional (eBPF/perf/headers) which is gated by --minimal.
//
// Bug fixed in v1.1:
//   - Legacy v1 used `dpkg-query -W -f='${Status}' ...` inside a JS template
//     string. JS interpolated ${Status} to undefined, so isInstalled() always
//     returned false → apt-get reran every install. Fixed by single-quoting
//     the format string with `\${...}` escapes (or using PATH-presence as the
//     install signal, which is what verify() uses anyway).
//   - isInstalled() and verify() now check the SAME signal (binaries on PATH)
//     so a partial install can't be misreported as "installed".

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const APT_CORE: readonly string[] = [
  // General
  "git", "curl", "ca-certificates", "jq", "vim", "less",
  // Networking debug
  "iproute2", "iptables", "nftables", "conntrack",
  "dnsutils", "netcat-openbsd", "tcpdump", "net-tools", "nmap",
  // Performance / observability
  "sysstat", "htop", "lsof", "strace", "ltrace", "procps", "bsdmainutils",
  // Files / process
  "file", "rsync", "openssl",
  // Productivity (TUI)
  "ripgrep", "fzf",
  // Editors / paging niceties
  "bat",
  // Completion framework — was missing in legacy bootstrap
  "bash-completion",
  // Python — required by methodology examples + offcputime-bpfcc bindings
  "python3", "python3-pip",
  // Coredump support — referenced by cluely cheatsheet for exit code 139
  "systemd-coredump",
  // age — modern file encryption with SSH-key recipients. Used by the
  // anthropic-key module to decrypt _secrets/anthropic-key.age in the repo
  // using the user's existing ~/.ssh/id_* private key (zero-paste install).
  "age",
];

/**
 * Binaries that MUST be on PATH after install. Used by both isInstalled()
 * (skip-if-already-good) and verify() (post-install sanity). Single source
 * of truth means re-runs cannot disagree with verify.
 */
const REQUIRED_BINS: readonly string[] = [
  "jq", "rg", "lsof", "ss", "tcpdump", "python3", "nmap", "openssl", "git",
];

export const aptCoreModule: InstallerModule = {
  id: "apt-core",
  description: "Apt packages: network/perf/process/python/coredump diagnostics + bash-completion",
  narrative: "32 diagnostic + dev tools — jq, ripgrep, lsof, tcpdump, python3, age, nmap, bash-completion",
  tags: ["apt", "core"],

  shouldRun(): boolean {
    return process.platform === "linux";
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    // PATH-presence is the signal that matches verify(). Avoids the legacy
    // dpkg-query JS-interpolation bug entirely.
    for (const bin of REQUIRED_BINS) {
      if (!(await ctx.runner.commandExists(bin))) return false;
    }
    return true;
  },

  async install(ctx: InstallContext): Promise<void> {
    await ctx.runner.run("apt-get update -y", { sudo: true, stream: true, allowFailure: true });
    const pkgList = APT_CORE.join(" ");
    await ctx.runner.run(`DEBIAN_FRONTEND=noninteractive apt-get install -y ${pkgList}`, {
      sudo: true,
      stream: true,
    });
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const missing: string[] = [];
    for (const bin of REQUIRED_BINS) {
      if (!(await ctx.runner.commandExists(bin))) missing.push(bin);
    }
    if (missing.length > 0) {
      return { ok: false, message: `missing on PATH: ${missing.join(", ")}` };
    }
    return { ok: true, message: `${REQUIRED_BINS.length} required binaries present` };
  },
};
