# Scenario 6 — "Devin can't reach our internal staging service"

**Difficulty:** mid (Devin-specific; multi-cause: VPN, proxy, cert, IP allowlist)
**Domains exercised:** devin, linux
**Time-to-resolution target:** ≤ 5 minutes

---

## User opening message

> We installed Devin last week. The agent works great for OSS PRs but it can't reach our internal staging API at `staging.internal.acme.io`. The session log shows `Could not resolve host: staging.internal.acme.io` and Devin keeps trying again. What do we configure?

## SE mental model (5 seconds)

This is the **Devin DevBox networking onboarding** problem — extremely common in enterprise rollout. The DevBox is a fresh microVM with no knowledge of the customer's internal network. Four possible mechanisms (in priority order to check):

1. **No DNS** — `staging.internal.acme.io` is internal-only; the DevBox's resolver doesn't know your internal DNS server. (Most likely given "Could not resolve host.")
2. **No VPN** — even if DNS resolves, the DevBox isn't on the internal network.
3. **Corporate HTTP proxy not set** — common in enterprises that mediate all egress.
4. **TLS cert chain not trusted** — if the internal API uses a private CA, Devin's curl/git/openssl rejects it.

The error message `Could not resolve host` strongly points at (1) or (2) — DNS or routing.

## Harness queries

```text
$ pnpm harness lookup "devin VPN proxy internal service"
```

Top hits surface `devin-docs-onboard-vpn` (the canonical onboarding doc) and `devin.fm.vpn-not-engaging`, `devin.fm.session-cant-reach-internal-svc`.

```text
$ pnpm harness playbook devin.fm.vpn-not-engaging
```

Verified diagnostic + fix steps. Plus the corporate-proxy and cert-untrusted siblings:

```text
$ pnpm harness lookup "corporate proxy 407 cannot resolve"
# → devin.fm.corporate-proxy-not-set

$ pnpm harness lookup "self-signed certificate untrusted CA"
# → devin.fm.internal-svc-cert-untrusted
```

Cross-link via:

```text
$ pnpm harness related devin.fm.session-cant-reach-internal-svc 1
# → devin.fm.vpn-not-engaging (specific-cause)
# → devin.fm.internal-svc-cert-untrusted (specific-cause)
```

## SE response (turn 1)

> "Could not resolve host" tells us it's failing at DNS, not at TCP — the DevBox has no idea where `staging.internal.acme.io` lives. Two near-paths: get the DevBox onto your network (VPN), or expose the service externally (probably not what you want).
>
> Check first: does Devin have any network-reach config at all? In your settings:
>
> - Settings → Integrations → VPN
> - Settings → Enterprise → Network setup
>
> If those are empty, you haven't configured Devin for your private network yet. The canonical setup is in [Onboarding → VPN / Private Network Setup](https://docs.devin.ai/onboard-devin/vpn).
>
> Quick decision tree:
>
> | Your situation | Recommended path |
> |---|---|
> | Internal services reachable via OpenVPN config | Add VPN to blueprint (works at session start) |
> | Internal services need IP allowlist | Use Devin's enterprise static egress IP |
> | All egress goes through corporate HTTP proxy | Set `HTTPS_PROXY` env in blueprint setup |
> | Internal services use private CA cert | Add corp CA bundle to DevBox trust store |
>
> Most teams need (1) and (4); some also need (3). What's your actual setup?

## User reply (turn 2)

> We have OpenVPN config. I added it via Settings → Integrations. But sessions still can't reach the service. Where do I check?

## SE mental model (turn 2)

VPN configured at the org level but not actually engaging in the session. Two possible reasons:
- Blueprint setup script didn't start the OpenVPN client (config alone isn't enough; something has to *run* it).
- VPN started but auth failed.

Walk via the playbook's diagnostic steps.

## SE response (turn 2)

> Org-level config is necessary but not sufficient — the DevBox has to actually start the VPN client at session boot. Diagnose:
>
> ```
> # Inside the DevBox terminal (open via session UI):
> pgrep -a openvpn
> # Expect: 12345 openvpn --config /etc/openvpn/client.conf --daemon
> # If empty → never started.
>
> ip addr show tun0
> # Expect: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> ... inet 10.x.y.z/16
> # If "Device not found" → VPN didn't establish.
>
> # If VPN tried but failed:
> sudo tail -100 /var/log/openvpn/*.log
> # Look for: AUTH_FAILED, TLS handshake fail, or "Initialization Sequence Completed"
> ```
>
> Most common cause: the blueprint's `setup` step writes the config but doesn't start openvpn. Add the start command:
>
> ```yaml
> # environment.yaml (blueprint)
> secrets:
>   - name: VPN_CONFIG
>     target: /etc/openvpn/client.conf
>   - name: VPN_AUTH
>     target: /etc/openvpn/auth.txt   # if username/password
>
> setup: |
>   sudo openvpn --config /etc/openvpn/client.conf \
>     --auth-user-pass /etc/openvpn/auth.txt \
>     --daemon --writepid /run/openvpn.pid
>   # Wait for tun0 to appear (up to 30s)
>   for i in $(seq 1 30); do
>     ip link show tun0 >/dev/null 2>&1 && break
>     sleep 1
>   done
>   ip route show table all | head
> ```
>
> Validation in next session: `ip addr show tun0` succeeds, `getent hosts staging.internal.acme.io` resolves, `curl -m5 https://staging.internal.acme.io/health` returns.

## User reply (turn 3)

> VPN comes up now (`tun0` has IP, log shows `Initialization Sequence Completed`). But Devin still gets `Could not resolve host`. From the terminal I can `curl https://10.50.1.5/health` (the IP) but not by name.

## SE mental model (turn 3)

VPN is up but DNS isn't using the internal resolver. OpenVPN can push DNS via `dhcp-option DNS x.x.x.x` but the systemd-resolved or `/etc/resolv.conf` on the DevBox needs to actually accept it.

Two fixes:
- VPN server pushes DNS and DevBox honors it (configure `--up` script that updates resolv.conf).
- Hardcode the internal DNS server in `/etc/resolv.conf` via blueprint.

## SE response (turn 3)

> VPN got you the route, but DNS is still using the public resolver — that's why IP works and name doesn't. Fix in the blueprint setup:
>
> **Option A — let VPN push DNS (cleaner if your VPN config supports it):**
>
> The OpenVPN config should have `dhcp-option DNS 10.50.1.1` (or similar). On the DevBox side, add an `up` script:
>
> ```yaml
> setup: |
>   # Tell OpenVPN to update resolv.conf when it connects
>   sudo apt-get install -y openvpn-systemd-resolved
>   sudo openvpn --config /etc/openvpn/client.conf \
>     --auth-user-pass /etc/openvpn/auth.txt \
>     --daemon --writepid /run/openvpn.pid \
>     --setenv PATH /usr/sbin:/usr/bin:/sbin:/bin \
>     --up /etc/openvpn/update-systemd-resolved \
>     --down /etc/openvpn/update-systemd-resolved \
>     --down-pre
> ```
>
> **Option B — hardcode internal DNS in blueprint (simpler, less elegant):**
>
> ```yaml
> setup: |
>   echo 'nameserver 10.50.1.1' | sudo tee /etc/resolv.conf
>   echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf  # fallback for public
>   echo 'search internal.acme.io' | sudo tee -a /etc/resolv.conf
> ```
>
> Validate after re-launching session:
>
> ```
> getent hosts staging.internal.acme.io
> # Expect: 10.50.1.5 staging.internal.acme.io
> curl -v https://staging.internal.acme.io/health
> # Expect: 200 OK
> ```

## Follow-up question (turn 4)

> Worked! Now Devin's git ops to our internal Bitbucket Server (bitbucket.internal.acme.io) fail with `SSL certificate problem: self signed certificate in certificate chain`. Same blueprint?

## SE mental model + harness query (turn 4)

The third sibling fm — `devin.fm.internal-svc-cert-untrusted`. Internal CA needs to be added to the DevBox trust store.

```text
$ pnpm harness playbook devin.fm.internal-svc-cert-untrusted
```

Verified fix: inject corporate CA via secrets + `update-ca-certificates`. Plus per-language stores for Java/Node.

## SE response (turn 4)

> Yes — your internal Bitbucket cert is signed by your corporate CA, which the DevBox base image doesn't trust by default. Add the CA bundle to the trust store via blueprint:
>
> ```yaml
> # environment.yaml
> secrets:
>   - name: CORP_CA
>     target: /usr/local/share/ca-certificates/corp.crt   # NOTE: must end in .crt
>
> setup: |
>   sudo update-ca-certificates   # rehashes /etc/ssl/certs/
>   # Verify:
>   openssl s_client -connect bitbucket.internal.acme.io:443 -servername bitbucket.internal.acme.io < /dev/null 2>/dev/null \
>     | openssl x509 -noout -issuer
>   # Expect: issuer=CN=Acme Internal Root CA
> ```
>
> Caveat — some language runtimes have their own trust stores and won't see the system update:
>
> | Runtime | Add CA |
> |---|---|
> | Java | `keytool -import -trustcacerts -keystore $JAVA_HOME/lib/security/cacerts -file /usr/local/share/ca-certificates/corp.crt -alias corp-ca` |
> | Node.js | `export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/corp.crt` (in .bashrc) |
> | Python (requests) | `export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt` |
> | curl | uses system store after `update-ca-certificates` ✓ |
> | git | uses system store ✓ |
>
> Add the language-specific lines for whatever stack Devin will use to your blueprint setup.

---

## Coverage notes

- **Devin-specific knowledge:** corpus has the canonical setup doc (`devin-docs-onboard-vpn`) plus three dedicated fms for the most common Devin networking failures. SE didn't have to invent the answer.
- **Decision-tree-from-error-message:** "Could not resolve host" → DNS path (not TCP); SE didn't waste time checking iptables.
- **VPN ≠ DNS:** turn 3 shows the SE recognizing that VPN routing alone doesn't bring DNS along — a subtle gotcha.
- **Per-runtime trust stores:** turn 4 covers the (very common) follow-up that "system trust" isn't always enough.

## Practice notes for interviewer pushback

- "We have a corp HTTP proxy not VPN — different setup?" → Yes; walk `pnpm harness playbook devin.fm.corporate-proxy-not-set`. Set `HTTPS_PROXY` + `NO_PROXY` for cluster IPs in blueprint setup. Also configure git, npm, apt, pip independently — each has its own proxy mechanism.
- "Static IP allowlist instead of VPN?" → Devin enterprise tier offers static egress IPs. Settings → Enterprise → Network. Cite this without VPN.
- "VPN works for me locally but not for Devin" → check VPN config doesn't require split-tunnel exclusions for paths the DevBox needs (Devin control plane, GitHub). Otherwise the tunnel captures everything and breaks Devin's own outbound.
- "DNS resolves but TCP times out" → routing problem. Check `traceroute` from inside DevBox; the path may be missing a route to the internal subnet. VPN might push only specific routes via `--route` directives.
- "Cert added but Java still rejects" → JVM trust store has its own format (JKS); `update-ca-certificates` doesn't touch it. Use `keytool` explicitly. Or set `-Djavax.net.ssl.trustStore` to a custom store.
