# 09 — Triage: Platform bug vs customer issue + implementing fixes

> The core SE skill: figure out whose problem it is, prove it, then fix it — even when it's on the customer's side.

## The triage decision tree

```
Customer reports issue
    │
    ├─ Can I reproduce it on a clean DevBox with default config?
    │   ├─ YES → PLATFORM BUG → escalate to engineering (see §Escalation)
    │   └─ NO → likely customer-side. Continue ↓
    │
    ├─ Does it reproduce ONLY with their specific config/code/env?
    │   ├─ YES → CUSTOMER CONFIG/CODE ISSUE → fix on their side (see §Fix)
    │   └─ UNCLEAR → isolate the variable ↓
    │
    └─ Isolation: strip their config down to minimal repro
        ├─ Works with minimal config → their config delta is the cause
        ├─ Fails with minimal config → platform issue, escalate
        └─ Fails only under specific conditions → edge case, file bug + workaround
```

## Step 1: Classify — whose bug is it?

### Evidence that it's a PLATFORM bug

| Evidence | How to gather | What it proves |
|----------|---------------|----------------|
| Reproduces on clean DevBox with no customer config | `# start fresh session on public repo with default blueprint` | Not caused by customer setup |
| Multiple customers hitting same issue | Check support queue for pattern | Systemic, not config-specific |
| Recent platform change correlates with onset | Check devinstatus.com + release notes | Regression |
| Error originates in Devin-managed code (agent, orchestrator, snapshot) | Read stack trace / build log | Platform-internal |
| Works in customer's local Docker but fails in DevBox | Compare environments side-by-side | DevBox-specific behavior |

### Evidence that it's a CUSTOMER issue

| Evidence | How to gather | What it proves |
|----------|---------------|----------------|
| Works on clean DevBox, fails only with their config | Test with/without their `environment.yaml` | Config-caused |
| Error is in their code/script (syntax, logic, path) | Read the actual error + their code | Their code |
| Missing dependency / wrong version they specified | Check their `initialize:` or `setup:` sections | Their dependency |
| Env var not reaching process (scope issue) | `docker exec $C env \| grep KEY` | Their env config |
| Cert/auth error from their infrastructure | `openssl s_client` to their endpoint | Their PKI/auth |
| Works if you fix one line in their config | Change it, verify | Proves the fix |

### The gray zone: platform limitation + customer workaround

Sometimes the platform doesn't do something the customer expects (e.g., secrets not auto-injected as env vars, no VPN support out of box). This is NOT a bug — it's a **feature gap** or **documentation gap**. Handle it:

> "This is working as designed — Devin doesn't auto-inject repo secrets as environment variables. Here's how to source them: add `source /run/repo_secrets/org/repo/.env.secrets` to your `setup:` section. I'll help you update your config."

## Step 2: Prove it — the evidence collection

Before telling a customer "this is on your side," you need **proof**. Three-point proof:

```
1. REPRODUCE with their config    → confirms the symptom is real
2. FIX one variable               → shows what caused it
3. VERIFY the fix holds           → proves causation, not coincidence
```

### Proof script template

```bash
# 1. Reproduce
echo "=== Reproducing with customer config ==="
# [run their exact setup / command that fails]
# Capture: exit code, error message, logs

# 2. Isolate
echo "=== Testing without the suspected cause ==="
# [remove/change the one variable you suspect]
# If it works now → that variable is the cause

# 3. Fix + verify
echo "=== Applying fix ==="
# [apply the minimal fix]
# [run the original command again]
# If it passes → fix confirmed
```

### Talk-track for delivering the verdict

> "I've confirmed this isn't a platform issue. Here's what I found:
>
> The symptom was **[X]**. I reproduced it with your config, then isolated
> the cause to **[specific config line / env var / script line]**.
>
> When I **[changed Y]**, the issue resolved. Here's the fix I'd recommend,
> and I can implement it for you right now."

## Step 3: Implement the customer-side fix

### Fix category 1: environment.yaml / blueprint issues

**Common problems:**
- YAML syntax (indentation, quoting, mixed tabs/spaces)
- Wrong section (put command in `initialize:` vs `setup:` vs `maintenance:`)
- Missing dependency in `packages:` or `setup:`
- Secrets not sourced (need explicit `source /run/repo_secrets/...`)

**How to fix:**

```yaml
# BEFORE (broken): dependency installed in maintenance (runs every session start,
# but only AFTER the snapshot is restored — too late if the dep is needed at build time)
maintenance:
  - pip install custom-tool

# AFTER (fixed): move to initialize (runs during snapshot build — baked in)
initialize:
  - pip install custom-tool
```

```yaml
# BEFORE (broken): secret expected as env var but not sourced
setup:
  - python my_script.py   # fails: KEY_NAME not found

# AFTER (fixed): source secrets before using them
setup:
  - source /run/repo_secrets/org/repo/.env.secrets
  - python my_script.py   # now KEY_NAME is available
```

**Validation:** Trigger a new snapshot build or session, confirm the fixed section runs clean.

### Fix category 2: Dockerfile / docker-compose issues

**Common problems:**
- Missing `--init` flag (zombie processes)
- Wrong memory limit (OOMKilled)
- `NODE_EXTRA_CA_CERTS` not passed through `docker run -e`
- resolv.conf not configured for corp DNS
- Multi-stage build ARG not re-declared after FROM

**How to fix:**

```dockerfile
# BEFORE (broken): env var set in shell but not in container
# Customer runs: docker run -d my-app
# Result: NODE_EXTRA_CA_CERTS is empty inside container

# AFTER (fixed): pass env var explicitly
docker run -d -e NODE_EXTRA_CA_CERTS=/etc/ssl/custom/full-chain.pem my-app
```

```yaml
# docker-compose.yml fix for zombie processes
services:
  app:
    image: my-app
    init: true              # ← adds tini as PID 1
    environment:
      - NODE_EXTRA_CA_CERTS=/etc/ssl/custom/full-chain.pem
    dns:
      - 10.0.0.53           # ← corp DNS server
```

**Validation:** `docker exec $C env | grep KEY` confirms env var is present. `docker exec $C ps aux` confirms PID 1 is tini/init.

### Fix category 3: Script / code bugs in customer's repo

**Common problems:**
- Hardcoded paths that don't exist in DevBox
- Bash script with Windows line endings (`\r\n`)
- Missing shebang (`#!/bin/bash`)
- Wrong permissions (script not executable)
- Relative paths that break when CWD changes

**How to fix:**

```bash
# Fix Windows line endings
sed -i 's/\r$//' customer-script.sh

# Fix missing shebang
sed -i '1i#!/bin/bash' customer-script.sh

# Fix permissions
chmod +x customer-script.sh

# Fix hardcoded path
sed -i 's|/Users/customer/project|/home/user/repos/project|g' customer-script.sh
```

**Validation:** Run the script, confirm it executes without error.

### Fix category 4: Agent / AI behavior issues

**Common problems:**
- Agent stuck repeating same command (context overflow)
- Agent can't find files (wrong CWD or search path)
- Agent uses wrong tool version (snapshot has old version)
- Knowledge note misconfigured (wrong trigger, outdated content)
- Playbook gives wrong instructions

**How to fix:**

```
# Context overflow → add a knowledge note to guide the agent
Knowledge note: "When encountering [X], do [Y] instead of retrying [Z]"
Trigger: "when the agent sees error message [X]"

# Wrong tool version → update environment.yaml
initialize:
  - npm install -g tool@latest    # pin the version you need

# Agent can't find files → add to knowledge
Knowledge note: "Project structure: source code is in /src, tests in /tests,
config in /config. Always search from repo root."
```

**Validation:** Start new session, confirm agent behaves correctly.

### Fix category 5: Auth / networking / TLS

**Common problems:**
- Corp proxy requiring custom CA bundle
- SSH key not available in DevBox
- GitHub app not installed on target repo
- VPN required but not configured
- Self-signed certs not trusted

**How to fix:**

```yaml
# environment.yaml: add corp CA bundle
setup:
  - |
    cat /run/repo_secrets/org/repo/.env.secrets  # get CA cert path
    # Append corp CA to system trust store:
    sudo cp /path/to/corp-ca.pem /usr/local/share/ca-certificates/corp-ca.crt
    sudo update-ca-certificates
    export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/corp-ca.crt
```

```yaml
# environment.yaml: SSH key for private repos
secrets:
  - name: SSH_PRIVATE_KEY
    target: /home/user/.ssh/id_rsa
setup:
  - chmod 600 /home/user/.ssh/id_rsa
  - ssh-keyscan github.com >> /home/user/.ssh/known_hosts
```

**Validation:** `git ls-remote <private-repo>` succeeds. `curl https://internal-service.corp.local` returns 200.

## Step 4: Escalate (when it IS a platform bug)

### Escalation checklist

Before escalating, document:

```markdown
## Escalation: [one-line summary]

**Customer impact:** [critical/high/medium/low] — [N users affected, since when]
**Reproduction steps:**
1. [exact steps to reproduce]
2. [include session ID if Devin-specific]

**What I tried:**
- [diagnostic 1] → [result]
- [diagnostic 2] → [result]

**What I ruled out:**
- NOT customer config (tested with default config, same error)
- NOT network (connectivity confirmed)

**Current hypothesis:** [your best guess at root cause]
**Workaround provided:** [yes/no — if yes, what]
```

### Escalation paths (from job description)

| Root cause location | Escalate to | How |
|---------------------|-------------|-----|
| Devin agent code (prompt, tool use, planning) | Deployed Engineering | Internal ticket + session ID |
| DevBox infrastructure (provisioning, networking, resources) | Field IT / Platform Eng | Internal ticket + reproduction |
| Enterprise features (SSO, RBAC, audit, blueprints) | Enterprise Engineering | Internal ticket + customer org ID |
| Customer's code/config (after proving it) | **Don't escalate — fix it yourself** | Implement the fix |

### The "workaround + bug report" pattern

When the bug IS real but you can help the customer NOW:

> "I've confirmed this is a platform issue — I'm filing it with engineering.
> In the meantime, here's a workaround that should unblock you:
> **[workaround]**. I'll follow up when the fix ships."

This is the highest-value SE behavior: unblock the customer immediately, escalate properly, follow through.

## Quick reference: customer communication templates

### "It's your config"
> "I found the issue — it's in your [environment.yaml / Dockerfile / script].
> Specifically, **[line/setting]** is **[what's wrong]**. The fix is
> **[specific change]**. Want me to walk you through applying it, or I can
> make the change and send you the updated file?"

### "It's our bug"
> "This is a platform issue on our side, not something in your config.
> I've filed it with our engineering team. Here's a workaround to unblock
> you now: **[workaround]**. I'll follow up when the fix is deployed."

### "It's a feature gap"
> "Devin doesn't currently support **[X]** natively. The recommended
> approach is **[workaround/pattern]**. I can help you set this up.
> I'll also flag this as a feature request internally."

## Cross-references

- Escalation criteria: [05-methodology.md](05-methodology.md) §When to escalate
- Customer expectation management example: [RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md](RCA-EXAMPLE-MULTI-SYMPTOM-GATEWAY.md) §Customer expectation management
- Anti-patterns (don't fix before diagnosing): [07-anti-patterns.md](07-anti-patterns.md)
- Talk tracks for proposing fixes: [06-talk-tracks.md](06-talk-tracks.md)
