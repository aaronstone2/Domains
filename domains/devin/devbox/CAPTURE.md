# Devin DevBox capture checklist

When you have a live Devin session running, paste each block below into the DevBox shell and save the output to `domains/devin/devbox/raw/devbox-capture-YYYY-MM-DD/`. These give us a **T0 (primary-source)** snapshot of what a real DevBox actually looks like under the hood — far more credible than reading docs.devin.ai.

**Critical:** strip any tokens / secrets before committing. The repo's `.gitignore` ignores `*.token`, `*.key`, `*sensitive*` to backstop accidents — but always grep your captures for `sk-`, `ghp_`, `ssh-rsa AAAA`, etc. before `git add`.

## 1. Boot environment

```bash
mkdir -p ~/devbox-capture
cd ~/devbox-capture

uname -a                                 > 01-uname.txt
cat /etc/os-release                      > 02-os-release.txt
cat /proc/cpuinfo | head -25             > 03-cpuinfo.txt
free -h                                  > 04-free.txt
df -h                                    > 05-df.txt
mount | sort                             > 06-mount.txt
cat /proc/cgroups                        > 07-cgroups.txt
ls /sys/fs/cgroup/                       > 08-cgroup-tree.txt
ls /sys/fs/cgroup/cgroup.controllers 2>/dev/null && \
  cat /sys/fs/cgroup/cgroup.controllers  > 09-cgroup-v2-controllers.txt
```

## 2. Process tree at idle

```bash
ps auxf > 10-ps.txt
ps -eo pid,user,stat,pcpu,pmem,rss,cmd --sort=-rss | head -30 > 11-top-rss.txt
systemctl list-units --type=service --state=running --no-pager > 12-systemd-units.txt 2>/dev/null
```

## 3. Network

```bash
ip a                                     > 20-ip-a.txt
ip route                                 > 21-ip-route.txt
ip link show                             > 22-ip-link.txt
cat /etc/resolv.conf                     > 23-resolv.txt
sudo iptables -L -n -t nat               > 24-iptables-nat.txt 2>/dev/null
sudo iptables -L -n -t filter            > 25-iptables-filter.txt 2>/dev/null
sudo nft list ruleset                    > 26-nftables.txt 2>/dev/null
ss -tlnp                                 > 27-listening.txt 2>/dev/null
```

## 4. Docker state

```bash
docker version                           > 30-docker-version.txt 2>&1
docker info                              > 31-docker-info.txt 2>&1
docker ps -a                             > 32-docker-ps.txt 2>&1
docker images                            > 33-docker-images.txt 2>&1
docker network ls                        > 34-docker-networks.txt 2>&1
docker volume ls                         > 35-docker-volumes.txt 2>&1
sudo cat /etc/docker/daemon.json         > 36-daemon.json 2>/dev/null
```

## 5. Filesystem map

```bash
find / -maxdepth 2 -type d 2>/dev/null   > 40-fs-l1.txt
ls -la /home                             > 41-home.txt
ls -la /workspace 2>/dev/null            > 42-workspace.txt
ls -la / | grep -v '^total'              > 43-root.txt
cat /etc/passwd                          > 44-passwd.txt
sudo ls -la /etc/sudoers.d/ 2>/dev/null  > 45-sudoers.txt
```

## 6. Capabilities / security

```bash
cat /proc/self/status | grep -i ^cap     > 50-self-caps.txt
sudo getcap -r /usr/bin 2>/dev/null      > 51-getcap.txt
ls -la /etc/apparmor.d/ 2>/dev/null      > 52-apparmor.txt
sudo aa-status 2>/dev/null               > 53-aa-status.txt
ls /etc/audit/ 2>/dev/null               > 54-audit.txt
```

## 7. MCP wiring

In the **Devin Settings UI → MCP Marketplace**:
- Take a screenshot of which MCPs are configured
- For each, note (a) the server name, (b) which env-var keys it requires (NOT the values), (c) whether enabled by default

Save as `60-mcp-config.md`.

## 8. Devin-side discovery

```bash
# Look for Devin-managed config files in any checked-out repo
find . -name '.devin*' -type f -o -name '.devin*' -type d 2>/dev/null > 70-devin-files.txt

# Session metadata (if exposed in the workspace)
ls -la /var/log/devin/ 2>/dev/null > 71-devin-logs.txt
ls -la /opt/devin/ 2>/dev/null > 72-devin-opt.txt

# Running processes that look Devin-related
ps auxf | grep -iE 'devin|cognition' | grep -v grep > 73-devin-processes.txt
```

## After capture

1. **Grep for secrets first:**
   ```bash
   cd ~/devbox-capture
   grep -rIiE 'sk-[a-z0-9]{20,}|ghp_[a-z0-9]{20,}|ssh-(rsa|ed25519) AAAA|password\s*=\s*[^[:space:]]' . | head -20
   ```
   Manually redact anything that matches.

2. **Bundle + compress:**
   ```bash
   cd ~
   tar -czf devbox-capture-$(date +%Y-%m-%d).tar.gz devbox-capture/
   ```

3. **Move into the corpus:**
   ```bash
   mv ~/devbox-capture-*.tar.gz domains/devin/devbox/raw/
   tar -xzf domains/devin/devbox/raw/devbox-capture-*.tar.gz -C domains/devin/devbox/raw/
   ```

4. **Commit ONLY the redacted text files** — never the original .tar.gz if it might contain secrets:
   ```bash
   git add domains/devin/devbox/raw/devbox-capture-*/
   git status            # eyeball what you're staging
   git diff --cached     # eyeball the actual content one more time
   git commit -m "feat(devin): T0 DevBox state capture from Devin trial $(date +%Y-%m-%d)"
   ```

5. **Re-run extraction** so the capture lands in the corpus tables:
   ```bash
   uv run --directory domains/_shared/ingest python -m ingest --domain devin --tier T0
   ```

## Why this matters

Every fact extracted from a primary T0 capture is more credible than docs.devin.ai. When the interviewer asks "how does Devin's container runtime sandbox work?", citing `lsmod` output from your own DevBox plus a docs page is twice as compelling as citing only the docs.

## Copyright / ToS guardrail

Capturing your **own** DevBox state for personal study is fair use. Do **not** republish proprietary Cognition code/binaries. Strip tokens. Strip session IDs. Strip anything that looks like an internal endpoint URL.
