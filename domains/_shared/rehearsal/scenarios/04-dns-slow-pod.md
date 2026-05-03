# Scenario 4 — "DNS lookups are slow inside my pods"

**Difficulty:** mid (subtle, very common, fixable in 30 seconds once diagnosed)
**Domains exercised:** k8s, linux, docker
**Time-to-resolution target:** ≤ 3 minutes

---

## User opening message

> Our pods make a lot of outbound HTTPS calls to a few external APIs (`api.stripe.com`, `s3.amazonaws.com`). Latency went from ~50 ms to ~3 seconds last week. The APIs are fine — I tested from my laptop. Inside the pods it feels like DNS is slow. How do I confirm and fix?

## SE mental model (5 seconds)

The user's already diagnosed correctly: "DNS slow inside the pods." The 3-second number is a giveaway — that's the classic glibc resolver retry timeout. Two specific causes:

1. **`ndots:5` + many search domains** (k8s default). Every external hostname is tried first as `api.stripe.com.<ns>.svc.cluster.local`, `api.stripe.com.svc.cluster.local`, `api.stripe.com.cluster.local`, **then** `api.stripe.com.`. Each NXDOMAIN takes a UDP timeout. ~500 ms × 4 = 2-3 s.
2. **CoreDNS itself is slow / overloaded** — less common; would affect cluster-internal too.

Diagnose with `cat /etc/resolv.conf` inside the pod and a timed dig. Fix with `dnsConfig.options: ndots: 2` or by using FQDN with trailing dot in app code.

## Harness queries

```text
$ pnpm harness lookup "DNS slow ndots search"
```

Verified hits include `man7-resolv-conf-5`, `k8s-dns`, `k8s-debug-services` and the matching failure modes.

```text
$ pnpm harness playbook k8s.fm.dns-pod-search-too-many
```

Verified:

```
=== k8s.fm.dns-pod-search-too-many  [k8s] ===
Patterns: search | ndots | slow dns | NXDOMAIN
Affects: k8s.networking.dns-pod-search, k8s.networking.dns-policy-clusterfirst

-- Diagnostic steps --
  1. Show pod's resolv.conf
     kubectl exec <pod> -- cat /etc/resolv.conf
     expect: search foo.svc.cluster.local svc.cluster.local cluster.local + ndots:5

-- Fix steps --
  1. Lower ndots in pod dnsConfig
     # spec.dnsConfig.options: [{name: ndots, value: "2"}]
  2. Use FQDN in code (trailing dot)
     # 'foo.svc.cluster.local.'
```

The Linux equivalent (same root cause, plain Linux, no k8s) is `linux.fm.dns-slow-ndots`:

```text
$ pnpm harness playbook linux.fm.dns-slow-ndots
```

## SE response (turn 1)

> The 3-second number is diagnostic — that's the glibc resolver retry timeout for failed lookups. K8s defaults pod resolv.conf to `ndots:5` plus a long search-domain list, which means **for any name with fewer than 5 dots, glibc tries the search domains first** before trying the name as-is. For `api.stripe.com` (2 dots) it tries:
>
> 1. `api.stripe.com.<ns>.svc.cluster.local.` → NXDOMAIN (~500 ms)
> 2. `api.stripe.com.svc.cluster.local.` → NXDOMAIN
> 3. `api.stripe.com.cluster.local.` → NXDOMAIN
> 4. `api.stripe.com.` → ✓ A record
>
> 4 round-trips per cold lookup = your 3 seconds.
>
> **Confirm:**
>
> ```
> kubectl exec <pod> -- cat /etc/resolv.conf
> ```
>
> Expect:
>
> ```
> nameserver 10.96.0.10
> search default.svc.cluster.local svc.cluster.local cluster.local
> options ndots:5
> ```
>
> Then time a query:
>
> ```
> kubectl exec <pod> -- sh -c 'time getent hosts api.stripe.com'
> kubectl exec <pod> -- sh -c 'time getent hosts api.stripe.com.'   # trailing dot = FQDN, skips search
> ```
>
> If the trailing-dot version is fast (<100 ms) and the no-dot version is slow, you've confirmed it.

## User reply (turn 2)

> Confirmed. `ndots:5`, search list as you described. Without trailing dot: 2.8s. With trailing dot: 47ms. So the search-expansion is the problem. What's the right fix?

## SE mental model (turn 2)

Two equally valid fixes; pick based on whether the user controls the app code or not.

- **Pod-side `dnsConfig.options ndots:2`** — works for any image, no code change. Safe; cluster-internal lookups still work because `kubernetes.default.svc.cluster.local` (3 dots) still triggers search.
- **App-code FQDN** — explicit, makes intent clear, but requires code change.
- **Don't recommend `ndots:1`** — too aggressive; breaks cluster-internal short names like `myservice` (0 dots).

## SE response (turn 2)

> Both fixes work; pick by what you control:
>
> **Fix A — pod-side (recommended for this case, no app change):**
>
> ```yaml
> spec:
>   dnsPolicy: ClusterFirst   # default; keeps in-cluster resolution
>   dnsConfig:
>     options:
>       - name: ndots
>         value: "2"
>   containers: [...]
> ```
>
> Now any name with 2+ dots (`api.stripe.com`, `s3.amazonaws.com`) is tried as-is first. Cluster-internal short names still expand via search.
>
> **Fix B — application code:** when calling external services, append a trailing dot:
>
> ```python
> # Python
> requests.get("https://api.stripe.com.")
> ```
>
> ```go
> // Go
> http.Get("https://api.stripe.com./...")
> ```
>
> The trailing dot tells the resolver "this is fully qualified, skip search."
>
> **Don't use `ndots:1`** — it'll break in-cluster short names like `myservice` (resolved as `myservice.<ns>.svc.cluster.local`).
>
> Validate after rolling out:
>
> ```
> kubectl exec <pod> -- sh -c 'time getent hosts api.stripe.com'
> # Expect <100 ms now
> ```

## User reply (turn 3)

> ndots:2 fixed it for the pods. But why is the k8s default `ndots:5`? Seems wasteful.

## SE response (turn 3)

> Two reasons baked into kubelet's resolv.conf generator:
>
> 1. **In-cluster service-name conventions**. K8s service DNS records have 5 dots (`<svc>.<ns>.svc.cluster.local`). With `ndots:5`, the search domain expansion is the *only* way short names like `myservice` resolve to `myservice.<ns>.svc.cluster.local`. Lower `ndots` and short-name resolution might break.
> 2. **Backward compat with apps that hardcoded short names**. Lots of legacy apps say `db` not `db.app.svc.cluster.local`; the high ndots makes that work transparently.
>
> The cost — search-amplification for external names — wasn't initially appreciated; got widely-known once everyone hit it. The k8s docs now explicitly call it out.
>
> If you control the cluster default for many namespaces and want a global fix, you can configure CoreDNS to **rewrite** stripped names so the search expansion stops failing fast (see CoreDNS `template` plugin), or you can set the `dnsConfig` cluster-wide via a mutating admission webhook. For a single team, per-pod `dnsConfig` is simpler.

## Follow-up question (turn 4)

> What if it weren't ndots — what other things make pod DNS slow?

## SE mental model (turn 4)

Other failure modes in this space (the harness has playbooks for each):

- `k8s.fm.dns-resolution-fail` — CoreDNS down or no endpoints (every lookup fails)
- `k8s.fm.coredns-loop-detection` — CoreDNS pods CrashLoopBackOff because forward `/etc/resolv.conf` loops back through the stub resolver
- `k8s.fm.networkpolicy-default-deny-too-broad` — NetworkPolicy blocking pod→CoreDNS traffic
- `linux.fm.conntrack-table-full` — host conntrack table full, UDP DNS replies dropped silently
- `linux.fm.dns-slow-ndots` — same root cause but in plain Linux containers (no k8s)

## SE response (turn 4)

> A few common runners-up (each with a dedicated playbook in the harness):
>
> - **CoreDNS down or no endpoints** — every lookup fails, not just external. `kubectl get pods -n kube-system -l k8s-app=kube-dns` and `kubectl get endpoints -n kube-system kube-dns`.
> - **CoreDNS loop-detection crash** — happens when CoreDNS's `forward .` upstream is the kubelet's `/etc/resolv.conf`, which itself points back to the stub resolver (loop). Fix: forward to a real upstream like `1.1.1.1` or fix host resolv.conf.
> - **NetworkPolicy blocking egress to kube-dns** — pods can resolve nothing because UDP/53 is blocked by a default-deny policy. Fix: explicit allow-egress to kube-dns pods on UDP/53.
> - **Conntrack table full on the node** — UDP DNS replies dropped silently when the conntrack table overflows. `dmesg | grep nf_conntrack` shows `table full`. Raise `net.netfilter.nf_conntrack_max`.
> - **Slow upstream DNS** — happens to anyone (cloudflare/route53 hiccup); usually transient. CoreDNS metrics will show.

---

## Coverage notes

- **Number-as-diagnostic:** "3 seconds" is the canonical glibc retry-timeout signature. Recognizing the number narrows the root cause space immediately.
- **Two valid fixes, picked by control:** ops-side (dnsConfig) vs app-side (FQDN). Don't push the "right" answer — explain when to use each.
- **Why-the-default:** the user's "this seems wasteful" is a real question; the answer (k8s service-name expansion) shows the SE understands the design tradeoff, not just the symptom.

## Practice notes for interviewer pushback

- "What if `time getent hosts api.stripe.com.` is *also* slow?" → the upstream resolver itself is slow. CoreDNS metrics or a test with `dig @<coredns-clusterip> api.stripe.com.` from inside the pod.
- "What about `dnsPolicy: None`?" → that disables k8s-managed resolv.conf entirely; pod uses whatever's in `dnsConfig`. Useful if you really want full control and don't need cluster DNS.
- "ndots also affects internal lookups, right?" → yes — `myservice` is 0 dots, so `ndots:2` still triggers search expansion for it (good, what you want). `myservice.app` is 1 dot, also still uses search. Only fully-qualified `api.stripe.com` (2 dots) escapes — exactly the goal.
- "CoreDNS metrics — what should I look at first?" → `coredns_dns_request_duration_seconds` p99, `coredns_forward_request_duration_seconds` (upstream latency), `coredns_dns_responses_total{rcode="NXDOMAIN"}` (search-amplification gives a flood of these).
