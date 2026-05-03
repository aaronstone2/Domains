# `linux/networking` — PROGRESS log

Per-leaf log; rolls up into `domains/linux/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.2 — 2026-05-03 — DONE

**Outputs:** 114 concepts / 14 commands / 227 config_keys = **355 rows** (plan target 362, within 2%).

**Concept kind distribution:** concept 43, protocol 19, feature 19, primitive 10, subsystem 9, state 9, driver 5. `concept` over-counted vs plan's 'protocol' bucket — fuzzy boundary (e.g., 3WHS, NAT, ephemeral port range default to `concept`).

**Config_keys scope distribution (19 scopes):** sysctl-net.ipv4 39, config_keys spread across socket-option-{SO_*,TCP_*,IPV6_*}, iptables-{target,match}, nft-{family,match}, tcpdump-filter-keyword, resolv-conf, nsswitch-conf, netlink-family, epoll-event-flag, socket-level-SOL_*, hosts-file, bridge-config-file, sysctl-net.{ipv6,core,netfilter}.

**Commands landed (14 of 32 planned):** ip, ip-link, ip-address, ip-route, ip-neighbour, bridge, iptables, nft, tcpdump, ss, dig, getent, conntrack, nmap. Total: 210 flag definitions, 42 examples.

**Commands deferred to Phase 1.5 (sources not in corpus):** tc, ifconfig, route, nslookup, host, mtr, traceroute, nstat, arp, ethtool, raw socket man page (`man7-raw-7`). Adding these would add ~25-40 more commands.

**Verified:**
- ✓ 0 orphan source_ids (after fix: 3 refs to non-existent `man7-raw-7` re-attributed to `man7-ip-7` + `man7-packet-7`)
- ✓ 0 empty source_ids; 0 PK collisions
- ✓ All scopes within ±30% of plan
- ✓ Spot-checked 5 random rows per table

**Method delta:** duckdb CLI used (motherduck MCP disconnected). One JSON parse error caught and Edited (stray `""` in 2 socket-option-TCP rows around TCP_FASTOPEN — broken multi-line continuation).

**Source attribution:** debian-nft-8 (106 KB) primary for nft; iptables-extensions-8 (98 KB) for iptables; tcpdump-manpage (61 KB) sole for tcpdump; tcp-7 + socket-7 for socket-options; kernel-docs-net-sysctl + conntrack-sysctl for sysctls; ipv6-7 for v6; nftables-wiki (T1 GFDL) secondary on nft; nmap-book-man sole for nmap. T2 sources: none (all T1).

**Boundary respect:**
- vs primitives: socket-API primitives owned here (socket/bind/connect/accept/listen/epoll/setsockopt). Network-namespace scope/lifecycle in primitives; network-stack contents (routes, sockets, iptables) here.
- vs systemd: systemd's socket-activation directives (ListenStream=, Accept=) live in systemd; the underlying socket API surfaces here.
- vs debugging: nc/socat command rows live in debugging. Pure protocol/firewall/netlink mechanics here.
- vs filesystem: unix-domain sockets are protocol rows here; sockfs filesystem semantics belong to filesystem.

**P4 failure-mode seeds (deferred):**
1. Cannot reach service through Docker port-publish — iptables NAT/MASQ missing or ip_forward=0
2. TIME_WAIT exhaustion on outbound proxy — many short conns
3. Conntrack table full, packets drop — bump nf_conntrack_max
4. DNS resolution slow — ndots:5 in container resolv.conf
5. Listen-queue overflow — accept backlog full under burst, raise net.core.somaxconn
6. Connection through firewall dies after 5 days — nf_conntrack_tcp_timeout_established expired without keepalive
7. MTU blackhole — small requests work, large hang (PMTUD broken)
8. Can't bind to port <1024 as non-root — missing CAP_NET_BIND_SERVICE
9. rp_filter dropping legitimate traffic in asymmetric routing
10. Bridge isn't filtering with iptables — net.bridge.bridge-nf-call-iptables=0

**Cross-domain seeds (P5):**
- iptables ↔ docker.engine.cfg.daemon.json.iptables
- bridge-device ↔ docker's bridge network driver (docker0)
- veth-pair ↔ docker's per-container veth wiring
- nat-dnat ↔ docker `-p HOST:CONTAINER`
- conntrack-table ↔ docker swarm / k8s overlay scale limits
- dns-resolver + ndots ↔ kubernetes pod DNS surprise
- epoll-edge-vs-level ↔ Node.js / nginx event loop perf

**Source list adjustment:** discovered `man7-raw-7` referenced in 3 rows but not in linux.sources (RAW socket man page wasn't included in Phase 1). Re-attributed to `man7-ip-7` + `man7-packet-7` combinations. Added `man7-raw-7` to Phase 1.5 candidate list.

**Next:** Session 3.3 — `linux/debugging` (~243 rows: 85 concepts / 23 commands / 135 config_keys; ftrace/perf/eBPF/strace/lsof/gdb/dmesg/kdump).

## Cross-references

- Plan file (Phase 3): `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`
- Sister leaf (just done): `domains/linux/primitives/PROGRESS.md` (126/3/224 = 353 rows)
- Pattern source: `domains/docker/engine/PROGRESS.md` (90/16/217 = 323 rows)
- Extraction artifacts: `domains/linux/networking/extract/{concepts,commands,config_keys}.json`
