import argparse
import sys
from pathlib import Path

import yaml

from ingest.extract import extract
from ingest.fetch import fetch
from ingest.load import init_db, open_db, upsert_document, upsert_source
from ingest.models import Source, SourcesFile
from ingest.paths import RAW_DIR, SHARED_SOURCES


def _load_sources(path: Path = SHARED_SOURCES) -> list[Source]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    parsed = SourcesFile.model_validate(raw)
    return parsed.sources


def _filter(
    sources: list[Source],
    domain: str | None,
    subdomain: str | None,
    source_id: str | None,
) -> list[Source]:
    out = sources
    if domain:
        out = [s for s in out if s.domain == domain]
    if subdomain:
        out = [s for s in out if s.subdomain == subdomain]
    if source_id:
        out = [s for s in out if s.id == source_id]
    return out


def _cmd_init_db(_: argparse.Namespace) -> int:
    init_db()
    print("init-db: schemas + tables created in _db/knowledge.duckdb", file=sys.stderr)
    return 0


def _cmd_list(args: argparse.Namespace) -> int:
    sources = _filter(_load_sources(), args.domain, args.subdomain, args.source_id)
    for s in sources:
        sub = s.subdomain or "-"
        print(f"{s.id}\t{s.tier}\t{s.domain}/{sub}\t{s.url}")
    print(f"# {len(sources)} sources", file=sys.stderr)
    return 0


def _cmd_fetch(args: argparse.Namespace) -> int:
    sources = _filter(_load_sources(), args.domain, args.subdomain, args.source_id)
    if not sources:
        print("fetch: no sources matched filter", file=sys.stderr)
        return 1
    con = open_db(read_only=False)
    try:
        for s in sources:
            sub = s.subdomain or "_"
            raw_dir = RAW_DIR / s.domain / sub
            try:
                body, digest, fetched_at = fetch(s, raw_dir)
            except Exception as e:  # noqa: BLE001
                print(f"FETCH-FAIL {s.id}: {e}", file=sys.stderr)
                continue
            s.content_hash = digest
            s.fetched_at = fetched_at
            doc = extract(s, body)
            upsert_source(con, s)
            upsert_document(con, doc, s.domain)
            print(f"OK {s.id}  {len(doc.content_md):>7d} chars  {s.url}")
    finally:
        con.close()
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
    )

    p_list = sub.add_parser("list", help="list sources from sources.yaml")
    for flag, kwargs in common_filters:
        p_list.add_argument(flag, **kwargs)
    p_list.set_defaults(func=_cmd_list)

    p_fetch = sub.add_parser("fetch", help="fetch + extract + load documents")
    for flag, kwargs in common_filters:
        p_fetch.add_argument(flag, **kwargs)
    p_fetch.set_defaults(func=_cmd_fetch)

    args = p.parse_args(argv)
    return int(args.func(args))
