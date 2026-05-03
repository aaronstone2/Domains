"""One-shot fixer: rewrite affected_concepts and source_ids to canonical IDs, drop dup rows."""
import json
import sys

INFILE = r"C:\Users\adsto\git\domains\domains\linux\extract\failure_modes_p4_expansion.json"

# concept-id replacements (missing -> canonical)
CONCEPT_FIX = {
    "linux.primitives.signal-subsystem": "linux.primitives.signal-disposition",
    "linux.primitives.capability-bounding-set": "linux.primitives.cap-bounding-set",
    "linux.networking.ip-protocol": "linux.networking.ipv4-protocol",
    "linux.networking.netlink-subsystem": "linux.networking.netlink-protocol",
    "linux.primitives.credentials-subsystem": "linux.primitives.cap-effective-set",  # closest
    "linux.filesystem.fstab-config": "linux.filesystem.fstab",
    "linux.filesystem.tmpfs-fs": "linux.filesystem.tmpfs",
    "linux.filesystem.lvm-volume": "linux.filesystem.lvm",
    "linux.filesystem.lvm-thin-pool": "linux.filesystem.lvm",
    "linux.filesystem.cryptsetup-volume": "linux.filesystem.cryptsetup-luks",
    "linux.filesystem.ext4-fs": "linux.filesystem.ext4",
    "linux.filesystem.inotify-feature": "linux.filesystem.inotify",
    "linux.filesystem.fanotify-feature": "linux.filesystem.fanotify",
    "linux.filesystem.xattr-feature": "linux.filesystem.xattr",
    "linux.filesystem.acl-feature": "linux.filesystem.acl",
    "linux.systemd.service-restart-on-failure": "linux.systemd.restart-policy",
    "linux.systemd.coredump-unit": "linux.systemd.coredump-handling",
    "linux.systemd.journald-config": "linux.systemd.journal-rate-limit",
    "linux.systemd.unit-target": "linux.systemd.target-unit",
    "linux.debugging.bpf-helpers": "linux.debugging.bpf-program-types",
    "linux.debugging.kdump-tool": "linux.debugging.kdump",
    "linux.debugging.crash-tool": "linux.debugging.crash-utility",
    "linux.debugging.auditctl-tool": "linux.debugging.audit-rule",
    "linux.debugging.ausearch-tool": "linux.debugging.audit-record-types",
}

# source-id replacements (missing -> canonical)
SOURCE_FIX = {
    "systemd-resolved-conf-5": "man7-resolv-conf-5",
    "linux.filesystem.proc-pid-fd": "man7-lsof-8",   # was wrongly using concept id
    "linux.debugging.process-d-state": "man7-htop-1",
    "linux.debugging.proc-pid-stack": "man7-htop-1",
}

# IDs that already exist in DB (dup'd) — drop these new rows
DROP_IDS = {
    "linux.fm.tcp-listen-overflow",
    "linux.fm.conntrack-table-full",
    "linux.fm.dns-slow-ndots",
    "linux.fm.disk-full-but-df-shows-free-space",
    "linux.fm.systemd-coredump-not-saved",
    "linux.fm.journald-rate-limited",
    "linux.fm.process-stuck-d-state",
}

with open(INFILE, "r", encoding="utf-8") as f:
    rows = json.load(f)

kept = []
for row in rows:
    if row["id"] in DROP_IDS:
        continue
    row["affected_concepts"] = [CONCEPT_FIX.get(c, c) for c in row.get("affected_concepts", []) or []]
    # also fix in diagnostic_steps and fix_steps source_id fields
    for step in row.get("diagnostic_steps", []) or []:
        sid = step.get("source_id")
        if sid in SOURCE_FIX:
            step["source_id"] = SOURCE_FIX[sid]
        if sid in CONCEPT_FIX:
            # someone used a concept id where a source goes — best-effort
            step["source_id"] = SOURCE_FIX.get(sid, "man7-lsof-8")
    for step in row.get("fix_steps", []) or []:
        sid = step.get("source_id")
        if sid in SOURCE_FIX:
            step["source_id"] = SOURCE_FIX[sid]
    row["source_ids"] = [SOURCE_FIX.get(s, s) for s in row.get("source_ids", []) or []]
    kept.append(row)

with open(INFILE, "w", encoding="utf-8") as f:
    json.dump(kept, f, separators=(",", ":"))
    f.write("\n")

print(f"kept {len(kept)} rows (dropped {len(rows) - len(kept)})")
