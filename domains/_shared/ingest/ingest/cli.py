import argparse
import sys
from pathlib import Path

import yaml

from ingest.extract import extract
from ingest.fetch import fetch
from ingest.load import (
    clear_staging,
    init_db,
    load_extract,
    load_staged,
    open_db,
    stage_document,
    stage_source,
)
from ingest.models import Source, SourcesFile
from ingest.paths import RAW_DIR, SHARED_SOURCES, STAGING_DIR


def _load_sources(path: Path = SHARED_SOURCES) -> list[Source]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    parsed = SourcesFile.model_validate(raw)
    return parsed.sources


_TIER_RANK = {"T0": 0, "T1": 1, "T2": 2, "T3": 3}


def _filter(
    sources: list[Source],
    domain: str | None,
    subdomain: str | None,
    source_id: str | None,
    max_tier: str | None = None,
) -> list[Source]:
    out = sources
    if domain:
        out = [s for s in out if s.domain == domain]
    if subdomain:
        out = [s for s in out if s.subdomain == subdomain]
    if source_id:
        out = [s for s in out if s.id == source_id]
    if max_tier:
        lim = _TIER_RANK[max_tier]
        out = [s for s in out if _TIER_RANK.get(s.tier, 99) <= lim]
    return out


def _cmd_init_db(_: argparse.Namespace) -> int:
    init_db()
    print("init-db: schemas + tables created in _db/knowledge.duckdb", file=sys.stderr)
    return 0


def _cmd_list(args: argparse.Namespace) -> int:
    sources = _filter(_load_sources(), args.domain, args.subdomain, args.source_id, args.max_tier)
    for s in sources:
        sub = s.subdomain or "-"
        print(f"{s.id}\t{s.tier}\t{s.domain}/{sub}\t{s.url}")
    print(f"# {len(sources)} sources", file=sys.stderr)
    return 0


def _cmd_fetch(args: argparse.Namespace) -> int:
    """Fetch + extract + stage to JSONL. Does NOT touch the DB (no lock conflict with motherduck MCP).

    After fetch, run `ingest load --domain <d>` (acquires DB lock) OR load via the motherduck MCP
    using `INSERT OR REPLACE INTO <d>.<t> BY NAME SELECT * FROM read_json('_db/staging/<d>.<t>.jsonl', format='newline_delimited')`.
    """
    sources = _filter(_load_sources(), args.domain, args.subdomain, args.source_id, args.max_tier)
    if not sources:
        print("fetch: no sources matched filter", file=sys.stderr)
        return 1

    # Clear staging once per domain on a full-domain or full pass.
    # Single-source flows (--source-id) append, so prior staging survives.
    if not args.source_id:
        for d in sorted({s.domain for s in sources}):
            clear_staging(d)

    ok, fail = 0, 0
    for s in sources:
        sub = s.subdomain or "_"
        raw_dir = RAW_DIR / s.domain / sub
        try:
            body, digest, fetched_at = fetch(s, raw_dir)
        except Exception as e:  # noqa: BLE001
            print(f"FETCH-FAIL {s.id}: {e}", file=sys.stderr)
            fail += 1
            continue
        s.content_hash = digest
        s.fetched_at = fetched_at
        doc = extract(s, body)
        stage_source(s)
        stage_document(doc, s.domain)
        print(f"OK {s.id}  {len(doc.content_md):>7d} chars  {s.url}")
        ok += 1

    print(
        f"# staged {ok} sources ({fail} failed) to {STAGING_DIR}\n"
        f"# next: `uv run python -m ingest load --domain <d>` "
        f"OR load via motherduck MCP using read_json on the .jsonl files",
        file=sys.stderr,
    )
    return 0 if fail == 0 else 2


def _cmd_load(args: argparse.Namespace) -> int:
    """Load staged JSONL into the DB. Requires the DB write lock — close motherduck MCP first."""
    if not args.domain:
        print("load: --domain is required", file=sys.stderr)
        return 1
    con = open_db(read_only=False)
    try:
        s_n, d_n = load_staged(con, args.domain)
        print(f"loaded {s_n} sources, {d_n} documents into {args.domain}.*")
    finally:
        con.close()
    return 0


def _cmd_load_extract(args: argparse.Namespace) -> int:
    """Load committed extension-table rows from domains/<domain>/[<leaf>/]extract/*.json into the DB."""
    if not args.domain:
        print("load-extract: --domain is required", file=sys.stderr)
        return 1
    con = open_db(read_only=False)
    try:
        counts = load_extract(con, args.domain, args.leaf)
    finally:
        con.close()
    total = sum(n for n in counts.values() if n >= 0)
    for table, n in sorted(counts.items()):
        print(f"  {table}: {n}")
    print(f"load-extract: {total} rows across {len(counts)} tables into {args.domain}.*", file=sys.stderr)
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ingest")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init-db", help="create schemas + tables in _db/knowledge.duckdb")
    p_init.set_defaults(func=_cmd_init_db)

    common_filters = (
        ("--domain", {"default": None}),
        ("--subdomain", {"default": None}),
        ("--source-id", {"default": None, "dest": "source_id"}),
        ("--max-tier", {"default": None, "dest": "max_tier", "choices": ["T0", "T1", "T2", "T3"]}),
    )

    p_list = sub.add_parser("list", help="list sources from sources.yaml")
    for flag, kwargs in common_filters:
        p_list.add_argument(flag, **kwargs)
    p_list.set_defaults(func=_cmd_list)

    p_fetch = sub.add_parser(
        "fetch",
        help="fetch + extract + stage to JSONL (no DB write; safe alongside motherduck MCP)",
    )
    for flag, kwargs in common_filters:
        p_fetch.add_argument(flag, **kwargs)
    p_fetch.set_defaults(func=_cmd_fetch)

    p_load = sub.add_parser(
        "load",
        help="load staged JSONL into DB (acquires write lock; close motherduck MCP first)",
    )
    p_load.add_argument("--domain", required=True)
    p_load.set_defaults(func=_cmd_load)

    p_lx = sub.add_parser(
        "load-extract",
        help="upsert extension-table rows from domains/<domain>/[<leaf>/]extract/*.json",
    )
    p_lx.add_argument("--domain", required=True)
    p_lx.add_argument("--leaf", default=None)
    p_lx.set_defaults(func=_cmd_load_extract)

    args = p.parse_args(argv)
    return int(args.func(args))
