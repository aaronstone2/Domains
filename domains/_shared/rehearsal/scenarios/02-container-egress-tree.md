# Scenario 2 — "My container can't reach the internet"

**Difficulty:** mid (vague symptom, branchy decision tree)
**Domains exercised:** docker, linux, k8s
**Time-to-resolution target:** ≤ 5 minutes; depends on which branch is the cause

---

## User opening message

> I just spun up a container with `docker run -it ubuntu bash` and `curl google.com` from inside it hangs forever. Container's the only one on the host. What do I check?

## SE mental model (5 seconds)

This is a **branchy diagnosis tree** — "no egress" has many root causes and the right next question is "where in the path does it break?" Don't jump to a fix. Build a layer-by-layer probe so the user partitions the failure for you in one shot.

The harness has an explicit umbrella fm:

```text
$ pnpm harness lookup "container cannot reach internet"
```

Hit: `docker.fm.container-no-egress-umbrella` (umbrella) plus its specific causes (`host-firewall-blocks-docker`, `no-masquerade-bridge`, `embedded-dns-misroute`, `container-egress-vpn-conflict`, `iptables-docker-chain-flushed`, `linux.fm.ip-forward-disabled`, `linux.fm.netfilter-rule-order`).

```text
$ pnpm harness related docker.fm.container-no-egress-umbrella 2
```

Verified — at depth 1, the umbrella connects to:
- docker.networking.{bridge-driver, docker-network, gateway-ip, iptables-DOCKER-chain}
- linux.fm.ip-forward-disabled
- linux.fm.netfilter-rule-order

At depth 2, it reaches docker.networking.{embedded-dns, iptables-DOCKER-USER-chain, iptables-nat-table, macvlan-driver, none-driver, overlay-driver, published-port, veth-pair}, linux.networking.{iptables-chain, ipv4-protocol, netfilter-hook-chain}, linux.primitives.network-namespace, **and k8s.fm.networkpolicy-blocking** (sibling failure mode in the k8s world).

## Harness umbrella playbook

```text
$ pnpm harness playbook docker.fm.container-no-egress-umbrella
```

Verified diagnostic steps:

```
1. Test layers in order: localhost, gateway, external
   docker exec <c> sh -c 'ping -c1 127.0.0.1 && \
     ip route show default | head -1 && \
     ping -c1 $(ip route show default | awk "{print \$3}") && \
     ping -c1 8.8.8.8 && \
     getent hosts example.com'
2. Check host has IP forwarding
   sysctl net.ipv4.ip_forward
3. Check DOCKER chains exist + masquerade present
   sudo iptables -t nat -L DOCKER -n
   sudo iptables -t nat -L POSTROUTING -n | grep MASQ
4. Check DOCKER-USER chain doesn't drop
   sudo iptables -L DOCKER-USER -n -v
```

Fix steps: enable ip_forward → restart docker → add docker0 to firewall trusted zone.

## SE response (turn 1)

> Container egress can break at half a dozen places — let me partition the failure first. Run this one-liner inside the container; it tests each layer in order:
>
> ```
> docker exec <c> sh -c 'echo "L1 loopback:" && ping -c1 127.0.0.1 && \
>   echo "L2 default route:" && ip route show default | head -1 && \
>   echo "L3 gateway reach:" && ping -c1 $(ip route show default | awk "{print \$3}") && \
>   echo "L4 external IP:" && ping -c1 8.8.8.8 && \
>   echo "L5 DNS:" && getent hosts example.com'
> ```
>
> The first line that fails tells me which branch we're on:
>
> | Failing layer | Likely cause | Next step |
> |---|---|---|
> | L1 loopback | container's own networking broken | check `--network=none`, missing `lo`; very rare |
> | L2 no default route | bridge driver didn't assign one (or `--network=none`) | inspect `docker network inspect bridge` |
> | L3 gateway unreachable | bridge isn't bridging — `docker0` interface down or wrong IP | `ip addr show docker0` on host |
> | L4 external IP unreachable | NAT/MASQUERADE missing OR ip_forward off OR host firewall | jump to host-side checks |
> | L5 DNS only | embedded DNS broken or upstream resolver dead | check `/etc/resolv.conf` inside container |
>
> Citations: [docker bridge driver](https://docs.docker.com/engine/network/drivers/bridge/), [packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/).

## User reply (turn 2)

> L1, L2, L3 all fine. L4 fails (`8.8.8.8` 100% loss). L5 obviously also fails since DNS goes upstream. So gateway works but external doesn't.

## SE mental model (turn 2)

This is the most common branch — "gateway reachable, external isn't." It maps to one of:
1. **`net.ipv4.ip_forward=0`** on the host — kernel won't forward packets between docker0 and eth0.
2. **MASQUERADE rule missing** — `iptables -t nat -L POSTROUTING` should have a `MASQUERADE` rule for the bridge subnet. Docker installs this on start; lost if someone ran `iptables -F` or `firewalld` reset rules.
3. **Host firewall (firewalld/ufw) intercepting** before docker's chains.
4. **VPN client (Tailscale, OpenVPN) installed a conflicting route** that captures the egress traffic.

## SE response (turn 2)

> Layer 4 = host can't NAT your container's traffic out. Three quick host-side checks:
>
> ```
> # 1. IP forwarding enabled?
> sysctl net.ipv4.ip_forward
> # expect: net.ipv4.ip_forward = 1
>
> # 2. MASQUERADE rule exists for the bridge subnet?
> sudo iptables -t nat -L POSTROUTING -n -v | grep MASQ
> # expect: a MASQUERADE line for 172.17.0.0/16 (or your custom bridge)
>
> # 3. Host firewall isn't dropping forwarded traffic?
> sudo systemctl is-active firewalld ufw 2>/dev/null
> sudo iptables -L FORWARD -n -v | head -10
> ```
>
> Most likely answer: forwarding is off (`= 0`) or someone flushed iptables and the MASQUERADE rule is missing.

## User reply (turn 3)

> `net.ipv4.ip_forward = 0`. Found it. How do I fix permanently — the host reboots and I want this to stick.

## SE response (turn 3)

> Two-step: enable now, then persist:
>
> ```
> # Enable now (takes effect immediately, lost on reboot)
> sudo sysctl -w net.ipv4.ip_forward=1
>
> # Persist across reboots (drop a snippet, keep ours separate from distro defaults)
> echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-docker-fwd.conf
> sudo sysctl --system   # apply all snippets
> ```
>
> Validate: `curl -m5 https://google.com` from inside the container now succeeds. To roll back: delete `/etc/sysctl.d/99-docker-fwd.conf` and `sudo sysctl -w net.ipv4.ip_forward=0`.
>
> **Why this happens:** docker requires forwarding to NAT container traffic out the host's eth0. Some hardened images / cloud-init AMIs default it to 0, and on systemd-managed machines `systemd-sysctl` resets it on reboot from `/etc/sysctl.conf` and `/etc/sysctl.d/`. Cite: [docker network firewall guide](https://docs.docker.com/engine/network/packet-filtering-firewalls/).

## Follow-up question (turn 4)

> What if the same symptom showed up in a Kubernetes pod instead of a docker container?

## SE response (turn 4)

> The umbrella's `related` walk surfaces `k8s.fm.networkpolicy-blocking` at depth 2 — which is the most common k8s-specific cause of "pod can't reach external." Different mechanism (NetworkPolicy is a CNI-enforced rule, not iptables on the host), but same observable symptom.
>
> **K8s-specific diagnosis:**
>
> 1. Check if any NetworkPolicies exist in the pod's namespace:
>    ```
>    kubectl get networkpolicy -n <ns>
>    ```
>    A `default-deny-egress` policy is the usual culprit — it blocks all egress unless explicitly allowed.
>
> 2. If you find one, you need an explicit allow-egress rule (and don't forget DNS):
>    ```yaml
>    spec:
>      egress:
>        - to:
>            - namespaceSelector:
>                matchLabels:
>                  kubernetes.io/metadata.name: kube-system
>              podSelector:
>                matchLabels:
>                  k8s-app: kube-dns
>          ports: [{port: 53, protocol: UDP}]
>        - to:
>            - ipBlock: { cidr: 0.0.0.0/0, except: [10.0.0.0/8] }
>          ports: [{port: 443, protocol: TCP}]
>    ```
>
> 3. The host-side `ip_forward` and iptables checks still apply — k8s nodes need forwarding too. Most distros (kubeadm, kubespray, EKS AMIs) set it correctly out of the box, but check first if you suspect host-side.
>
> Cite: `harness playbook k8s.fm.networkpolicy-default-deny-too-broad` for the full NetworkPolicy gotcha walk.

---

## Coverage notes

- **Branchy diagnosis vs single root cause:** scenario design that asks "where does it break" up front, not "what's the fix" — partitions the search space in one round-trip.
- **Cross-layer probe one-liner:** the L1→L5 layered ping/getent ladder is the highest-information single command for this symptom space. Memorize it.
- **K8s parallel:** `harness related` walks the umbrella to `k8s.fm.networkpolicy-blocking` automatically — the corpus already encodes that egress-failure has different mechanisms in docker vs k8s but the same observable symptom.

## Practice notes for interviewer pushback

- "What if L1 fails too?" → user did `--network=none` or `--cap-drop=NET_RAW` (ICMP needs CAP_NET_RAW). Use `nc -z 127.0.0.1 22` instead of ping.
- "What if everything works from `docker exec` but the application's network calls hang?" → app is using a different namespace (CLONE_NEWNET in code), or DNS resolves to a stale embedded-DNS entry — `harness playbook docker.fm.embedded-dns-stale-after-rename`.
- "Containerd-only host (no docker daemon) — same diagnosis?" → yes for ip_forward, no for the DOCKER iptables chains. Containerd doesn't manage iptables; the user's CNI does (e.g. `bridge` plugin). Walk `/etc/cni/net.d/` instead.
- "What if it's `--network=host`?" → host networking shares the host's namespace; no NAT, no docker0. Diagnosis collapses to "is the host able to reach the internet?"
