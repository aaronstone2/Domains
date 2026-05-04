#!/usr/bin/env bash
# Scenario: An app fails with EACCES / EPERM on operations the user thinks
#           it should be allowed (chmod 777 won't help). The catch: AppArmor
#           or SELinux is blocking it at the LSM layer, denying the syscall
#           regardless of file perms. dmesg / audit log shows the denial.
# Symptom:  "Permission denied" on operations whose file perms LOOK fine.
#           strace shows EPERM where you'd expect EACCES.
#           dmesg has "audit: type=1400 ... DENIED ..." entries.
# Suggested: ha "permission denied chmod 777 doesn't help"
# Restore:  no destructive system changes; remove staged file

set -uo pipefail
DIR="/tmp/domains-practice/23-lsm"

start() {
  mkdir -p "$DIR"
  # Generate a doc explaining the LSM denial pattern. We don't actually
  # invoke AppArmor/SELinux denials (depends on the host's profile state and
  # would require sudo). Instead we teach the diagnostic flow.

  cat <<EOF

Scenario:  An app reports "Permission denied" on a file you can read/write
           with cat/echo from the same shell. \`ls -l\` shows the file is
           world-readable. \`chmod 777\` doesn't help. Containers exhibit
           it more often than the host. What's blocking?

           This is the AppArmor / SELinux LSM (Linux Security Module)
           denial pattern. POSIX permissions said yes; the LSM said no.
           The mismatch is HUGE — POSIX checks happen first; LSM checks
           are LATER in the syscall path. An LSM denial returns EACCES /
           EPERM identical to a POSIX denial — but the cause is different
           and the FIX is different.

           This scenario is mostly a DOCS exercise — the diagnostic flow
           is what matters. There's no live broken state to repro because
           AppArmor/SELinux state is host-policy-dependent and would need
           sudo to mutate.

Diagnostic flow (this IS the interview answer):

  pnpm harness ask "permission denied chmod doesn't help LSM"

  # 1. Confirm POSIX perms are fine (rules out the obvious)
  ls -la /path/to/file
  stat /path/to/file
  id   # what uid/gid is your process

  # 2. Watch the actual syscall — strace shows precise errno + syscall
  strace -f -e trace=openat,open,read,write,connect,mmap \\
    -- <command> 2>&1 | grep -E 'EACCES|EPERM|EOPNOTSUPP' | head

  # 3. Check if AppArmor is enforcing (most common on Ubuntu/Debian)
  sudo aa-status 2>/dev/null
  cat /sys/kernel/security/apparmor/profiles 2>/dev/null
  # processes confined: column "processes confined" in aa-status

  # 4. Check if SELinux is enforcing (most common on RHEL/Fedora)
  getenforce 2>/dev/null
  sestatus 2>/dev/null

  # 5. THE smoking gun: audit log shows the denial with full context
  # AppArmor:
  sudo dmesg | grep -i 'apparmor.*denied' | tail -10
  sudo journalctl -k --grep='apparmor.*DENIED' -n 20 --no-pager
  # SELinux:
  sudo ausearch -m AVC -ts recent 2>/dev/null
  sudo journalctl -k --grep='avc:.*denied' -n 20 --no-pager

  # 6. Decode the denial line. Example:
  # "audit: type=1400 audit(...): apparmor=\"DENIED\" operation=\"open\"
  #  profile=\"docker-default\" name=\"/etc/shadow\" pid=12345 comm=\"app\"
  #  requested_mask=\"r\" denied_mask=\"r\""
  # Tells you: WHICH profile, WHICH operation, WHICH path, WHICH access bit.
  # SELinux equivalent: "avc:  denied  { read } for  pid=12345 comm=\"app\"
  #  name=\"shadow\" scontext=... tcontext=... tclass=file"

  # 7. Inspect the profile that's denying
  # AppArmor: cat /etc/apparmor.d/<profile-name>
  # SELinux: ls /etc/selinux/targeted/contexts/ ; semanage fcontext -l | grep <path>

Reveal:    $0 reveal
Restore:   $0 restore (no system changes; just removes \$DIR)
Verify:    $0 verify
EOF
}

restore() {
  rm -rf "$DIR"
  echo "[23] cleaned"
}

verify() {
  if [[ -d "$DIR" ]]; then
    echo "[23] $DIR still present. Run: $0 restore"
    return 1
  else
    echo "[23] clean"
    return 0
  fi
}

reveal() {
  cat <<'EOF'
[23-apparmor-denial] reveal:

  Failure mode id:    linux.fm.lsm-apparmor-denied  +
                      linux.fm.lsm-selinux-denied
                      (POSIX-permission-passed-but-LSM-denied — these LOOK
                       like normal permission errors but require an entirely
                       different fix path)

  Why it happens:     POSIX file perms (rwx for owner/group/other) are
                      the OLDEST access control. Linux Security Modules
                      (LSMs — AppArmor, SELinux, Tomoyo, Smack) layer
                      MAC (Mandatory Access Control) on top. POSIX says
                      "uid 1000 can read this file." LSM says "no app in
                      docker-default profile can read /etc/shadow regardless
                      of POSIX perms." Both checks must pass; the LSM check
                      happens AFTER POSIX check, but a denial at either
                      layer returns the same EACCES/EPERM to userspace —
                      so the symptom is identical.

  Two main LSMs in the wild:
    AppArmor (Ubuntu/Debian default): path-based confinement. Profiles
      live in /etc/apparmor.d/. Each profile names paths + access bits
      that an executable can use. docker-default is the profile applied
      to all docker containers.
    SELinux (RHEL/Fedora/CentOS default): label-based confinement. Every
      file + process has an SELinux label (user:role:type:level). Policy
      is "type X can do Y to type Z." More expressive, harder to read.

  Diagnostic flow:
    1. ls/stat → POSIX perms look fine        → suspect LSM
    2. strace → exact syscall returning EACCES/EPERM
    3. aa-status / getenforce → which LSM is enforcing
    4. dmesg | grep DENIED  /  ausearch -m AVC → the actual denial line
    5. Read profile/policy that owns the denial
    6. Decide: relax profile OR change app to fit profile

  Fix paths (in order of safety):
    (A) Change the APP to fit the profile [PREFERRED]:
        - Use a different path that the profile allows
        - Drop the operation if it's not strictly needed
        - For docker: bind-mount a different host path to the in-container
          path that's allowed
    (B) Loosen the profile ONLY for this case:
        AppArmor:
          edit /etc/apparmor.d/<profile>; add the new path with required
          access bits; sudo apparmor_parser -r /etc/apparmor.d/<profile>
        SELinux:
          sudo semanage fcontext -a -t <type> '/path/to(/.*)?'
          sudo restorecon -Rv /path
          OR write a custom policy module (complex):
          sudo audit2allow -a -M mypolicy
          sudo semodule -i mypolicy.pp
    (C) Container-specific (docker):
        --security-opt apparmor=unconfined           (NEVER for prod)
        --security-opt label=disable                 (SELinux equivalent)
        --security-opt apparmor=my-custom-profile    (right way)
    (D) Disable the LSM entirely [WORST]:
        sudo systemctl disable apparmor               (don't, just don't)
        sudo setenforce 0                              (SELinux permissive)

  How to know your fix worked:
    - Run the failing operation; succeeds (no EACCES/EPERM)
    - dmesg/audit shows no new DENIED for this operation
    - aa-status / sestatus still shows enforcing (you didn't disable it!)

  Trade-off:          LSMs exist for a reason — they enforce least-privilege
                      even against bugs in the app. The temptation to
                      "disable AppArmor" or "setenforce 0" is huge during a
                      P1 incident. Resist. Path B (narrow policy edit) takes
                      30 minutes; path D (disable) is a 10-second fix that
                      removes the security control system-wide.

  Devin/container note: docker-default is permissive enough for most
                         workloads. If a Devin agent task is hitting
                         AppArmor denies, it usually means the task is
                         doing something legitimately unusual (writing to
                         /sys, mounting filesystems, accessing /proc/<pid>
                         of another process). That's worth a conversation
                         with the Devin platform team — don't unilaterally
                         disable confinement.

  Reference: pnpm harness playbook linux.fm.lsm-apparmor-denied
             pnpm harness ask "permission denied LSM"
EOF
}

case "${1:-}" in
  start) start ;;
  restore) restore ;;
  verify) verify ;;
  reveal) reveal ;;
  *) echo "usage: $0 {start|restore|verify|reveal}"; exit 1 ;;
esac
