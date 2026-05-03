# `linux/filesystem` — PROGRESS log

Per-leaf log; rolls up into `domains/linux/PROGRESS.md` and `domains/_shared/PROGRESS.md`.

## Phase 3 — Concepts / Commands / Config-keys

### Session 3.5 — 2026-05-03 — DONE

**Outputs:** 91 concepts / 14 commands / 219 config_keys = **324 rows** (plan target 335; landed 3% under).

**Concept kind distribution:** concept 29, driver 20, feature 14, file 12, primitive 7, state 6, subsystem 3.

**Commands (14 of 15 planned):** mount, umount, lsblk, blkid, losetup, mkfs.ext4, tune2fs, mkfs.xfs, mkfs.btrfs, lvm, pvcreate, vgcreate, lvcreate, cryptsetup. ~190 flags + ~28 examples.

**Config_keys scopes (21):** mount-option-common 22, mount-option-ext4 21, mount-option-xfs 11, mount-option-overlayfs 11, mount-option-tmpfs 9, mount-option-btrfs 10, proc-control-file 16, sysfs-attribute 11, open-flag 18, openat2-flag 6, inotify-watch-mask 15, fanotify-event-type 7, iouring-option 9, fstab-field 6, xattr-namespace 4, acl-entry-format 5, cryptsetup-option 6, stat-field 11, statfs-field 10, symlink-behavior 3, inode-field 7.

**Verified:**
- ✓ 0 orphan source_ids (after fixing 2 errors: source_ids missing on all 219 config_keys initially [bulk-backfilled by scope]; man7-mkfs-ext4-8 → debian-mkfs-ext4-8 in 5 references)
- ✓ 0 PK collisions
- ✓ Spot-check 5 random rows: all sane

**Method delta:** TWO bugs caught and fixed during load:
1. Concepts JSON had 4 missing-comma syntax errors (`pam_umask)."source_ids":` should have been `pam_umask).","source_ids":`). Bulk-fixed via Python regex.
2. config_keys.json was authored without source_ids on any row (forgot the field while batch-writing). Bulk-backfilled by scope using a scope→canonical-sources lookup table (mount-option-* → man7-mount-8/+specific; open-flag → man7-open-2; etc.).

**Source attribution:**
- man7-mount-8 (100 KB) primary for mount command + mount-option-* scopes
- kernel-docs-vfs (59 KB) for VFS subsystem concepts
- man7-lvcreate-8 (48 KB) sole for lvcreate
- man7-open-2 (46 KB) primary for open-flag scope
- man7-fanotify-7 (40 KB) primary for fanotify-event-type
- kernel-docs-overlayfs (36 KB) primary for mount-option-overlayfs + overlayfs concepts
- man7-mkfs-xfs-8 (32 KB) for mkfs.xfs
- man7-cryptsetup-8 (31 KB) for cryptsetup command + cryptsetup-option scope
- man7-io-uring-7 (27 KB) for iouring-option
- debian-mkfs-ext4-8 (26 KB) for mkfs.ext4
- man7-inotify-7 (26 KB) for inotify-watch-mask
- man7-tune2fs-8 (25 KB) for tune2fs
- man7-mount-2 (23 KB) for mount-syscall concept
- man7-mkfs-btrfs-8 (21 KB) for mkfs.btrfs + mount-option-btrfs
- man7-lvm-8 + pvcreate + vgcreate (~50 KB combined) for LVM commands
- man7-symlink-7, man7-acl-5, man7-proc-5, man7-openat2-2, man7-stat-2, man7-lsblk-8, man7-blkid-8, man7-tmpfs-5, kernel-docs-tmpfs, man7-inode-7, man7-path-resolution-7, man7-umount-8, man7-statfs-2, man7-losetup-8, man7-fstab-5, man7-xattr-7, man7-sysfs-5, kernel-docs-ramfs-rootfs-initramfs, man7-fsync-2, man7-umount2-2

T2 sources: none (all T1).

**Boundary respect:**
- vs primitives: mount(2)/umount(2) syscall semantics + mount-flag-MS_* live in primitives (kernel-side flag definitions). Filesystem owns the user-tools (mount(8)/umount(8)) and per-FS mount options. Mount-namespace propagation concepts in primitives; mount-syscall as a primitive concept here.
- vs networking: unix-domain socket files (filesystem entries) referenced here only as concept (the protocol lives in networking).
- vs systemd: .mount unit + Mount=/Where= directives in systemd. mount(8) command + fstab in filesystem.
- vs debugging: blktrace/lsof/iotop owned by debugging. block-device + lsblk command here.

**P4 failure-mode seeds (deferred):**
1. Disk full — `df -h`, `du -sh`. ext4 reserved-blocks (5% by default) may make `df` show 100% but root can still write.
2. Inode exhaustion — `df -i`. Common with tons of small files (mail spool, container layers).
3. EROFS (read-only filesystem) — auto-remount on errors. `dmesg | grep EXT4-fs error`. Fix: unmount, fsck, remount.
4. NFS hang (D state) — server unreachable; mount with `soft` or `hard,intr` to control behavior.
5. EBUSY on umount — files open. `lsof +D /mnt`, `fuser -m /mnt`. Lazy unmount: `umount -l`.
6. Overlayfs 'permission denied' — userxattr / metacopy / SELinux context mismatch. Common in rootless container setups.
7. mount fails 'unknown filesystem type' — kernel module not loaded. `modprobe`, `lsmod`.
8. LVM thin pool full — VG out of space causes thin LVs to stop accepting writes. `lvs -o +data_percent,metadata_percent`.
9. cryptsetup luksOpen 'No key available' — wrong passphrase or all slots erased. `luksDump` to inspect slots.
10. ext4 'Structure needs cleaning' — filesystem corruption. Mount FAILS. `fsck -y /dev/...` (after taking backup).

**Cross-domain seeds (P5):**
- linux.filesystem.overlayfs ↔ docker.engine.cfg.daemon.json.storage-driver (overlay2)
- linux.filesystem.bind-mount ↔ docker.engine.bind-mount (docker -v / --mount type=bind)
- linux.filesystem.tmpfs ↔ docker --tmpfs / docker-compose tmpfs
- linux.filesystem.cryptsetup-luks ↔ host disk encryption for production docker hosts
- linux.filesystem.lvm ↔ docker storage (devicemapper driver historically used LVM thin pool)
- linux.filesystem.cmd.lsblk ↔ docker storage troubleshooting
- linux.filesystem.proc-control-file ↔ host introspection for any docker debug
- linux.filesystem.cfg.mount-overlayfs.userxattr ↔ rootless container setups
- linux.filesystem.io-uring ↔ modern async runtimes (Node, Rust tokio io_uring driver)

**Source list adjustments:** none. All 38 filesystem docs from Phase 1 used.

**Next:** Linux Phase 3 vertical COMPLETE (5 leaves done). Move to devin domain (Phase 1 → Phase 3 vertical) per the doctrine, OR begin Phase 4 (failure-modes) horizontally across all domains, OR Phase 2 (devbox live capture).

## Cross-references

- Plan file (Phase 3): `~/.claude/plans/read-domains-shared-sessions-phase-3-de-radiant-torvalds.md`
- Sister leaves: primitives 353, networking 355, debugging 252, systemd 427, filesystem 324 = **1711 total**
- Extraction artifacts: `domains/linux/filesystem/extract/{concepts,commands,config_keys}.json`
