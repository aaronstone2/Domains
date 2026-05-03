# Scenario 9 — "docker pull fails 'unauthorized'"

**Difficulty:** mid (one symptom, ~5 different mechanisms, common in interview rotation)
**Domains exercised:** docker, k8s, linux, devin
**Time-to-resolution target:** ≤ 4 minutes

---

## User opening message

> CI started failing this morning with `Error response from daemon: pull access denied for myorg/myapp, repository does not exist or may require 'docker login'`. Nothing changed in CI config. The image definitely exists; I can pull it from my laptop. Why?

## SE mental model (5 seconds)

Five distinct mechanisms behind "pull access denied" / "unauthorized":

1. **Credentials missing or expired** on the CI runner specifically. Most likely given "works locally."
2. **Token rotated** (ECR/GAR/short-lived registries) — `docker login` token expired since the runner last refreshed.
3. **Wrong registry/path** — repo name typo, or the registry is gated by IP allowlist that the runner isn't on.
4. **Docker Hub anonymous rate limit** hit (different error: `toomanyrequests`, but lay user often reports them together).
5. **Repository policy / RBAC change** upstream — admin restricted who can pull.

The error wording (`pull access denied for ...repository does not exist or may require 'docker login'`) is *specifically* the "no/bad creds" message. That narrows to (1) or (2).

## Harness queries

```text
$ pnpm harness lookup "image pull unauthorized denied registry"
```

Surfaces:
- `docker.fm.image-pull-private-registry-auth` — primary
- `docker.fm.image-pull-rate-limit` — for Docker Hub anonymous
- `docker.fm.image-pull-architecture-mismatch` — different (image platform)
- `ecs.task-defs.fm.cannot-pull-container-error-auth` — ECS sibling
- `k8s.fm.imagepullbackoff` — k8s surfacing of same root cause

```text
$ pnpm harness playbook docker.fm.image-pull-private-registry-auth
```

Verified:

```
=== docker.fm.image-pull-private-registry-auth  [docker] ===

-- Diagnostic steps --
  1. Show docker auth file
     cat ~/.docker/config.json | jq .auths
     expect: entry for the registry hostname
  2. Test auth manually
     curl -u USER:PASS https://<registry>/v2/
     expect: 200 OK or 401

-- Fix steps --
  1. Re-login
     docker login <registry>
  2. For ECR: refresh token
     aws ecr get-login-password --region us-east-1 \
       | docker login --username AWS --password-stdin \
       <account>.dkr.ecr.us-east-1.amazonaws.com
```

## SE response (turn 1)

> The exact message `pull access denied for ... repository does not exist or may require 'docker login'` is docker's catch-all for "you have no/bad credentials for this registry." Docker can't tell from a 401 whether the repo is private+you're not authed or doesn't exist; it shows this generic message either way.
>
> Three quick checks on the runner:
>
> ```
> # 1. What credentials does the docker daemon think it has?
> cat ~/.docker/config.json | jq .auths
> # OR if using a credential helper:
> docker-credential-<helper> list
>
> # Expect an entry for your registry. If the registry hostname is missing, no creds at all.
>
> # 2. Test auth directly against the registry's v2 API
> curl -u "$USER:$PASS" -I https://<registry>/v2/myorg/myapp/manifests/latest
> # 200 = auth + repo OK
> # 401 = auth bad
> # 404 = auth OK but repo/tag wrong
>
> # 3. What registry is the image actually on? (Common typo source)
> docker pull myorg/myapp:latest        # implies docker.io
> docker pull ghcr.io/myorg/myapp:latest # explicit
> ```
>
> Walk back what changed between when CI worked and now. The most common patterns:
>
> | If your registry is | Likely cause | Fix |
> |---|---|---|
> | Docker Hub (private) | password rotated; token revoked | `docker login docker.io` with new creds |
> | AWS ECR | token expired (12-hour lifetime) | `aws ecr get-login-password \| docker login` in CI before each pull |
> | GHCR (ghcr.io) | PAT rotated/expired | new GitHub PAT with `read:packages`; `docker login ghcr.io` |
> | Google Artifact Registry | service-account JSON key rotated | `gcloud auth configure-docker` |
> | Self-hosted Harbor/Nexus | network ACL change, password rotated | re-login; check IP allowlist |
>
> Which registry, and any pattern in the timestamps?

## User reply (turn 2)

> It's ECR (`123456789.dkr.ecr.us-east-1.amazonaws.com/myorg/myapp:v0.42`). Yeah, looking at our CI history, this same job hit a similar failure 12 hours ago that auto-recovered on a retry. So the 12-hour token thing fits.

## SE mental model (turn 2)

Confirmed: ECR token expiry. The login command produces a token valid for 12 hours; if your CI's been running with a stale `docker login`, the token expires and pulls start failing. Fix: refresh the token in every CI job, not once at runner setup.

## SE response (turn 2)

> ECR tokens are intentionally short-lived (12 hours). The fix is to refresh the docker login at the start of every CI job, not once when the runner is provisioned:
>
> ```yaml
> # Most CI providers — run before any docker pull/build
> - name: Login to ECR
>   run: |
>     aws ecr get-login-password --region us-east-1 \
>       | docker login --username AWS --password-stdin \
>           123456789.dkr.ecr.us-east-1.amazonaws.com
> ```
>
> If you use GitHub Actions, the official action does this for you:
>
> ```yaml
> - uses: aws-actions/amazon-ecr-login@v2
> # Subsequent docker pull/build/push commands inherit the auth.
> ```
>
> Validate by checking docker config gets refreshed — `~/.docker/config.json` will have an `auth` entry that's a freshly-encoded token.
>
> **Bonus** — for cluster-side (k8s/ECS) ECR access, prefer **IRSA** (IAM Roles for Service Accounts) on EKS or task IAM role on ECS, instead of stuffing static creds in a Secret. The kubelet/agent fetches a fresh ECR token automatically using the assumed role. No 12-hour expiry pain.

## User reply (turn 3)

> The same image fails to pull in our EKS cluster too — pods stuck `ImagePullBackOff`. Same fix?

## SE mental model + harness query (turn 3)

The k8s sibling fm:

```text
$ pnpm harness playbook k8s.fm.imagepullbackoff
```

For EKS + ECR specifically, the canonical fix is IRSA — the node's instance role grants ECR pull, no Secret needed. If the cluster used a static `imagePullSecret` and the secret expired, that's the symptom.

## SE response (turn 3)

> Same root cause (expired ECR token), different mechanism in k8s land. Two patterns:
>
> **Pattern A — node IAM role (most EKS clusters):** the EC2 instance running kubelet has an IAM role that includes `AmazonEC2ContainerRegistryReadOnly`. Kubelet calls ECR with that role's credentials — no docker login involved. Token never expires (the role can fetch a new one anytime). If pulls work for some images and not others, suspect repo policy. If pulls fail for *everything*:
>
> ```
> # On a node, check the role:
> aws sts get-caller-identity   # confirm assumed role
> aws ecr get-authorization-token --region us-east-1   # should succeed
> ```
>
> **Pattern B — `imagePullSecrets` in pod spec (manual creds):** you stuffed a token into a Secret and now it's stale. This is the less-good pattern; you have to rotate every 12 hours. Fix it by switching to Pattern A.
>
> If you really need imagePullSecrets (e.g. multi-account ECR cross-pull), set up a CronJob that refreshes the Secret:
>
> ```yaml
> # Refresh ECR creds every 6h (well within the 12h token life)
> apiVersion: batch/v1
> kind: CronJob
> metadata:
>   name: ecr-cred-refresh
> spec:
>   schedule: "0 */6 * * *"
>   jobTemplate:
>     spec:
>       template:
>         spec:
>           serviceAccountName: ecr-cred-refresher  # IRSA-bound
>           containers:
>             - name: refresh
>               image: amazon/aws-cli
>               command: ["sh","-c"]
>               args:
>                 - |
>                   TOKEN=$(aws ecr get-login-password --region us-east-1)
>                   kubectl create secret docker-registry ecr-creds \
>                     --docker-server=123456789.dkr.ecr.us-east-1.amazonaws.com \
>                     --docker-username=AWS --docker-password="$TOKEN" \
>                     --dry-run=client -o yaml | kubectl apply -f -
>           restartPolicy: OnFailure
> ```
>
> But seriously, just use IRSA / node role.
>
> Diagnose pod-side meanwhile:
>
> ```
> kubectl describe pod <name> | grep -A5 -i 'failed\|pull'
> # Look for: "Failed to pull image ... no basic auth credentials"
> # Or:        "ImagePullBackOff" with timestamps
>
> kubectl get events --field-selector involvedObject.name=<pod> --sort-by=.lastTimestamp | tail
> ```

## Follow-up question (turn 4)

> Devin sometimes hits docker pull rate limit errors when building from Docker Hub images. Different error?

## SE mental model + harness query (turn 4)

Different fm — `docker.fm.image-pull-rate-limit`:

```text
$ pnpm harness playbook docker.fm.image-pull-rate-limit
```

Docker Hub anonymous pulls are limited to ~100 pulls per 6h per IP, ~200 with free auth, unlimited with paid. From a shared CI/cloud egress (or Devin's shared egress IP), this hits fast.

## SE response (turn 4)

> Different mechanism, similar wording but distinguishable. Docker Hub rate-limit error:
>
> ```
> Error response from daemon: toomanyrequests: You have reached your pull rate limit.
> You may increase the limit by authenticating and upgrading: https://www.docker.com/increase-rate-limits
> ```
>
> The `toomanyrequests` keyword is the giveaway (vs `denied`/`unauthorized`).
>
> Three fixes in order of effort:
>
> **1. Authenticate** (jumps from anonymous limit to authed limit):
>
> ```yaml
> # Devin blueprint setup:
> setup: |
>   echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
> ```
>
> Even a free Docker Hub account doubles your limit.
>
> **2. Mirror Docker Hub in a private registry** (ECR, GAR, Harbor) and pull from there. Most cloud registries have built-in mirroring. For ECR:
>
> ```
> # One-time per image set
> aws ecr create-repository --repository-name docker-hub-mirror/library/alpine
> # Then in Dockerfile / k8s manifests:
> # FROM 123456789.dkr.ecr.us-east-1.amazonaws.com/docker-hub-mirror/library/alpine:3.19
> ```
>
> **3. For Devin specifically, use the [Devin Docker Hub mirror documentation](https://docs.devin.ai/onboard-devin/network)** — Devin can be configured to route Docker Hub through an org's private mirror. This is the cleanest enterprise pattern.

---

## Coverage notes

- **Wording-as-diagnostic:** "pull access denied / repository does not exist" vs "toomanyrequests" vs "no basic auth credentials" — three distinct error messages mapping to three distinct fms.
- **ECR-specific 12-hour expiry:** non-obvious unless you've seen it. SE recognized the pattern immediately from "auto-recovered on retry."
- **Cluster-side variants:** turn 3 walks the k8s/EKS equivalent and offers the right architectural fix (IRSA over imagePullSecrets).
- **Devin Docker Hub mirror:** turn 4 surfaces the Devin-specific solution to the rate-limit problem.

## Practice notes for interviewer pushback

- "We use Harbor with cert auth and the cert rotated last week." → docker login uses different mechanism (mTLS); check `~/.docker/config.json` for `identitytoken` or wrap with `docker --tlscert/--tlskey`. Or use the `cred-helper` binary that authenticates with cert.
- "Pull works for some tags, fails for others." → repo policy (which tags you can pull) or image is in a different registry. `docker manifest inspect <image>` shows where docker tries to fetch from.
- "Login succeeds but pull still fails 'unauthorized'." → token doesn't have *pull* scope. Some registries issue scope-limited tokens; the login token might only have `push`. Re-issue with explicit pull scope.
- "Anonymous pulls work but authenticated pulls fail." → password mismatch *most* of the time; less common but possible: the registry is returning a 403 (forbidden) and docker shows generic 401 message. `curl` directly confirms.
- "ECR pull fails with `denied` even with valid IAM role." → cross-account ECR? The role needs `ecr:GetAuthorizationToken` *plus* the resource-based repo policy on the *other* account's ECR repo allowing your role's principal. Walk `pnpm harness playbook ecs.agent.fm.cross-account-ecr-pull-denied`.
