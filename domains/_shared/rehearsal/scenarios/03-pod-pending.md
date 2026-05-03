# Scenario 3 — "My pod is stuck in Pending"

**Difficulty:** mid (one symptom, ~6 distinct root causes, all common)
**Domains exercised:** k8s
**Time-to-resolution target:** ≤ 4 minutes

---

## User opening message

> I deployed a new service but the pod is stuck in Pending and never starts. `kubectl get pods` shows it's been Pending for 10 minutes. Other pods in the same namespace work fine. What do I do?

## SE mental model (5 seconds)

`Pending` = the **scheduler hasn't placed it on a node yet**. The reasons are well-bounded:

1. No node has enough free CPU/memory for the requests
2. Node selector / affinity has no matching node
3. Taints with no matching toleration
4. PVC is unbound (volume waiting for first consumer or storage class issue)
5. Image pull is in progress / failing (technically Pending until container starts)
6. PodDisruptionBudget / quota / admission webhook blocking

The single command that tells you which is `kubectl describe pod <name>` — the events at the bottom name the reason. Don't guess; read.

## Harness queries

```text
$ pnpm harness lookup "pod pending FailedScheduling"
```

Verified hits (failure_modes section):

```
[k8s] k8s.fm.taint-toleration-mismatch  (conf=0.95)  — Pods stuck Pending with FailedScheduling due to taint X but pod has toleration
[k8s] k8s.fm.pod-pending-failedscheduling  (conf=0.95)  — Pod stuck Pending; events show FailedScheduling
[k8s] k8s.fm.statefulset-pod-stuck  (conf=0.85)  — StatefulSet pod stuck Pending; subsequent ordinals can't proceed
```

```text
$ pnpm harness playbook k8s.fm.pod-pending-failedscheduling
```

Verified diagnostic steps from the playbook:

```
1. Read pod events
   kubectl describe pod <name>
   expect: FailedScheduling event with reason
2. Check node capacity
   kubectl describe nodes | grep -E 'Capacity|Allocatable|Allocated resources' -A 5
3. Check taints/tolerations
   kubectl describe nodes | grep Taints
```

Patterns the playbook lists: `FailedScheduling | didn't have free ports | insufficient cpu | insufficient memory | didn't match Pod's node affinity`.

## SE response (turn 1)

> `Pending` = scheduler hasn't placed it. The fast diagnostic is `kubectl describe`, which shows the actual reason in the Events section:
>
> ```
> kubectl describe pod <pod-name> -n <ns> | tail -30
> ```
>
> Look at the bottom for an Event like:
>
> ```
> Type     Reason            Message
> Warning  FailedScheduling  0/3 nodes are available: 3 Insufficient memory.
> ```
>
> The message is verbatim what scheduler tried and rejected. Common reasons map 1:1 to fixes:
>
> | Event message contains | Cause | Fix |
> |---|---|---|
> | `Insufficient cpu` / `Insufficient memory` | requests exceed any node's free | shrink requests, scale cluster, or change `nodeSelector` to bigger nodes |
> | `node(s) had untolerated taint {X: NoSchedule}` | taint mismatch | add `tolerations` to pod spec |
> | `node(s) didn't match Pod's node affinity/selector` | nodeSelector or affinity has no matching node | check affinity vs `kubectl get nodes --show-labels` |
> | `pod has unbound immediate PersistentVolumeClaims` | PVC isn't bound | inspect PVC + storage class |
> | `0/N nodes are available: ... didn't have free ports` | hostPort conflict | drop hostPort or move to NodePort/Service |
> | (no events at all) | scheduler isn't running, OR namespace blocked by ResourceQuota | check `kubectl get pods -n kube-system` for kube-scheduler; check `kubectl describe quota -n <ns>` |
>
> Paste the Events section back and I'll walk the specific fix.

## User reply (turn 2)

> ```
> Warning  FailedScheduling  87s (x12 over 11m)  default-scheduler
>   0/4 nodes are available: 1 node(s) had untolerated taint {nvidia.com/gpu: present},
>   3 Insufficient memory.
> ```
>
> So one node is GPU (we use it for ML), the other three don't have memory. Pod requests 8Gi memory.

## SE mental model (turn 2)

Two distinct problems in the same Event line:
- **GPU node tainted, regular workload doesn't tolerate** — by design (we don't want regular pods landing on the expensive GPU node).
- **Other 3 nodes don't have 8Gi free** — the actual blocker for this pod.

Need to know what's actually allocated vs capacity to decide between (a) shrink the pod's request, (b) add capacity, (c) free capacity by evicting something else.

## SE response (turn 2)

> Two issues bundled, but the GPU-taint one is **expected** — that node is reserved for GPU workloads. The actual blocker is "3 of 4 nodes are too full." Get the breakdown:
>
> ```
> kubectl describe nodes | grep -E 'Name:|Allocated resources' -A 5 | head -40
> ```
>
> You'll see per-node:
>
> ```
> Name: node-1
> Allocated resources:
>   cpu     2400m  (60%)
>   memory  6Gi    (75%)
> ```
>
> 6Gi used of 8Gi capacity = 2Gi free; can't fit your 8Gi pod. Cross-check against the pod's actual request:
>
> ```
> kubectl get pod <name> -o jsonpath='{.spec.containers[*].resources.requests}'
> ```
>
> Three paths in priority order:
>
> 1. **Lower the request if it's over-provisioned** (most common). Watch what the workload actually uses (`kubectl top pod` after running it for a while in a cluster with capacity), then set `requests` to actual+headroom.
> 2. **Add a node** — easy if you have cluster autoscaler, otherwise scale your node group.
> 3. **Free capacity** — find the heaviest pod that doesn't need to be where it is and reschedule (`kubectl drain` a node temporarily, or evict specific pods).
>
> If you genuinely need 8Gi, options 2/3. If the request is just inherited from a template, option 1.

## User reply (turn 3)

> Actual usage is more like 4Gi according to top. I'll lower the request. While I'm at it — the GPU taint is intentional but I want to make sure my ML pod can land on it. Reminder of how that works?

## Harness query (turn 3)

```text
$ pnpm harness playbook k8s.fm.taint-toleration-mismatch
```

Verified:

```
-- Diagnostic steps --
  1. Show taints
     kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
  2. Show pod tolerations
     kubectl get pod <p> -o yaml | grep -A20 tolerations

-- Fix steps --
  1. Add matching toleration
     # spec.tolerations: - key: dedicated, value: gpu, effect: NoSchedule
  2. Or remove the taint
     kubectl taint nodes <node> <key>=<val>:NoSchedule-
```

## SE response (turn 3)

> First, drop the request:
>
> ```yaml
> resources:
>   requests: { memory: 5Gi, cpu: 500m }
>   limits:   { memory: 8Gi, cpu: 2000m }
> ```
>
> 5Gi requests + 8Gi limit gives you headroom without locking the scheduler out (and Burstable QoS class).
>
> For the ML pod and the GPU taint: tolerations have to match the taint **exactly** — same key, value, and effect. Your taint shows `nvidia.com/gpu: present` with effect (probably `NoSchedule`). The matching toleration:
>
> ```yaml
> spec:
>   tolerations:
>     - key: "nvidia.com/gpu"
>       operator: "Equal"
>       value: "present"
>       effect: "NoSchedule"
>   nodeSelector:
>     nvidia.com/gpu: "true"   # OR use a label that's only on the GPU node
> ```
>
> The toleration says "I'm willing to land on a node with this taint"; the nodeSelector forces it (otherwise it's *willing* but not *required*, so could land anywhere).
>
> Verify:
>
> ```
> kubectl get nodes -l nvidia.com/gpu=true   # should list the GPU node
> kubectl describe pod <ml-pod> | grep -A2 Tolerations
> ```

## Follow-up question (turn 4)

> What if `kubectl describe pod` shows no events at all — just blank?

## SE mental model (turn 4)

This is rarer but specific. Three causes:
1. The scheduler isn't running (kube-scheduler crashed or unhealthy).
2. ResourceQuota is rejecting the pod before scheduling even tries.
3. An admission webhook is timing out / failing.

Test in that order — fastest signal first.

## SE response (turn 4)

> No events = scheduling never even tried. Three checks:
>
> 1. **Scheduler alive?**
>    ```
>    kubectl get pods -n kube-system -l component=kube-scheduler
>    kubectl logs -n kube-system kube-scheduler-<node> --tail=50
>    ```
>    If the pod isn't running or the log shows leader-election thrash, that's it.
>
> 2. **Namespace blocked by ResourceQuota?**
>    ```
>    kubectl describe quota -n <ns>
>    ```
>    Look for `Used >= Hard` on any axis. If quota's full, the *creation* gets rejected with `forbidden: exceeded quota` rather than producing a Pending pod — but if it's an LimitRange issue, you can have a created pod that no scheduler will look at.
>
> 3. **Admission webhook hanging?**
>    ```
>    kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration
>    kubectl get events -A | grep -i webhook | tail
>    ```
>    A failing webhook with `failurePolicy: Fail` will block pod creation entirely. The harness has the dedicated playbook: `pnpm harness playbook k8s.fm.admission-webhook-timeout`.

---

## Coverage notes

- **Decision-tree-from-message:** the table mapping FailedScheduling messages to fixes is the single highest-leverage memorization for this scenario. All 6 common causes have one canonical phrase in the Event message.
- **Two-issue parsing:** the GPU-taint message in turn 2 had two issues, only one of which was the actual blocker. SE explicitly separated them.
- **Cross-check before fixing:** "actual usage 4Gi" → reduce request, not raise capacity. Saved cluster cost.

## Practice notes for interviewer pushback

- "Pod went Pending → Running → Pending again." → That's not normal Pending; usually preemption. Look for `Preempted` event. Walk PriorityClass / preemption (`pnpm harness playbook k8s.fm.scheduler-preempt-thrash`).
- "PVC unbound — what's the diagnosis?" → `kubectl describe pvc <name>`; reason will name storage class. Either no PV available or storage class with `volumeBindingMode: WaitForFirstConsumer` (chicken-and-egg with the pod). Walk `pnpm harness playbook k8s.fm.statefulset-volume-binding-stuck`.
- "Pod has the right toleration but still won't land on the tainted node." → toleration just says "I'm *allowed*"; you also need a nodeSelector or affinity to actually force it there. Tolerations don't pull, they just don't push away.
- "Cluster autoscaler is on but didn't scale up." → Walk `pnpm harness playbook k8s.fm.cluster-autoscaler-no-fit-pending` — autoscaler may have decided the pod doesn't fit any *theoretical* new node either (wrong instance type / zone / arch).
