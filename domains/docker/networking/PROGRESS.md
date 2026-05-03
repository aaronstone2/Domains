# `docker/networking` — PROGRESS log

Per-leaf log; rolls up into `domains/docker/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.3 — 2026-05-03 — DONE

**Inputs:** plan at `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase C). Continued from docker engine (Phase 3.1) and runtime (Phase 3.2).

**Outputs:**

| Table | Rows landed | Plan target |
|---|---:|---:|
| `docker.concepts` (`id LIKE 'docker.networking.%'`) | **56** | 55 |
| `docker.commands` (`id LIKE 'docker.networking.%'`) | **10** | 10 |
| `docker.config_keys` (`id LIKE 'docker.networking.%'`) | **100** | 100 |

Cumulative flags across 10 commands: **38**. Cumulative examples: **24**. Total networking rows: **166**.

**Verification:**

- ✓ Counts hit targets (concepts +1 — added `ip-range` concept; commands and config_keys exactly on target).
- ✓ 0 orphan source_ids across all three tables.
- ✓ 0 PK collisions.
- ✓ Concept kind distribution: driver 7, runtime-object 12, primitive 13, feature 10, concept 14.
- ✓ Config_keys scope distribution exactly per plan: network-create-flag 30, daemon.json-network 18, bridge-driver-opt 15, port-publish-syntax 12, overlay-driver-opt 10, ipvlan-driver-opt 8, macvlan-driver-opt 7.
- ✓ Spot-check 5 random rows per table — sane, source_ids resolvable.

**Method:** continued duckdb-CLI fallback. Bulk-dumped 12 networking docs to `domains/docker/raw/scratch_p3/` via `dump_networking_docs.sql`.

**Boundary respect:**

- Default-bridge / `docker0` / iptables surface owned exclusively by this leaf — engine catalogues them only as runtime-objects/feature stubs.
- `daemon.json-network` scope re-keys 18 networking-relevant daemon.json keys (bridge, bip, mtu, ip-forward, ip-masq, iptables, ip6tables, userland-proxy, dns, default-address-pools, fixed-cidr, fixed-cidr-v6, host-gateway-ip, firewall-backend, ip-forward-no-drop, dns-search, dns-opts, userland-proxy-path) under their networking semantic. Engine catalogs them under generic `daemon.json` scope; distinct PK by scope.
- `port-publish-syntax` scope owns the `-p` mini-language entirely; engine's `container-run-flag.--mount` / `restart` etc. don't overlap.
- iptables chain primitives (DOCKER, DOCKER-USER, DOCKER-ISOLATION-STAGE-1/2) live here; engine's `iptables-management` feature is a daemon-level toggle pointing here.
- Cloud-restriction / kernel-version / rootless-unsupported `property` config_keys are deliberately structural rather than user-tunable — they document hard constraints rather than knobs. This mirrors the Plan agent's framing.
- Some image-pull/image-push command surfaces could equally live in docker/runtime (registry API) or docker/engine (CLI surface). Decision: catalogued here because port-publish + image-pull/push are the network-traffic-shaped surfaces operators see; runtime leaf already owns the OCI distribution-spec primitives (chunked upload, bearer auth, etc.). P5 will wire the cross-leaf links.

**Source attribution diligence:** `wsargent-docker-cheat-sheet` (T2) used as secondary on the 4 unfetched CLI surfaces (network-ls/connect/disconnect/rm) — primary is always a T1 docker-docs-* page (network-bridge, network-firewall, etc.) where the command's behavior is described in context. No row's sole source is T2 or T3.

### Deferred to P4 (failure-modes, horizontal across all domains)

Sample failure-mode seeds for the networking layer:

1. **`Bind for 0.0.0.0:80 failed: port is already allocated`** — host port held by another process or container. Diagnose: `ss -tlnp | grep :80`, `docker ps --filter publish=80`. Fix: stop the holder or pick a different host port. Source: docker-docs-network-port-publishing.
2. **`could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network`** — `default-address-pools` exhausted or all default pools collide with on-prem subnets. Fix: configure `default-address-pools` in daemon.json with non-colliding ranges. Source: docker-docs-cli-dockerd, docker-docs-network-bridge.
3. **`Network name <X> is ambiguous`** — two networks share a name prefix. Diagnose: `docker network ls`. Fix: use full ID or rename. Source: docker-cli-network-create.
4. **iptables rules persist after stale containers, blocking new traffic** — `docker network prune` to clean up; or `iptables -t nat -F DOCKER` (last resort, restart docker after). Source: docker-docs-network-firewall.
5. **MTU mismatch silently drops large packets** — host on GRE/IPsec/VXLAN tunnel; container MTU 1500 too high. Symptom: small TCP works, large writes hang (PMTU discovery often blocked too). Fix: lower per-network or daemon-wide MTU to 1450. Source: docker-docs-network-bridge.
6. **`nf_conntrack: table full, dropping packet`** — connection-tracking table filled on heavy port-published host. Fix: bump `nf_conntrack_max` sysctl. Source: docker-docs-network-firewall.
7. **`docker stop` hang on macvlan container** — kernel restriction prevents container-to-host comms; if app does host healthcheck on stop, it hangs. Fix: also attach a bridge network for healthchecks. Source: docker-docs-network-macvlan.
8. **`Cannot connect to peer` on overlay network** — required ports 2377/tcp, 4789/udp, 7946/tcp+udp not open between hosts. Diagnose: `nc -zv <peer> 2377`; `tcpdump -i any -n udp port 4789`. Source: docker-docs-network-overlay.
9. **DNS resolution between containers fails on default bridge** — embedded DNS only works on user-defined bridges. Fix: create a user-defined network and connect both containers to it (or use legacy `--link`). Source: docker-docs-network-bridge.
10. **Container can't reach the internet despite network being up** — `net.ipv4.ip_forward=0` (disabled or sysctl not applied), or `--ip-masq=false` set. Diagnose: `sysctl net.ipv4.ip_forward`, `iptables -t nat -L POSTROUTING -n -v`. Source: docker-docs-network-firewall.
11. **`firewalld` rules wiped by reload break Docker networking** — fix: re-add docker zone + rules; or add docker.service ExecStartPost to restore rules. Source: docker-docs-network-firewall.
12. **ufw rules ignored for published ports** — Docker DNATs in `nat` table, ufw filters in `INPUT`/`OUTPUT` (filter table). Fix: rules in `DOCKER-USER` chain instead. Source: docker-docs-network-firewall.

### Deferred to P5 (relationships, horizontal)

Cross-domain edge candidates:

- `docker.networking.veth-pair` ↔ `linux.networking.veth` (kernel mechanism).
- `docker.networking.linux-bridge` ↔ `linux.networking.bridge`.
- `docker.networking.network-namespace-runtime` ↔ `linux.primitives.namespace-network` ↔ `docker.runtime.namespace-network`.
- `docker.networking.iptables-DOCKER-chain` / `iptables-DOCKER-USER-chain` ↔ `linux.networking.iptables` (kernel netfilter framework).
- `docker.networking.nftables-table` ↔ `linux.networking.nftables`.
- `docker.networking.vxlan-tunnel` ↔ `linux.networking.vxlan`.
- `docker.networking.connection-tracking` ↔ `linux.networking.nf_conntrack`.
- `docker.networking.sysctl-ip-forward` ↔ `linux.networking.sysctl` (engine catalogued daemon-side; kernel side here).
- `docker.networking.bridge-driver` ↔ `docker.engine.daemon-json` (`iptables`, `ip-masq`, `userland-proxy` keys live in engine but are surfaced through this driver).
- `docker.networking.embedded-dns-resolver` ↔ `docker.compose.compose-network` (compose `networks.<name>` config keys feed bridge-driver opts cataloged here).
- `docker.networking.swarm-routing-mesh` ↔ k8s.networking (when that leaf lands — kube-proxy IPVS routing is the analogue).
- `docker.networking.cmd.image-pull` / `cmd.image-push` ↔ `docker.runtime.{auth-bearer-token, www-authenticate, manifest-list, chunked-upload}` (CLI surface vs registry-API surface).

In-leaf edges:

- `docker-network` (object) implemented-by `bridge-driver`, `host-driver`, `overlay-driver`, `ipvlan-driver`, `macvlan-driver`, `none-driver`.
- `bridge-driver` provides `embedded-dns-resolver`, `embedded-dns`, `port-binding`, `network-alias`, `multi-network-attach` features.
- `bridge-driver` requires `iptables-nat-table` (NAT/MASQUERADE), `iptables-filter-table` (DOCKER-ISOLATION-STAGE-1/2 chains), `linux-bridge`, `veth-pair`, `network-namespace-runtime`, `sysctl-ip-forward`.
- `overlay-driver` requires `vxlan-tunnel` + the swarm control-plane port + gossip ports.
- `ipvlan-driver` / `macvlan-driver` do NOT use iptables — direct L2/L3 attachment to the parent.
- `legacy-link` is restricted-to `default-bridge`.
- `port-publish-host-binding` controlled-by `bridge-driver-opt.host-binding-ipv4` and `daemon.json-network.bridge`.
- `default-address-pools` (concept) carves into per-network `subnet-cidr` instances.
- `userland-proxy` provides hairpin/loopback bridging that pure NAT can't.
- Each `docker-network` has 0..N `network-endpoint`s (one per attached container).
- Each `network-endpoint` has 0..N `port-binding`s.

## Cross-references

- Plan file: `~/.claude/plans/read-domains-shared-sessions-phase-3-dee-shimmering-knuth.md` (Phase C)
- Predecessor leaf logs: `domains/docker/engine/PROGRESS.md`, `domains/docker/runtime/PROGRESS.md`
- Scratch dumps used this session (gitignored): `domains/docker/raw/scratch_p3/`
