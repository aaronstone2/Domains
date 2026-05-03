# Phase 7 — Harness Rehearsal Prompts (15 realistic interview scenarios)

Goal: validate corpus depth and harness usability for AI Support Engineer scenarios at Cognition. Each prompt simulates a Devin user reporting a problem.

## Prompt 1 — "My container exited with code 137. What happened?"
- Tool: `harness lookup "exit 137 OOM"` then `harness playbook docker.fm.exit-137-oomkilled`
- Expected: surfaces docker.fm.exit-137-oomkilled and linux.fm.cgroup-memory-oom-kill; playbook walks docker inspect → dmesg → memory.events → raise --memory or fix leak

## Prompt 2 — "Why does my Docker container's process not die when I send SIGTERM?"
- Tool: `harness lookup "SIGTERM ignored container PID 1"` → `harness playbook linux.fm.pid1-not-reaping-zombies` and `docker.fm.docker-stop-hangs-10s`
- Expected: explains PID 1 init semantics, recommends --init / tini

## Prompt 3 — "Pod stuck Pending: 'had taints, that pod did not tolerate'"
- Tool: `harness playbook k8s.fm.taint-toleration-mismatch`
- Expected: shows kubectl describe steps, taint vs toleration matching

## Prompt 4 — "DNS lookups inside my Devin DevBox are 5x slower than my laptop"
- Tool: `harness lookup "DNS slow ndots"` → playbook on linux.fm.dns-slow-ndots and k8s.fm.dns-pod-search-too-many
- Expected: explains ndots search expansion; recommends ndots:1 or FQDN

## Prompt 5 — "Kubernetes pods OOMKilled even though node has free memory"
- Tool: `harness related linux.primitives.cgroup-v2 3` to see chain
- Expected: cgroup memory.max → OOM, distinct from system OOM

## Prompt 6 — "Builds randomly fail with 'no space left on device' but df shows 50% free"
- Tool: `harness lookup "no space left disk full"` → `harness playbook docker.fm.disk-full-overlay2-leaked` and `linux.fm.disk-full-but-df-shows-free-space`
- Expected: inode exhaustion vs orphan layers diagnosis

## Prompt 7 — "iptables flush broke all my docker port-forwarding"
- Tool: `harness playbook docker.fm.iptables-docker-chain-flushed`
- Expected: explains DOCKER vs DOCKER-USER chain, restart docker recovery

## Prompt 8 — "pod's ConfigMap edit isn't reaching the app"
- Tool: `harness playbook k8s.fm.configmap-not-updating`
- Expected: subPath vs full mount, kubelet sync interval

## Prompt 9 — "Devin's snapshot resume is slow on first session of the day"
- Tool: `harness playbook devin.fm.snapshot-cold-boot-slow`
- Expected: warm pool sizing + pre-warm scheduling

## Prompt 10 — "kubelet says PLEG is not healthy"
- Tool: `harness playbook k8s.fm.kubelet-pleg-unhealthy`
- Expected: containerd backlog, restart container runtime

## Prompt 11 — "iptables rule order is denying my allowed traffic"
- Tool: `harness playbook linux.fm.netfilter-rule-order`
- Expected: list with --line-numbers, INSERT vs APPEND

## Prompt 12 — "How does Devin run untrusted code? What's the isolation model?"
- Tool: `harness related devin.devbox.microvm 3`
- Expected: walks to firecracker.vmm.firecracker-vmm and linux.primitives.namespace-subsystem

## Prompt 13 — "My eBPF script fails with 'verifier failed'"
- Tool: `harness playbook linux.fm.bpf-verifier-rejects`
- Expected: bound loops, use kfunc

## Prompt 14 — "How do I profile a hot Go service?"
- Tool: `harness lookup "perf flame graph CPU"` → playbook on linux.fm.flame-graph-flat and methodology.fm.flame-graph-flat
- Expected: --call-graph dwarf, frame pointers

## Prompt 15 — "Container can't reach internet, can ping localhost"
- Tool: `harness lookup "container network unreachable bridge"`
- Expected: surfaces docker network firewall + ip_forward + bridge-driver concepts
