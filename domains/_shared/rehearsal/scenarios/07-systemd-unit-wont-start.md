# Scenario 7 — "My systemd unit won't start"

**Difficulty:** entry-mid (very common, well-bounded diagnosis)
**Domains exercised:** linux (systemd, debugging)
**Time-to-resolution target:** ≤ 4 minutes

---

## User opening message

> I have a systemd service for our internal collector. After a config change, `sudo systemctl start collector` returns `Failed to start collector.service: Unit collector.service has failed.` and `systemctl status` shows it as failed. Logs aren't obvious to me. What's the right diagnostic order?

## SE mental model (5 seconds)

systemd error reporting is famously layered: `systemctl status` shows a one-line summary; the real story is in `journalctl -u`. The diagnostic order:

1. **`systemctl status <unit>`** — see the immediate exit reason (active/failed, exit code, last lines of journal).
2. **`journalctl -u <unit> -e`** — full unit log with the error message from the binary.
3. **`systemd-analyze verify <unit>`** — catches malformed unit files (typo'd directives, bad paths).
4. **Permissions / ExecStart path** — does the binary exist? Is it executable? Does the User exist?
5. **StartLimitBurst** — if the unit failed N times within an interval, systemd refuses to retry.

Most failures resolve at step 2.

## Harness queries

```text
$ pnpm harness lookup "systemd unit failed start"
```

Top hits include `systemd-systemd-service-5` and the failure modes:
- `linux.fm.systemd-unit-restart-loop` — start-limit-burst exhaustion
- `linux.fm.systemd-service-killed-on-shutdown` — TimeoutStopSec
- `linux.fm.systemd-mount-failed-fstab` — fstab typo
- `linux.fm.systemd-target-reached-but-services-not-up` — dependency ordering

```text
$ pnpm harness playbook linux.fm.systemd-unit-restart-loop
```

Verified:

```
=== linux.fm.systemd-unit-restart-loop  [linux] ===
Patterns: start-limit-hit | StartLimitBurst | start request repeated too quickly

-- Diagnostic steps --
  1. View unit status + journal
     systemctl status myapp
     journalctl -u myapp -e

-- Fix steps --
  1. Raise StartLimitBurst or interval
     # [Unit] StartLimitBurst=10
     #        StartLimitIntervalSec=600s
  2. Reset failure counter manually
     sudo systemctl reset-failed myapp
     sudo systemctl start myapp
```

## SE response (turn 1)

> systemd hides the actual error in a journal entry; `status` is just a summary. Diagnostic order:
>
> ```
> # 1. Status — summary line + last 10 journal entries
> sudo systemctl status collector.service --no-pager -l
>
> # 2. Full unit log, newest first
> sudo journalctl -u collector.service -e --no-pager
>
> # 3. Verify the unit file itself isn't malformed
> sudo systemd-analyze verify collector.service
> ```
>
> Paste the output of the first two and I can usually point at the exact issue from the messages. Things to look for:
>
> | Phrase in journal | Likely cause | Fix |
> |---|---|---|
> | `status=203/EXEC` | binary missing or not executable | check `ExecStart=` path; `chmod +x` |
> | `status=200/USER` | User= refers to nonexistent user | `useradd` or fix User= |
> | `status=216/GROUP` | Group= problem | same |
> | `start request repeated too quickly` | StartLimitBurst exhausted | `systemctl reset-failed` then start |
> | `Failed to set up mount namespacing: Permission denied` | container/sandboxed unit + namespace restriction | check ProtectSystem=, NoNewPrivileges=, etc. |
> | `Configuration file ... not found` | typo'd path | check unit file paths |
>
> Citations: [systemctl(1)](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html), [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html), [systemd-analyze(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html).

## User reply (turn 2)

> ```
> $ sudo systemctl status collector
> ● collector.service - Internal Metrics Collector
>      Loaded: loaded (/etc/systemd/system/collector.service; enabled; preset: enabled)
>      Active: failed (Result: start-limit-hit) since Sat 2026-05-03 14:22:11 EDT; 5min ago
>     Process: 12345 ExecStart=/usr/local/bin/collector --config /etc/collector.yaml (code=exited, status=2)
>        CPU: 0
>
> May 03 14:22:11 host systemd[1]: collector.service: Scheduled restart job, restart counter is at 5.
> May 03 14:22:11 host systemd[1]: collector.service: Start request repeated too quickly.
> May 03 14:22:11 host systemd[1]: collector.service: Failed with result 'start-limit-hit'.
> May 03 14:22:11 host systemd[1]: Failed to start collector.service - Internal Metrics Collector.
>
> $ sudo journalctl -u collector -e --no-pager
> ...
> May 03 14:22:09 host collector[12345]: Error parsing config: yaml: unmarshal error at line 14: cannot unmarshal !!str into int
> May 03 14:22:09 host systemd[1]: collector.service: Main process exited, code=exited, status=2/INVALIDARGUMENT
> May 03 14:22:09 host systemd[1]: collector.service: Failed with result 'exit-code'.
> ...
> ```

## SE mental model (turn 2)

Two findings, in priority order:

1. **The actual cause:** YAML parse error at line 14 of `/etc/collector.yaml`. The binary started, found the bad config, exited code 2.
2. **The compounding issue:** `start-limit-hit`. After 5 quick restarts, systemd refused further attempts. This blocks restart even after fixing the config.

Fix path: fix the YAML, then `reset-failed`, then start. Don't just start — without the reset, systemd will refuse.

## SE response (turn 2)

> Two issues stacked:
>
> 1. **Real cause:** the binary's failing to parse `/etc/collector.yaml` at line 14 — looks like a string where it expects an integer. Open the file:
>    ```
>    sudo sed -n '10,18p' /etc/collector.yaml
>    ```
>    Look for something like `port: "8080"` (string-quoted number) where the schema expects `port: 8080`. YAML is strict about the difference.
>
> 2. **Compound issue:** systemd hit `StartLimitBurst` after 5 fast restarts and is now refusing to even try (that's the `start-limit-hit` result). You have to reset the counter before the next start will fire:
>    ```
>    # After fixing the YAML:
>    sudo systemctl reset-failed collector.service
>    sudo systemctl start collector.service
>    sudo systemctl status collector.service
>    ```
>
> Validate by tailing the journal during start:
>
> ```
> sudo journalctl -u collector.service -f
> ```
>
> Should now show clean startup messages, not the YAML error.

## User reply (turn 3)

> Yep — line 14 was `timeout: "30"` instead of `timeout: 30`. Fixed and started clean. To prevent the start-limit issue, what's the right tuning?

## SE mental model (turn 3)

`StartLimitBurst` and `StartLimitIntervalSec` exist for good reason — they prevent systemd from infinitely respawning a unit that's broken. But the defaults (5 in 10s) are very tight for a service that legitimately takes a few seconds to start and might fail occasionally. Loosen, don't disable.

Also worth covering: `Restart=` policy. The unit probably has `Restart=on-failure`, which is why systemd kept retrying.

## SE response (turn 3)

> Two-part fix; one is "make it less brittle," the other is "make sure config errors get caught before deploy."
>
> **A — loosen the start-limit so an occasional failure doesn't lock you out:**
>
> ```ini
> # /etc/systemd/system/collector.service
> [Unit]
> StartLimitIntervalSec=600s   # window
> StartLimitBurst=10           # max restarts in window
>
> [Service]
> Restart=on-failure
> RestartSec=5s                # wait before restart, prevents thrash
> ```
>
> 10 restarts in 10 minutes = catches genuinely broken state without locking you out for transient failures. After editing, `sudo systemctl daemon-reload`.
>
> **B — validate config before starting:**
>
> Add an `ExecStartPre=` step that runs the config-checker:
>
> ```ini
> [Service]
> ExecStartPre=/usr/local/bin/collector --config-check /etc/collector.yaml
> ExecStart=/usr/local/bin/collector --config /etc/collector.yaml
> ```
>
> If the binary supports `--config-check` (or whatever its dry-run flag is), bad config now fails the start with a clear message *before* the main process tries to start, and you don't waste 5 restart attempts.
>
> **Bonus C — for prod, also enable systemd's coredump capture so segfaults are debuggable:**
>
> ```ini
> [Service]
> LimitCORE=infinity
> ```
>
> Then `coredumpctl list collector` shows captured cores.

## Follow-up question (turn 4)

> Different unit problem: I have a `mounts/data.mount` unit that's been failing since the upstream NFS server hiccuped. NFS is back but the unit is still failed and won't auto-recover. How does that work?

## SE mental model (turn 4)

Mount units have their own quirks. `Restart=` doesn't apply to mount units the same way; they require explicit handling. The harness has the dedicated playbook:

```text
$ pnpm harness playbook linux.fm.systemd-mount-failed-fstab
```

For NFS specifically, the path is: ensure the unit can re-attempt; check `Options=` for `_netdev` (mount only after network); check `TimeoutSec=` (NFS hangs can exhaust default).

## SE response (turn 4)

> Mount units are weirder than service units. Once failed, they don't auto-restart in the same way. Path:
>
> 1. **Reset the failed state and try again manually:**
>    ```
>    sudo systemctl reset-failed mounts-data.mount
>    sudo systemctl start mounts-data.mount
>    sudo systemctl status mounts-data.mount
>    ```
>
> 2. **For NFS specifically, check the mount options include `_netdev`** so systemd waits for network:
>    ```
>    # /etc/fstab
>    server:/export /mnt/data nfs _netdev,soft,timeo=30,retrans=3 0 0
>    ```
>    `_netdev` adds an implicit dependency on `network-online.target`. `soft,timeo=30,retrans=3` makes hangs recoverable instead of D-state'ing every read.
>
> 3. **For auto-recovery on subsequent NFS hiccups**, drop a systemd timer that restarts the mount unit if it's failed:
>    ```ini
>    # /etc/systemd/system/data-mount-watchdog.timer
>    [Unit]
>    Description=Re-attempt failed data mount every 5 min
>    [Timer]
>    OnBootSec=5min
>    OnUnitActiveSec=5min
>    [Install]
>    WantedBy=timers.target
>    ```
>    ```ini
>    # /etc/systemd/system/data-mount-watchdog.service
>    [Service]
>    Type=oneshot
>    ExecStart=/bin/bash -c 'systemctl is-failed mounts-data.mount && systemctl reset-failed mounts-data.mount && systemctl start mounts-data.mount || true'
>    ```
>
> 4. **Investigate why it didn't auto-recover the first time** — look at `journalctl -u mounts-data.mount` and whether `Restart=` is set on the mount unit; mount units do support `RestartSec=` and `Restart=on-failure` in newer systemd (>= v244).
>
> Citation: `pnpm harness playbook linux.fm.systemd-mount-failed-fstab`, [systemd.mount(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html).

---

## Coverage notes

- **Two-step diagnostic ladder:** status → journalctl. Most failures land at journalctl; status is just the gateway.
- **Status-code table:** the `status=N/REASON` taxonomy (203/EXEC, 200/USER, etc.) is a common interview-day reference. Should be memorized.
- **Compounded failures:** real incidents often have a *cause* (YAML error) and a *symptom amplifier* (start-limit-hit). Both need fixing.
- **Mount-unit quirks:** different from service-unit; `Restart=` semantics changed between systemd versions. Worth knowing.

## Practice notes for interviewer pushback

- "What if `journalctl -u` is empty?" → unit didn't even start ExecStart (config-load failure). Try `journalctl -e | grep collector` (system journal) or run the binary directly: `sudo -u <user> /usr/local/bin/collector --config ...`.
- "Hardened unit (ProtectSystem=strict, NoNewPrivileges=true) fails with EACCES." → systemd's sandboxing is hiding the file. Use `systemd-analyze security collector.service` to see what's restricted; check `ReadWritePaths=` for paths the unit needs to write.
- "Started fine, then died after 30 minutes." → not a start failure, but a runtime issue. Check `Type=` (`simple` vs `notify` matters), watch `MainPID=` change, look for OOM (`dmesg`).
- "Type=notify but the daemon never sends READY=1 — systemd kills it." → ExecStart binary needs to call `sd_notify(0, "READY=1")` after init. Either fix the binary or change to `Type=simple` (loses readiness signal).
- "After upgrade, all my custom services say `unknown directive`." → systemd version mismatch. Run `systemctl --version`; some directives (RuntimeMaxSec, JoinsNamespaceOf) require newer systemd.
