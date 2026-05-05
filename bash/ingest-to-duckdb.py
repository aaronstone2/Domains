#!/usr/bin/env python3
"""Ingest bash debug/fix scripts + cmd_history.txt into the DuckDB corpus.

Adds:
- Sources: one per script (bash-debug-* and bash-fix-*)
- Commands: parsed from cmd_history.txt per category section
- Concepts: one per debug/fix script (links symptom to tool)
- Relationships: script → failure_mode, script → commands

Run from repo root:
    python3 bash/ingest-to-duckdb.py

Idempotent — uses INSERT OR REPLACE.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import duckdb
except ImportError:
    print("pip install duckdb", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / "_db" / "knowledge.duckdb"
BASH_DIR = REPO_ROOT / "bash"
CMD_HISTORY = REPO_ROOT / "cmd_history.txt"

# ---------------------------------------------------------------------------
# Script metadata — maps each script to its domain + related failure modes
# ---------------------------------------------------------------------------

DEBUG_SCRIPTS = {
    "oom.sh":       {"domain": "docker", "category": "memory",    "fms": ["docker.fm.exit-137-oomkilled"]},
    "dns.sh":       {"domain": "linux",  "category": "network",   "fms": ["docker.fm.dns-resolv-broken-in-container"]},
    "tls.sh":       {"domain": "linux",  "category": "tls",       "fms": ["devin.fm.build-failed-blueprint-error"]},
    "network.sh":   {"domain": "docker", "category": "network",   "fms": ["docker.fm.no-egress-network-broken"]},
    "procs.sh":     {"domain": "linux",  "category": "process",   "fms": ["linux.fm.zombie-processes"]},
    "leak.sh":      {"domain": "linux",  "category": "memory",    "fms": ["linux.fm.fd-exhaustion-emfile"]},
    "cgroup.sh":    {"domain": "linux",  "category": "cgroup",    "fms": ["docker.fm.cgroup-cpu-throttled"]},
    "throttle.sh":  {"domain": "linux",  "category": "cpu",       "fms": ["docker.fm.cgroup-cpu-throttled"]},
    "disk.sh":      {"domain": "linux",  "category": "disk",      "fms": []},
    "secrets.sh":   {"domain": "devin",  "category": "devin",     "fms": ["devin.fm.repo-scoped-secret-not-auto-injected"]},
    "ulimits.sh":   {"domain": "linux",  "category": "process",   "fms": ["linux.fm.fd-exhaustion-emfile"]},
    "restart.sh":   {"domain": "docker", "category": "container", "fms": []},
    "gateway.sh":   {"domain": "docker", "category": "multi",     "fms": []},
    "compose.sh":   {"domain": "docker", "category": "compose",   "fms": []},
    "proxy.sh":     {"domain": "linux",  "category": "proxy",     "fms": []},
    "volumes.sh":   {"domain": "docker", "category": "volume",    "fms": []},
    "build.sh":     {"domain": "docker", "category": "build",     "fms": []},
    "logs.sh":      {"domain": "docker", "category": "logging",   "fms": []},
    "blueprint.sh": {"domain": "devin",  "category": "blueprint", "fms": ["devin.fm.build-failed-blueprint-error"]},
}

FIX_SCRIPTS = {
    "env.sh":              {"domain": "devin",  "category": "env",       "fms": ["devin.fm.repo-scoped-secret-not-auto-injected"]},
    "hosts.sh":            {"domain": "linux",  "category": "dns",       "fms": []},
    "hosts-rm.sh":         {"domain": "linux",  "category": "dns",       "fms": []},
    "dns.sh":              {"domain": "linux",  "category": "dns",       "fms": ["docker.fm.dns-resolv-broken-in-container"]},
    "cabundle.sh":         {"domain": "linux",  "category": "tls",       "fms": []},
    "cert-renew.sh":       {"domain": "linux",  "category": "tls",       "fms": []},
    "reload.sh":           {"domain": "linux",  "category": "process",   "fms": []},
    "restart-process.sh":  {"domain": "linux",  "category": "process",   "fms": []},
    "restart-container.sh":{"domain": "docker", "category": "container", "fms": ["docker.fm.exit-137-oomkilled"]},
    "recreate-init.sh":    {"domain": "docker", "category": "container", "fms": ["linux.fm.zombie-processes"]},
    "install-tools.sh":    {"domain": "docker", "category": "tools",     "fms": []},
    "prune.sh":            {"domain": "docker", "category": "disk",      "fms": []},
    "compose.sh":          {"domain": "docker", "category": "compose",   "fms": []},
    "proxy.sh":            {"domain": "linux",  "category": "proxy",     "fms": []},
    "volume-perms.sh":     {"domain": "docker", "category": "volume",    "fms": []},
    "log-rotate.sh":       {"domain": "docker", "category": "logging",   "fms": []},
    "blueprint.sh":        {"domain": "devin",  "category": "blueprint", "fms": ["devin.fm.build-failed-blueprint-error"]},
}

# ---------------------------------------------------------------------------
# Parse cmd_history.txt into categorized command blocks
# ---------------------------------------------------------------------------

def parse_cmd_history(path: Path) -> list[dict]:
    """Parse cmd_history.txt into structured command entries."""
    entries = []
    current_section = "misc"
    current_subsection = ""

    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")

            # Section headers
            m = re.match(r'^# =+ (.*?) =+$', line)
            if m:
                current_section = m.group(1).strip()
                current_subsection = ""
                continue

            # Subsection headers
            m = re.match(r'^# --- (.*?) ---$', line)
            if m:
                current_subsection = m.group(1).strip()
                continue

            # Skip pure comments and blank lines
            if line.startswith("#") or not line.strip():
                continue

            # This is a command
            cmd = line.strip()
            if cmd:
                # Determine domain from section name
                section_lower = current_section.lower()
                if "docker" in section_lower or "compose" in section_lower or "volume" in section_lower or "log rot" in section_lower or "build" in section_lower:
                    domain = "docker"
                elif "devin" in section_lower or "blueprint" in section_lower or "environment" in section_lower:
                    domain = "devin"
                elif "proxy" in section_lower or "dns" in section_lower or "tls" in section_lower:
                    domain = "linux"
                elif "harness" in section_lower or "mcp" in section_lower:
                    domain = "methodology"
                elif "k8s" in section_lower or "kubectl" in section_lower:
                    domain = "k8s"
                else:
                    domain = "linux"  # default

                cmd_id = f"bash.cmd.{domain}.{re.sub(r'[^a-z0-9]+', '-', cmd[:60].lower()).strip('-')}"

                entries.append({
                    "id": cmd_id,
                    "command": cmd,
                    "purpose": f"{current_section} / {current_subsection}" if current_subsection else current_section,
                    "domain": domain,
                    "section": current_section,
                    "subsection": current_subsection,
                })

    return entries


# ---------------------------------------------------------------------------
# Parse a script file for its doc comment (purpose/usage)
# ---------------------------------------------------------------------------

def parse_script_meta(path: Path) -> dict:
    """Extract purpose, usage, example from script doc comment."""
    meta = {"purpose": "", "usage": "", "examples": [], "hints": []}
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.startswith("#"):
                break
            line = line.lstrip("# ").rstrip()
            if line.startswith("Usage:"):
                meta["usage"] = line[6:].strip()
            elif line.startswith("Example:"):
                meta["examples"].append(line[8:].strip())
            elif "—" in line and not meta["purpose"]:
                meta["purpose"] = line.split("—", 1)[1].strip()
    return meta


# ---------------------------------------------------------------------------
# Main ingest
# ---------------------------------------------------------------------------

def main():
    if not DB_PATH.exists():
        print(f"ERROR: DB not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    con = duckdb.connect(str(DB_PATH))
    now = datetime.now(timezone.utc).isoformat()
    counts = {"sources": 0, "commands": 0, "concepts": 0, "relationships": 0}

    # 1. Ingest debug scripts as sources + concepts
    print("=== Ingesting debug scripts ===")
    for script_name, meta in DEBUG_SCRIPTS.items():
        path = BASH_DIR / "debug" / script_name
        if not path.exists():
            print(f"  SKIP (not found): {path}")
            continue

        domain = meta["domain"]
        src_id = f"bash-debug-{script_name.replace('.sh', '')}"
        script_meta = parse_script_meta(path)

        # Source — delete + insert (idempotent)
        con.execute(f"DELETE FROM {domain}.sources WHERE id = ?", [src_id])
        con.execute(f"""
            INSERT INTO {domain}.sources
            (id, url, title, subdomain, tier, license_note, fetched_at, parser, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            src_id,
            f"file://bash/debug/{script_name}",
            f"Debug script: {script_name} — {script_meta['purpose']}",
            meta["category"],
            "T0",
            "redistribute-ok",
            now,
            "bash-script",
            f"Usage: {script_meta['usage']}",
        ])
        counts["sources"] += 1

        # Concept — delete + insert
        concept_id = f"{domain}.tool.debug-{script_name.replace('.sh', '')}"
        con.execute(f"DELETE FROM {domain}.concepts WHERE id = ?", [concept_id])
        con.execute(f"""
            INSERT INTO {domain}.concepts
            (id, name, kind, description, source_ids, aliases)
            VALUES (?, ?, ?, ?, ?, ?)
        """, [
            concept_id,
            f"debug/{script_name}",
            "tool",
            f"Read-only diagnostic script: {script_meta['purpose']}. {script_meta['usage']}",
            [src_id],
            [f"bash/debug/{script_name}", f"dbg-{script_name.replace('.sh', '')}"],
        ])
        counts["concepts"] += 1

        # Relationships to failure modes
        for fm_id in meta["fms"]:
            fm_domain = fm_id.split(".")[0]
            con.execute(f"""
                DELETE FROM {domain}.relationships
                WHERE from_id = ? AND to_id = ? AND rel_type = ?
            """, [concept_id, fm_id, "diagnoses"])
            con.execute(f"""
                INSERT INTO {domain}.relationships
                (from_id, to_id, rel_type, source_id)
                VALUES (?, ?, ?, ?)
            """, [concept_id, fm_id, "diagnoses", src_id])
            counts["relationships"] += 1

        print(f"  ✓ {domain}.{src_id}")

    # 2. Ingest fix scripts as sources + concepts
    print("\n=== Ingesting fix scripts ===")
    for script_name, meta in FIX_SCRIPTS.items():
        path = BASH_DIR / "fix" / script_name
        if not path.exists():
            print(f"  SKIP (not found): {path}")
            continue

        domain = meta["domain"]
        src_id = f"bash-fix-{script_name.replace('.sh', '')}"
        script_meta = parse_script_meta(path)

        # Source — delete + insert (idempotent)
        con.execute(f"DELETE FROM {domain}.sources WHERE id = ?", [src_id])
        con.execute(f"""
            INSERT INTO {domain}.sources
            (id, url, title, subdomain, tier, license_note, fetched_at, parser, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            src_id,
            f"file://bash/fix/{script_name}",
            f"Fix script: {script_name} — {script_meta['purpose']}",
            meta["category"],
            "T0",
            "redistribute-ok",
            now,
            "bash-script",
            f"Usage: {script_meta['usage']}. Dry-run by default, --apply to execute.",
        ])
        counts["sources"] += 1

        # Concept — delete + insert
        concept_id = f"{domain}.tool.fix-{script_name.replace('.sh', '')}"
        con.execute(f"DELETE FROM {domain}.concepts WHERE id = ?", [concept_id])
        con.execute(f"""
            INSERT INTO {domain}.concepts
            (id, name, kind, description, source_ids, aliases)
            VALUES (?, ?, ?, ?, ?, ?)
        """, [
            concept_id,
            f"fix/{script_name}",
            "tool",
            f"Remediation script (dry-run default, --apply to execute): {script_meta['purpose']}. {script_meta['usage']}",
            [src_id],
            [f"bash/fix/{script_name}", f"fix-{script_name.replace('.sh', '')}"],
        ])
        counts["concepts"] += 1

        # Relationships to failure modes
        for fm_id in meta["fms"]:
            con.execute(f"""
                DELETE FROM {domain}.relationships
                WHERE from_id = ? AND to_id = ? AND rel_type = ?
            """, [concept_id, fm_id, "remediates"])
            con.execute(f"""
                INSERT INTO {domain}.relationships
                (from_id, to_id, rel_type, source_id)
                VALUES (?, ?, ?, ?)
            """, [concept_id, fm_id, "remediates", src_id])
            counts["relationships"] += 1

        print(f"  ✓ {domain}.{src_id}")

    # 3. Ingest cmd_history.txt commands
    print("\n=== Ingesting cmd_history.txt ===")
    cmds = parse_cmd_history(CMD_HISTORY)
    seen_ids = set()
    for entry in cmds:
        # Deduplicate by ID
        cid = entry["id"]
        suffix = 1
        while cid in seen_ids:
            cid = f"{entry['id']}-{suffix}"
            suffix += 1
        seen_ids.add(cid)

        domain = entry["domain"]
        try:
            con.execute(f"DELETE FROM {domain}.commands WHERE id = ?", [cid])
            con.execute(f"""
                INSERT INTO {domain}.commands
                (id, command, purpose, flags, examples, source_ids)
                VALUES (?, ?, ?, ?, ?, ?)
            """, [
                cid,
                entry["command"],
                entry["purpose"],
                None,  # flags
                None,  # examples
                ["bash-cmd-history"],
            ])
            counts["commands"] += 1
        except Exception as e:
            # Skip commands that fail (e.g., domain schema doesn't exist)
            pass

    # 4. Add cmd_history.txt as a source in each domain
    for domain in ["docker", "linux", "devin", "methodology", "k8s"]:
        try:
            con.execute(f"DELETE FROM {domain}.sources WHERE id = ?", ["bash-cmd-history"])
            con.execute(f"""
                INSERT INTO {domain}.sources
                (id, url, title, subdomain, tier, license_note, fetched_at, parser, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [
                "bash-cmd-history",
                "file://cmd_history.txt",
                "cmd_history.txt — curated atuin-seeded commands for interview Ctrl+R",
                "tools",
                "T0",
                "redistribute-ok",
                now,
                "custom",
                f"{len(cmds)} commands across all categories",
            ])
        except:
            pass

    # 5. Rebuild FTS indexes for the domains we touched
    print("\n=== Rebuilding FTS indexes ===")
    for domain in ["docker", "linux", "devin"]:
        try:
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.docs")
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.terms")
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.dict")
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.fields")
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.stats")
            con.execute(f"DROP TABLE IF EXISTS fts_{domain}_documents.stopwords")
            con.execute(f"DROP SCHEMA IF EXISTS fts_{domain}_documents CASCADE")
        except:
            pass
        try:
            con.execute(f"""
                INSTALL fts; LOAD fts;
                PRAGMA create_fts_index('{domain}.documents', 'source_id', 'content_md', 'section_path',
                    stemmer='english', stopwords='english', lower=1, strip_accents=1, overwrite=1)
            """)
            print(f"  ✓ FTS index rebuilt for {domain}")
        except Exception as e:
            print(f"  ✗ FTS rebuild failed for {domain}: {e}")

    con.close()

    print(f"\n=== Done ===")
    print(f"  Sources:       {counts['sources']}")
    print(f"  Commands:      {counts['commands']}")
    print(f"  Concepts:      {counts['concepts']}")
    print(f"  Relationships: {counts['relationships']}")


if __name__ == "__main__":
    main()
