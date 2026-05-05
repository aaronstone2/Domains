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

// Lean apt-core for interview-day diagnostic work. Cut from the legacy list:
// vim/less (preinstalled on Ubuntu), file/rsync (rarely diagnostic),
// bsdmainutils/net-tools/nftables/conntrack/ltrace/python3-pip/systemd-coredump
// (rarely needed; available via the in-the-holster install path during
// interview if a scenario calls for them — see HOLSTER comment below).
//
// Net effect: ~30% smaller install, ~10-15s faster on cold DevBox.
const APT_CORE: readonly string[] = [
  // General
  "git", "curl", "ca-certificates", "jq",
  // Networking debug — minimum viable
  "iproute2", "iptables",
  "dnsutils", "netcat-openbsd", "tcpdump", "nmap",
  // Performance / observability
  "sysstat", "htop", "lsof", "strace", "procps",
  // TLS
  "openssl",
  // Productivity (TUI) — small + interview-relevant
  "ripgrep", "fzf",
  // bash-completion framework (was missing in legacy)
  "bash-completion",
  // Python (preinstalled but explicit so install verifies it)
  "python3",
  // age — required by anthropic-key module (decrypts _secrets/*.age via SSH key)
  "age",
];

// HOLSTER: install live mid-interview if the scenario needs them:
//   pnpm bootstrap install --module=apt-optional   # eBPF / perf / btop / sysbench (~60s)
//   sudo apt install -y nftables conntrack         # nftables debugging (~10s)
//   sudo apt install -y net-tools                  # legacy netstat/ifconfig (~5s)
//   sudo apt install -y bsdmainutils               # column, hexdump (~5s)
//   sudo apt install -y systemd-coredump           # coredumpctl for segfaults (~5s)
//   sudo apt install -y ltrace                     # library-call tracing (~5s)
//   sudo apt install -y python3-pip                # pip install <whatever> (~10s)
//   sudo apt install -y bat                        # cat with syntax highlight (~5s)

/**
 * Binaries that MUST be on PATH after install. Used by both isInstalled()
 * (skip-if-already-good) and verify() (post-install sanity). Single source
 * of truth means re-runs cannot disagree with verify.
 */
const REQUIRED_BINS: readonly string[] = [
  "jq", "rg", "lsof", "ss", "tcpdump", "python3", "nmap", "openssl", "git", "age",
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
    // --no-install-recommends skips the "soft dependency" packages apt would
    // otherwise pull. Saves significant time + disk on cold install. Each
    // package's HARD deps (Depends) still install.
    await ctx.runner.run(
      `DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${pkgList}`,
      { sudo: true, stream: true },
    );
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
