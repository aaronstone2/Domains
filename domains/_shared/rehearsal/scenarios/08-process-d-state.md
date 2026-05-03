# Scenario 8 — "Process is stuck and even SIGKILL won't kill it"

**Difficulty:** advanced (uncommon symptom but always interview-worthy when it appears)
**Domains exercised:** linux (debugging, filesystem, kernel)
**Time-to-resolution target:** ≤ 5 minutes for diagnosis; "fix" depends on root cause and may need reboot

---

## User opening message

> I tried to kill a stuck `rsync` process but `kill -9 <pid>` doesn't make it go away. `ps` shows the process is still there. The whole machine feels normal, this one process is just frozen. What's happening?

## SE mental model (5 seconds)

**SIGKILL not killing a process** = the process is in **uninterruptible sleep** (`D` state). The kernel cannot deliver a signal until the process returns to userspace, and it can't return until whatever syscall it's in completes. The two common D-state holders:

- **Disk I/O that's hanging** — NFS server gone, SAN failure, dying drive, software RAID rebuild stuck.
- **Filesystem op blocked** — fsync waiting on flushed data; rare on healthy disk.

The diagnostic isn't "find a way to kill it" — there isn't one short of reboot. It's "find what it's waiting on" via `/proc/<pid>/stack` (kernel call stack) and `/proc/<pid>/wchan` (the kernel function that put it to sleep).

## Harness queries

```text
$ pnpm harness lookup "process D state uninterruptible"
```

Surfaces `linux.fm.process-stuck-d-state` and load-average background reading (`brendangregg-linux-load-averages`).

```text
$ pnpm harness playbook linux.fm.process-stuck-d-state
```

Verified:

```
Patterns: D state | uninterruptible sleep | D in ps
Affects: linux.primitives.process-state-disk-sleep

-- Diagnostic steps --
  1. Confirm D state
     ps -o pid,stat,wchan,cmd -p <pid>
     expect: STAT=D, wchan = kernel function blocking
  2. Read kernel stack
     sudo cat /proc/<pid>/stack
     expect: call stack of where it's stuck
  3. Read wchan
     sudo cat /proc/<pid>/wchan
     expect: function name (e.g. nfs_wait_on_request, io_schedule)
  4. Check disk + mounts
     dmesg -T | tail -100; mount | grep -E 'nfs|cifs'

-- Fix steps --
  1. For NFS hang: umount -fl <mountpoint>
  2. For dying disk: replace + reboot
  3. Last resort: sudo reboot
```

## SE response (turn 1)

> SIGKILL ignored = the process is in `D` state (**uninterruptible sleep**). The kernel can't deliver any signal to it because it's blocked inside a syscall that promised the kernel "I won't be interrupted." It'll come out of D only when the syscall returns — usually because the underlying I/O completes. If that I/O never completes (dead NFS server, broken disk), the process stays D forever and reboot is the only escape.
>
> Confirm + diagnose where it's stuck:
>
> ```
> # 1. Confirm D state
> ps -o pid,stat,wchan,cmd -p <pid>
> # Expect STAT column = "D" or "D+", wchan = a kernel function name
>
> # 2. Get the kernel call stack — this tells you what subsystem is hung
> sudo cat /proc/<pid>/stack
>
> # 3. dmesg + mounts — look for the upstream cause
> dmesg -T | tail -100 | grep -iE 'nfs|cifs|i/o error|hung'
> mount | grep -E 'nfs|cifs|fuse'
> ```
>
> The wchan and stack output narrows the cause:
>
> | wchan / top of stack | Likely cause |
> |---|---|
> | `nfs_wait_on_request`, `nfs4_wait_for_completion`, `rpc_wait_bit_killable` | NFS server unresponsive |
> | `io_schedule`, `wait_on_buffer` | block-device I/O stuck (dying disk, controller, multipath) |
> | `cifs_demultiplex_thread`, `smb_*` | SMB/CIFS server unresponsive |
> | `fuse_get_req` | FUSE userspace daemon hung (sshfs, gocryptfs) |
> | `wait_for_completion`, `flush_workqueue` | generic kernel-thread waiting on something |
>
> Paste the wchan + stack and I'll point at the exact root cause.

## User reply (turn 2)

> ```
> $ ps -o pid,stat,wchan,cmd -p 8421
>     PID STAT  WCHAN              CMD
>    8421 D     nfs_wait_on_request  rsync /mnt/nfs/backup /local/dest
> $ sudo cat /proc/8421/stack
> [<0>] nfs_wait_on_request+0x4b/0x70
> [<0>] nfs_wait_for_request_locked+0x29/0x40
> [<0>] nfs_lock_and_join_requests+0x4ad/0x540
> [<0>] nfs_updatepage+0x71/0x180
> [<0>] nfs_write_end+0x88/0x1c0
> [<0>] generic_perform_write+0x113/0x180
> [<0>] nfs_file_write+0x1e6/0x2e0
> [<0>] vfs_write+0xc4/0x1f0
> [<0>] ksys_write+0x67/0xe0
> [<0>] do_syscall_64+0x37/0xa0
> $ dmesg -T | tail -10
> [Sat May 03 14:33:21 2026] nfs: server backup-nfs.acme.io not responding, still trying
> [Sat May 03 14:35:02 2026] nfs: server backup-nfs.acme.io not responding, still trying
> ```

## SE mental model (turn 2)

Confirmed: NFS hang. Server `backup-nfs.acme.io` isn't responding. The rsync called write() → entered NFS layer → posted an RPC → waiting for ack that's never coming. dmesg confirms — kernel printed the standard "server not responding" message.

Two paths:
- **Recover the NFS server** (proper fix; rsync may resume on its own once server's back).
- **Force-unmount on the client** (`umount -fl`) — releases the hold even if server is permanently gone.

The `-fl` flag combo: `-f` = force (don't wait for in-flight ops), `-l` = lazy (detach now, free when last reference goes away). With both, the client gives up; the rsync process gets to finish its current syscall (with EIO most likely) and can then be reaped.

## SE response (turn 2)

> Confirmed: rsync is stuck inside NFS waiting for `backup-nfs.acme.io` to respond. The server's not answering — that's the actual issue, not your process. Two paths:
>
> **Option A — fix the server** (preferred). If you can ssh into `backup-nfs.acme.io`, get it healthy. Once it accepts requests again, the kernel's NFS retry will succeed and your rsync will continue (or it'll see an error and exit gracefully). No client-side action needed.
>
> **Option B — force the client to give up** if the server is permanently gone or you can't reach it:
>
> ```
> sudo umount -fl /mnt/nfs/backup
> # -f = force (drop in-flight ops); -l = lazy (detach now, clean up later)
> ```
>
> After umount-fl, the kernel returns EIO to the pending NFS RPC, the rsync syscall exits with error, the process leaves D state, and the queued SIGKILL finally fires. The process disappears in seconds.
>
> **Both paths**: dmesg should stop logging "not responding" once the issue's resolved.
>
> **Mount-options note for next time**: bare `nfs` mounts (the default) use `hard,intr` semantics — RPCs retry forever. Add `soft,timeo=30,retrans=3` to fstab so failed RPCs return EIO instead of hanging:
>
> ```
> # /etc/fstab
> backup-nfs.acme.io:/export /mnt/nfs/backup nfs _netdev,soft,timeo=30,retrans=3 0 0
> ```
>
> Risk of `soft`: a flaky network can corrupt writes (the app sees "success" via short-write semantics that NFS can't always guarantee). For read-mostly workloads, `soft` is fine. For databases-on-NFS (don't), keep `hard`.

## User reply (turn 3)

> `umount -fl` worked, process gone. Server's still down — turns out the NFS box's disk array failed. While we wait for ops to fix it, what could prevent this from happening again on a flaky network?

## SE response (turn 3)

> Three layers of defense:
>
> **1. Mount options that fail fast** (covered above):
>
> ```
> # Read-mostly: soft + timeo + retrans is fine
> nfs _netdev,soft,timeo=30,retrans=3,vers=4.2
>
> # Read-write: keep hard but use intr (interruptible by signals after a while)
> nfs _netdev,hard,intr,timeo=600,retrans=2,vers=4.2
> ```
>
> Newer NFS versions (4.x) handle network blips better than v3 — prefer `vers=4.2`.
>
> **2. systemd auto-recovery** for the mount:
>
> ```ini
> # /etc/systemd/system/mnt-nfs-backup.mount
> [Unit]
> Description=NFS backup mount
> After=network-online.target
> Wants=network-online.target
>
> [Mount]
> What=backup-nfs.acme.io:/export
> Where=/mnt/nfs/backup
> Type=nfs
> Options=_netdev,soft,timeo=30,retrans=3
> TimeoutSec=60
>
> [Install]
> WantedBy=multi-user.target
> ```
>
> Then a watchdog timer that re-attempts on failure (covered in scenario 7's mount-recovery pattern).
>
> **3. Workload pattern** — for backups specifically, don't rsync directly to NFS. Stage to local, then ship via a separate process that can retry. Keeps the *primary* workload immune to NFS hiccups.
>
> ```
> rsync /local/source /local/staging   # always succeeds (local disk)
> systemd-run --on-active=5min --unit=push-to-nfs.service \
>   /usr/local/bin/safe-nfs-push.sh   # async, retried
> ```
>
> Cite: [systemd.mount(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html), `pnpm harness playbook linux.fm.systemd-mount-failed-fstab`.

## Follow-up question (turn 4)

> If wchan had shown `io_schedule` instead of an NFS function — different diagnosis?

## SE mental model (turn 4)

`io_schedule` = generic block-device I/O wait. The process is waiting on a buffer or page-cache flush. Cause is local block device, not network FS. Could be:
- Dying physical disk (the SSD is failing, retries are exhausting)
- Controller / SAS card issue
- Software RAID degraded and rebuilding
- Multipath failover in progress

Diagnose via `dmesg` (look for I/O errors), `iostat -x` (look for which device has high svctm/await), `smartctl -a /dev/sdX` (drive health).

## SE response (turn 4)

> `io_schedule` = block-device level wait, not network. Different diagnostic order:
>
> ```
> # 1. Look for hardware errors first
> dmesg -T | grep -iE 'i/o error|sense key|aborted command|smart|medium error'
> # Any of these = dying disk/controller; replacing is the fix.
>
> # 2. Find which device the process is waiting on
> sudo iostat -xz 1 5
> # Compare devices; one with svctm or await >>10x others is the suspect.
>
> # 3. Cross-check with the process's open file descriptors
> sudo ls -l /proc/<pid>/fd | grep -v 'pipe\|socket'
> # Match the inode to the device via stat or lsblk
>
> # 4. Drive health (if a real disk)
> sudo smartctl -a /dev/sdX | grep -iE 'reallocated|pending|uncorrectable|temperature'
>
> # 5. Software RAID rebuild?
> cat /proc/mdstat
> # Look for "[U_]" or "recovery = X%" — degraded array means slow I/O until done
>
> # 6. Multipath?
> sudo multipath -ll
> # Any failed paths?
> ```
>
> The fix depends on which signal you find. SMART pending sectors → swap drive. Multipath failover stuck → bounce the failed path. Software RAID still rebuilding → wait it out (or, if rebuild is actually stuck, walk through `mdadm --detail` and fix paths).
>
> If you can't fix the hardware in time and the process *must* die, reboot is the only path — D-state processes can't be killed any other way.

---

## Coverage notes

- **Why SIGKILL doesn't work:** the SE explained the *mechanism* (kernel can't deliver until syscall returns) before jumping to fix. This is the kind of "show your understanding" answer that interviewers grade highly.
- **wchan/stack as canonical diagnostic:** `/proc/<pid>/stack` and `/proc/<pid>/wchan` are the single best signal for D-state. Memorize.
- **NFS-specific recovery (`umount -fl`):** the `-f -l` combo is the right answer; `umount` alone fails on a busy mount.
- **Mount-options-as-prevention:** `soft,timeo,retrans` discussion shows the SE thinks beyond "fix the immediate symptom."
- **Two distinct wchan families covered:** NFS (turn 2) and io_schedule (turn 4) demonstrate different diagnostic paths from the same surface symptom.

## Practice notes for interviewer pushback

- "Why does Linux even have D state? Why not let SIGKILL through?" → kernel guarantees that some syscalls won't be interrupted (e.g., partial NFS writes that could leave a file in an inconsistent state). D state is the cost of that guarantee. There's also `TASK_KILLABLE` (D+ on some kernels) which lets SIGKILL through for syscalls explicitly marked safe.
- "Process is in D, machine is sluggish, load average is huge but CPU is idle." → Linux load average counts D-state processes. One D process = +1 to load average even though it's not on CPU. Confirms what's happening; not a separate issue.
- "How do I find ALL D-state processes at once?" → `ps -eo pid,stat,wchan,cmd | awk '$2 ~ /^D/'` or `top` then press `R` to sort by state and look for D.
- "We have a workload that legitimately blocks for 30s+ in normal NFS write — is it always going to look like a hang?" → Yes from D-state perspective. Distinguish via `dmesg` (no "not responding" = working as designed) and by knowing your workload. For unattended monitoring, alert on "D state for >5 min" not just "D state present."
- "Reboot worked but how do I prevent the next one?" → Mostly the prevention layers in turn 3 — mount options, systemd watchdog, workload-staging. For storage hardware, monitor SMART proactively and swap drives at first signs of failure (reallocated sectors growing, etc.) rather than waiting for the dying-disk D-state.
