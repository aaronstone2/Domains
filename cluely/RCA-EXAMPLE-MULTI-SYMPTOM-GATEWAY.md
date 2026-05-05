# RCA — Multi-symptom service gateway (corp PKI + DNS + cert expiry)

> Worked example of a full root-cause analysis for the **API Gateway 503**
> ticket. Use as a reference when you face a similar multi-symptom incident
> in the interview. The pattern (decompose by error code, not by service)
> generalizes to any "N services failing simultaneously" report.

## Ticket as received

> **Subject**: API Gateway 503 — all downstream services failing
>
> Our API gateway on port 5000 is returning 503 with status 'degraded'. All 4
> downstream services (auth, metrics, database, cache) are reported as failed.
> This is a production service. We have an internal PKI with a Root CA and
> Intermediate CA. We added `NODE_EXTRA_CA_CERTS` to the environment. curl to
> the auth service works fine from inside the container, but the Node.js
> gateway can't connect. The metrics service is also failing separately.
> DB and cache connections are failing with DNS errors.

## Initial response — gateway probe

```bash
curl -s http://localhost:5000 | jq
```

Output (the structured signal we work from):

```json
{
  "status": "degraded",
  "services": {
    "auth": "failed", "metrics": "failed", "db": "failed", "cache": "failed"
  },
  "errors": [
    { "service": "auth",    "error": "unable to get issuer certificate",   "code": "UNABLE_TO_GET_ISSUER_CERT" },
    { "service": "metrics", "error": "certificate has expired",             "code": "CERT_HAS_EXPIRED" },
    { "service": "db",      "error": "getaddrinfo ENOTFOUND db.corp.internal",    "code": "ENOTFOUND" },
    { "service": "cache",   "error": "getaddrinfo ENOTFOUND cache.corp.internal", "code": "ENOTFOUND" }
  ]
}
```

## Decomposition (the talk-track move)

**4 services, 4 error messages — but only 3 distinct error CODES, so likely 3 root causes:**

| Code | Services | Hypothesis |
|---|---|---|
| `UNABLE_TO_GET_ISSUER_CERT` | auth | TLS chain incomplete — Node can't find the issuer of the leaf cert |
| `CERT_HAS_EXPIRED` | metrics | Real expiry OR clock skew |
| `ENOTFOUND` | db, cache | DNS — same root for both since they share `.corp.internal` suffix |

> **Rule**: services with the same error code likely share a root cause.
> Don't treat 4 services as 4 problems; group by error code first.

## Diagnosis

Get into the gateway container:

```bash
docker exec -it <gateway> sh
```

### Cause 1 — auth: NODE_EXTRA_CA_CERTS env var not actually injected

```sh
env | grep -i ca
# Output: only PYTHON_SHA256, PATH, REDIS_URL match "ca" by accident.
# NO NODE_EXTRA_CA_CERTS, NO SSL_CERT_FILE, NO CA_BUNDLE.
echo $NODE_EXTRA_CA_CERTS    # empty
```

**Smoking gun**: customer says they "added NODE_EXTRA_CA_CERTS to the environment" — but it's NOT in the gateway process's env. The variable exists in their *shell* (or in a config file) but never made it into the running container. Same shape as Devin Bug 101 (env var in wrong scope) but for any container, not just Devin.

Verify by inspecting the running container's config:

```bash
exit  # back to host
docker inspect <gateway> --format '{{json .Config.Env}}' | jq
```

If the array doesn't include `NODE_EXTRA_CA_CERTS`, the customer's `docker run` / compose file omits it.

### Cause 2 — metrics: real cert expiry vs clock skew

First rule out clock skew (cheap):

```sh
date -u
curl -sI https://www.google.com | grep -i ^date
```

If they match within a minute → clock is fine, expiry is real.

Then probe the metrics cert:

```sh
openssl s_client -connect metrics:443 < /dev/null 2>&1 | openssl x509 -noout -dates
# notBefore=...
# notAfter=2024-12-15T...    ← if this is in the past, cert is genuinely expired
```

Or test from Node directly (matches gateway's runtime, not curl):

```sh
node -e 'require("https").get({host:"metrics",port:443,rejectUnauthorized:true}, r => console.log("STATUS",r.statusCode)).on("error", e => console.log("ERR", e.code, e.message))'
```

Three outcomes:
- `ERR CERT_HAS_EXPIRED` → confirms the ticket; renew the cert
- `ERR ENOTFOUND` / `EAI_AGAIN` → DNS is the real issue, ticket's "CERT_HAS_EXPIRED" was stale
- `STATUS 200` → service works now; ticket was a transient blip

### Cause 3 — db + cache: DNS resolver doesn't know `.corp.internal`

```sh
cat /etc/resolv.conf
# nameserver 127.0.0.11               ← Docker's embedded DNS
# search .
# # ExtServers: [host(127.0.0.53)]    ← forwards unknown queries to host
```

Docker's resolver forwards queries it doesn't know to the **host's** systemd-resolved (127.0.0.53). If the host's systemd-resolved doesn't have a `.corp.internal` upstream configured, the query goes to public root servers and returns NXDOMAIN.

Confirm:

```sh
dig +short db.corp.internal      # empty
getent hosts db.corp.internal     # nothing
```

Try direct against a likely corp DNS (if customer provided):

```sh
dig @<corp-dns-ip> db.corp.internal   # if this resolves, host's resolver is the missing link
```

## Root causes summary

| # | Cause | Fix layer |
|---|---|---|
| 1 | `NODE_EXTRA_CA_CERTS` env var missing from gateway container | gateway deployment config (docker-compose / k8s manifest) |
| 2 | Metrics service cert genuinely expired (or DNS issue masquerading) | service-side cert renewal OR DNS fix |
| 3 | Container DNS doesn't route `.corp.internal` to corp DNS | docker networking config OR host systemd-resolved config |

## Fixes

### Fix 1 — auth (CA bundle injection)

**Immediate** (test it works):

```bash
# On the host, with the cert file accessible:
docker stop <gateway>
docker run -d --name <gateway> \
  -e NODE_EXTRA_CA_CERTS=/etc/ssl/corp/full-chain.pem \
  -v /opt/certs/full-chain.pem:/etc/ssl/corp/full-chain.pem:ro \
  ... (existing flags) ...
```

The bundle MUST contain Root CA AND Intermediate CA concatenated:

```bash
cat /opt/certs/root-ca.pem /opt/certs/intermediate-ca.pem > /opt/certs/full-chain.pem
grep -c 'BEGIN CERTIFICATE' /opt/certs/full-chain.pem  # should be 2
```

**Permanent** (docker-compose):

```yaml
services:
  gateway:
    environment:
      NODE_EXTRA_CA_CERTS: /etc/ssl/corp/full-chain.pem
    volumes:
      - /opt/certs/full-chain.pem:/etc/ssl/corp/full-chain.pem:ro
```

**Permanent** (k8s):

```yaml
spec:
  containers:
  - name: gateway
    env:
    - name: NODE_EXTRA_CA_CERTS
      value: /etc/ssl/corp/full-chain.pem
    volumeMounts:
    - name: corp-ca
      mountPath: /etc/ssl/corp
  volumes:
  - name: corp-ca
    secret:
      secretName: corp-ca-bundle
```

Verify after restart:

```bash
docker exec <gateway> env | grep NODE_EXTRA_CA_CERTS
docker exec <gateway> openssl verify -CAfile $NODE_EXTRA_CA_CERTS <(openssl s_client -connect auth:443 -showcerts </dev/null 2>/dev/null | openssl x509)
```

### Fix 2 — metrics (cert renewal)

If genuinely expired:

```bash
# Renew via your ACME / cert-manager / internal CA workflow.
# Verify new cert:
openssl s_client -connect metrics:443 </dev/null 2>&1 | openssl x509 -noout -dates
# notBefore=2026-05-05  notAfter=2027-05-05  ← good
```

Rolling restart any service that pinned the old cert into memory:

```bash
docker restart <metrics-container>
docker exec <gateway> node -e 'require("https").get({host:"metrics",port:443}, r => console.log(r.statusCode)).on("error",e=>console.log(e.code))'
# expect: STATUS 200
```

### Fix 3 — DNS for `.corp.internal`

**Immediate** (per-container override):

```bash
docker stop <gateway>
docker run -d --name <gateway> \
  --dns <corp-dns-ip> \
  --dns-search corp.internal \
  ... (existing flags) ...
```

**Permanent** (docker-compose):

```yaml
services:
  gateway:
    dns:
      - <corp-dns-ip>
      - 1.1.1.1   # public fallback
    dns_search:
      - corp.internal
```

**Better** (host-side systemd-resolved config — fixes for all containers):

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/corp.conf <<EOF
[Resolve]
DNS=<corp-dns-ip>
Domains=~corp.internal
EOF
sudo systemctl restart systemd-resolved
resolvectl status     # confirm corp.internal upstream
```

Verify:

```bash
docker exec <gateway> getent hosts db.corp.internal     # IP returned
docker exec <gateway> getent hosts cache.corp.internal  # IP returned
```

## Validation — gateway should now report healthy

```bash
curl -s http://localhost:5000 | jq '.status'
# "healthy"
curl -s http://localhost:5000 | jq '.services'
# { "auth": "ok", "metrics": "ok", "db": "ok", "cache": "ok" }
```

## Customer expectation management

> "Three independent issues converged here. The auth failure was a config bug
> on your side — the env var didn't reach the gateway process; we've moved
> it into the deployment config so it's persistent. The metrics cert was
> genuinely expired; we renewed it and rolled the service. The DB and cache
> 'DNS errors' weren't a Devin platform issue but a missing corp-DNS upstream
> in your container's resolver config; the systemd-resolved config we
> shipped routes `.corp.internal` to your corp resolver from now on.
>
> Recommend: add a smoke test to your gateway's CI that confirms each
> downstream is reachable post-deploy. Catches all three of these at deploy
> time instead of in production."

## Prevention recommendations

1. **Health check that exercises every downstream**, not just gateway-self. The gateway's own `/health` should call each downstream and surface the status — same JSON shape as the ticket's degraded output.
2. **Cert expiry monitoring** — alert at 30/14/7 days before expiry per cert across the fleet.
3. **Build-time verification of NODE_EXTRA_CA_CERTS** — add a test that loads the file and counts certs (should match expected chain depth).
4. **DNS smoke test in deployment** — `getent hosts <each-corp-host>` on container startup; fail fast if any unresolvable.
5. **Standardize on docker-compose `dns:` field** for all services that need corp resolution; don't rely on host's resolver propagating.

## Addendum — full 8-issue audit (deeper than the surface-level report)

The customer's degraded JSON listed 4 errors. Surface-level decomposition →
3 root causes (corp PKI, cert expiry, DNS). But a deeper probe inside the
container revealed **8 distinct issues**. Real-world incidents often layer.

### 1. Auth: NODE_EXTRA_CA_CERTS pointing at the WRONG file

```sh
docker exec <gateway> bash -c 'cat /var/log/app/gateway-stdout.log | grep NODE_EXTRA'
# NODE_EXTRA_CA_CERTS=/etc/ssl/custom/intermediate.crt
```

It's set — but to the **intermediate** CA, not the root. Node needs a root
CA (a self-signed trust anchor) to verify the chain; the intermediate alone
is useless.

### 2. service-config.yaml has the CORRECT path; deploy script picked the wrong key

```yaml
gateway:
  tls:
    ca_bundle:        /etc/ssl/custom/root-ca.crt          # ← CORRECT (root CA)
    node_extra_certs: /etc/ssl/custom/intermediate.crt    # ← WRONG (the intermediate)
```

Whatever templates the deploy env took `node_extra_certs` instead of
`ca_bundle`. **Bug at deploy-time, not config-time.**

### 3. Auth server-side chain is FINE

```sh
docker exec <gateway> bash -c 'echo | openssl s_client -connect auth.corp.internal:8443 -showcerts 2>&1' \
  | grep -E 'depth|verify'
# depth=2 ... CN=Corp Root CA       verify return:1
# depth=1 ... CN=Corp Intermediate  verify return:1
# depth=0 CN=auth.corp.internal     verify return:1
```

Server serves leaf + intermediate; openssl uses system trust for the root.
Server-side fine. Bug is purely client-side trust store (#1).

### 4. Metrics: zero-day cert (real expiry, port 9443 not 443)

```sh
docker exec <gateway> ss -tlnp | grep 9443
# LISTEN  *:9443  node /app/metrics-service.js

docker exec <gateway> bash -c 'echo | openssl s_client -connect metrics.corp.internal:9443 2>&1 | openssl x509 -noout -dates'
# notBefore=May  5 06:26:31 2026 GMT
# notAfter =May  5 06:26:31 2026 GMT     ← SAME timestamp; valid for 0 seconds
```

Not stale — the cert really expired the moment it was issued. Port is `9443`
per `METRICS_URL`, not 443. Cert pipeline likely has `-days 0` bug.

### 5. /etc/hosts has fake entries for auth+metrics, none for db+cache

```sh
docker exec <gateway> cat /etc/hosts
# 127.0.0.1 auth.corp.internal      ← fake stub (services run in same container)
# 127.0.0.1 metrics.corp.internal   ← fake stub
# (no db.corp.internal)
# (no cache.corp.internal)
```

Test scenario routes auth+metrics back to the same container, doesn't even
bother stubbing db+cache → genuine ENOTFOUND for those.

### 6. **ZOMBIE PROCESSES** — PID 1 doesn't reap

```sh
docker exec <gateway> ps auxf
# PID 1: sleep 86400      ← container's init is sleep, can't reap children
# PID 2410: [bash] <defunct>
# PID 2428-2438: [sleep] <defunct>   (11+ zombies, growing)
```

Classic "no init in container." Fix: `docker run --init ...` (adds tini PID 1).
Matches practice scenario `13-zombie-processes.sh`.

### 7. Memory + request-log leak

```sh
for i in $(seq 1 20); do
  curl -s http://localhost:5000 | jq '{memoryMB,requestLogSize}'
done
# {memoryMB:5,  requestLogSize:1}
# {memoryMB:5,  requestLogSize:2}
# ...
# {memoryMB:6,  requestLogSize:5}    ← memoryMB ticked up; requestLogSize linear
```

Gateway accumulates an in-memory request log without bound. Linear growth
in entries → eventual OOM. **Fix: bound the buffer (last N entries) OR
rotate to disk + logrotate.**

### 8. DB + cache: confirmed DNS root cause (same as surface-level report)

No /etc/hosts entry, no upstream DNS resolver for `.corp.internal`.

## 5-layer fix (the talk-track structure that scores high in interviews)

### Layer A — immediate inside container (prove fixes work)

```sh
# Auth: point at the actual root CA per service-config.yaml's ca_bundle field
export NODE_EXTRA_CA_CERTS=/etc/ssl/custom/root-ca.crt
kill -HUP $(pgrep -f gateway.js)

# DB + cache: temp /etc/hosts entries
echo '127.0.0.1 db.corp.internal'    >> /etc/hosts
echo '127.0.0.1 cache.corp.internal' >> /etc/hosts
```

### Layer B — deployment config (docker-compose / k8s)

```yaml
services:
  staff-tls:
    init: true                                       # fix #6: PID 1 reaping (tini)
    environment:
      NODE_EXTRA_CA_CERTS: /etc/ssl/custom/root-ca.crt   # fix #1, #2
    extra_hosts:
      - "db.corp.internal:127.0.0.1"
      - "cache.corp.internal:127.0.0.1"
    # OR (better) point at corp DNS:
    dns: [<corp-dns-ip>]
    dns_search: [corp.internal]
```

### Layer C — gateway code (fix #7 memory leak)

```js
// /app/gateway.js
const MAX_LOG = 100;
function pushLog(entry) {
  requestLog.push(entry);
  if (requestLog.length > MAX_LOG) requestLog.shift();
}
```

### Layer D — deployment script bug (fix #2 properly)

```diff
- NODE_EXTRA_CA_CERTS: ${config.gateway.tls.node_extra_certs}
+ NODE_EXTRA_CA_CERTS: ${config.gateway.tls.ca_bundle}
```

Or concatenate into a full chain:
```bash
cat /etc/ssl/custom/root-ca.crt /etc/ssl/custom/intermediate.crt > /etc/ssl/custom/full-chain.pem
NODE_EXTRA_CA_CERTS=/etc/ssl/custom/full-chain.pem
```

### Layer E — cert issuance pipeline (fix #4 zero-day cert)

Wherever metrics certs are issued — the validity is set to 0 days:
```bash
- openssl req -new -x509 -key key -out cert -days 0 ...
+ openssl req -new -x509 -key key -out cert -days 365 ...
```
Audit + repair the issuance script. Add a CI check that rejects certs with
notBefore >= notAfter.

## Validation commands (interview-ready talk track)

```sh
# Confirm all 8 fixes in one pass via the all-in-one probe:
docker exec -i <gateway> bash < practice/debug-tools/multi-symptom-probe.sh
```

Or per-fix:

```sh
docker exec <gateway> bash -c 'env | grep NODE_EXTRA_CA_CERTS'
# NODE_EXTRA_CA_CERTS=/etc/ssl/custom/root-ca.crt   ← #1, #2

docker exec <gateway> ps -eo state,cmd | awk '$1=="Z"' | wc -l
# 0   ← #6 (zombies reaped)

curl -s http://localhost:5000 | jq '.status'
# "healthy"

# Hit gateway 100 times; memory should be FLAT, not growing:
for i in $(seq 1 100); do curl -s http://localhost:5000 > /dev/null; done
docker exec <gateway> ps -o rss,cmd -p $(pgrep -f gateway.js)
# RSS should stabilize after ~50 requests (#7 fixed)
```

## Reusable in-container debug script

`practice/debug-tools/multi-symptom-probe.sh` — drop into any container,
prints all the above sections in one pass. Use:

```bash
docker exec -i <container> bash < practice/debug-tools/multi-symptom-probe.sh
```

or pipe over the network from any host that can reach github raw.

## Cross-reference — failure modes in the corpus

```bash
pnpm harness ask "Node corporate CA NODE_EXTRA_CA_CERTS empty container"
pnpm harness ask "container DNS .corp.internal ENOTFOUND"
pnpm harness ask "TLS cert expired clock skew distinguish"
pnpm harness playbook docker.fm.no-egress-network-broken
pnpm harness playbook docker.fm.dns-resolv-broken-in-container
```

## Related practice scenarios

- `19-corporate-ca-bundle.sh` — Customer App 101 (corp PKI / per-tool trust stores)
- `08-bad-resolv.sh` — DNS layer-by-layer
- `22-clock-skew.sh` — distinguish real cert expiry from clock skew
- `28-env-var-empty.sh` — Devin Bug 101 (env var not actually injected; same SHAPE as fix 1 here)
