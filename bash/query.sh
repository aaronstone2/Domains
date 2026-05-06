#!/usr/bin/env bash
# query.sh — search the DuckDB corpus from the command line
#
# Fast CLI lookup for commands, failure modes, scripts, and concepts.
# No MCP needed — queries DuckDB directly via python3.
#
# Usage:   query.sh <mode> <search-term>
# Modes:   commands   — search commands by keyword
#          failures   — search failure modes by symptom
#          scripts    — search debug/fix scripts by name or purpose
#          concepts   — search concepts by name or description
#          all        — search everything
# Example: query.sh commands "compose proxy"
#          query.sh failures "OOM killed"
#          query.sh scripts "tls"
#          query.sh all "dns timeout"

set +e

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
DB="$REPO_ROOT/_db/knowledge.duckdb"

mode="${1:-}"
query="${2:-}"

if [ "$mode" = "-h" ] || [ "$mode" = "--help" ] || [ -z "$mode" ] || [ -z "$query" ]; then
  sed -n '2,17p' "$0" | sed 's/^# *//'
  exit 0
fi

if [ ! -f "$DB" ]; then
  echo "ERROR: DuckDB not found at $DB" >&2
  echo "Run the ingest first: python3 bash/ingest-to-duckdb.py" >&2
  exit 1
fi

python3 - "$DB" "$mode" "$query" << 'PYEOF'
import sys
import duckdb

db_path, mode, query = sys.argv[1], sys.argv[2], sys.argv[3]
con = duckdb.connect(db_path, read_only=True)
escaped = query.replace("'", "''")
words = [w for w in query.lower().split() if len(w) >= 2]
like_clauses = " OR ".join([f"lower({{col}}) LIKE '%{w}%'" for w in words])

CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"

def print_header(title):
    print(f"\n{BOLD}{CYAN}=== {title} ==={RESET}")

def search_commands():
    print_header(f"Commands matching: {query}")
    clause = like_clauses.format(col="command") + " OR " + like_clauses.format(col="purpose")
    rows = con.execute(f"""
        SELECT domain, command, purpose
        FROM meta.all_commands
        WHERE {clause}
        ORDER BY domain, purpose
        LIMIT 30
    """).fetchall()
    if not rows:
        print(f"  {DIM}(no matches){RESET}")
        return
    for domain, cmd, purpose in rows:
        print(f"  {GREEN}[{domain}]{RESET} {cmd}")
        if purpose:
            print(f"         {DIM}{purpose}{RESET}")

def search_failures():
    print_header(f"Failure modes matching: {query}")
    clause = (
        like_clauses.format(col="symptom") + " OR " +
        like_clauses.format(col="id") + " OR " +
        like_clauses.format(col="root_cause_class")
    )
    rows = con.execute(f"""
        SELECT domain, id, symptom, root_cause_class, confidence
        FROM meta.all_failure_modes
        WHERE {clause}
        ORDER BY confidence DESC NULLS LAST
        LIMIT 15
    """).fetchall()
    if not rows:
        print(f"  {DIM}(no matches){RESET}")
        return
    for domain, fid, symptom, rcc, conf in rows:
        conf_str = f" ({conf:.0%})" if conf else ""
        print(f"  {YELLOW}[{domain}]{RESET} {BOLD}{fid}{RESET}{conf_str}")
        print(f"         {symptom}")
        if rcc:
            print(f"         {DIM}Root cause: {rcc}{RESET}")

def search_scripts():
    print_header(f"Scripts matching: {query}")
    clause = (
        like_clauses.format(col="name") + " OR " +
        like_clauses.format(col="description") + " OR " +
        like_clauses.format(col="id")
    )
    rows = con.execute(f"""
        SELECT domain, id, name, description
        FROM meta.all_concepts
        WHERE kind = 'tool' AND ({clause})
        ORDER BY domain, name
        LIMIT 20
    """).fetchall()
    if not rows:
        print(f"  {DIM}(no matches){RESET}")
        return
    for domain, cid, name, desc in rows:
        print(f"  {GREEN}[{domain}]{RESET} {BOLD}{name}{RESET}")
        if desc:
            print(f"         {DIM}{desc[:100]}{RESET}")

def search_concepts():
    print_header(f"Concepts matching: {query}")
    clause = (
        like_clauses.format(col="name") + " OR " +
        like_clauses.format(col="description") + " OR " +
        like_clauses.format(col="id")
    )
    rows = con.execute(f"""
        SELECT domain, id, name, kind, description
        FROM meta.all_concepts
        WHERE {clause}
        ORDER BY domain, kind, name
        LIMIT 20
    """).fetchall()
    if not rows:
        print(f"  {DIM}(no matches){RESET}")
        return
    for domain, cid, name, kind, desc in rows:
        print(f"  {GREEN}[{domain}]{RESET} {BOLD}{name}{RESET} {DIM}({kind}){RESET}")
        if desc:
            print(f"         {DIM}{desc[:100]}{RESET}")

def search_all():
    search_commands()
    search_failures()
    search_scripts()

if mode == "commands":
    search_commands()
elif mode == "failures":
    search_failures()
elif mode == "scripts":
    search_scripts()
elif mode == "concepts":
    search_concepts()
elif mode == "all":
    search_all()
else:
    print(f"Unknown mode: {mode}", file=sys.stderr)
    print("Modes: commands, failures, scripts, concepts, all", file=sys.stderr)
    sys.exit(2)

con.close()
PYEOF
