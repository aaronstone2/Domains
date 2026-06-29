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


def _cmd_verify(args: argparse.Namespace) -> int:
    """Recalibrate the gold layer: assign verification standards, compute CIs, flag stale claims."""
    from ingest.verify import recalibrate
    if not args.domain:
        print("verify: --domain is required", file=sys.stderr)
        return 1
    con = open_db(read_only=False)
    try:
        summary = recalibrate(con, args.domain)
        if args.stale_only:
            rows = con.execute(
                f"SELECT id, verdict, last_verified, decay_halflife_days FROM {args.domain}.claims "
                f"WHERE stale ORDER BY last_verified NULLS FIRST"
            ).fetchall()
            for r in rows:
                print(f"STALE {r[0]}  verdict={r[1]}  last_verified={r[2]}  halflife={r[3]}d")
    finally:
        con.close()
    print(f"verify: {summary}", file=sys.stderr)
    return 0


def _cmd_calibrate(args: argparse.Namespace) -> int:
    """Brier-score resolved predictive claims for forecast calibration."""
    from ingest.verify import calibrate
    con = open_db(read_only=False)
    try:
        print(f"calibrate {args.domain}: {calibrate(con, args.domain)}")
    finally:
        con.close()
    return 0


def _cmd_forecast(args: argparse.Namespace) -> int:
    """Register predictive claims as datable forecasts (feeds the Brier calibration loop)."""
    from ingest.verify import register_forecasts
    con = open_db(read_only=False)
    try:
        print(f"forecast {args.domain}: {register_forecasts(con, args.domain, args.horizon)}")
    finally:
        con.close()
    return 0


def _cmd_sensitivity(args: argparse.Namespace) -> int:
    """Tornado sensitivity: which model inputs drive output variance."""
    from ingest.mc import sensitivity
    con = open_db(read_only=False)
    try:
        r = sensitivity(con, args.domain, args.model, args.seed, args.draws)
    finally:
        con.close()
    if "error" in r:
        print(r["error"]); return 1
    print(f"sensitivity [{r['model']} -> {r['metric']}] (n={r['n']}, seed={r['seed']}):")
    for d in r["tornado"]:
        bar = "#" * int(round(d["contribution"] * 40))
        print(f"  {d['param']:<16} rho={d['rho']:+.3f}  {d['contribution']*100:5.1f}%  {bar}")
    return 0


def _cmd_watch(args: argparse.Namespace) -> int:
    """Detect competitor moves since a cutoff that erode the wedge / fire falsifiers => recompute."""
    from ingest.watch import watch
    con = open_db(read_only=True)
    try:
        w = watch(con, args.since)
    finally:
        con.close()
    print(f"watch since {w['since']}: {len(w['erosions'])} wedge-eroding move(s), "
          f"{len(w['new_falsifiers'])} new falsifier(s), {len(w['hit_wedge_features'])} feature(s) hit")
    for e in w["erosions"]:
        print(f"  [{e['date']}] {e['strength'] or '?':<8} {e['detail']}  -> {','.join(e['features'] or [])}")
    for f in w["new_falsifiers"]:
        print(f"  ! FALSIFIER {f['finding']} ({f['severity']}) fired on {f['on_date']}")
    if w["recompute"]:
        print(f"  => recompute {len(w['recompute'])} recommendation(s): {', '.join(r['rec'] for r in w['recompute'])}")
    return 0


def _cmd_decide(args: argparse.Namespace) -> int:
    """0/1 knapsack over recommendations under an effort budget => committed action set."""
    from ingest.decide import decide
    con = open_db(read_only=True)
    try:
        d = decide(con, args.budget)
    finally:
        con.close()
    print(f"decide (budget {d['budget_pts']} pts, spent {d['spent_pts']}, realized priority {d['realized_priority']}):")
    print("  SELECTED:")
    for s in d["selected"]:
        tag = " [experiment]" if s["is_experiment"] else ""
        print(f"    + {s['id']} ({s['kind']}, {s['effort']}, prio {s['priority']}){tag}")
    print("  DEFERRED:")
    for s in d["deferred"]:
        print(f"    - {s['id']} ({s['kind']}, {s['effort']}, prio {s['priority']})")
    return 0


def _cmd_model(args: argparse.Namespace) -> int:
    """Run a Monte-Carlo model (deterministic from committed YAML + seed) into model_runs."""
    from ingest.mc import run
    con = open_db(read_only=False)
    try:
        print(f"model run: {run(con, args.domain, args.model, args.seed, args.draws)}")
    finally:
        con.close()
    return 0


def _cmd_render(args: argparse.Namespace) -> int:
    """Project strategy.render_blocks into the non-divergent artifact family (read-only)."""
    from pathlib import Path

    from ingest.render import render
    con = open_db(read_only=True)
    try:
        written = render(con, Path(args.out) if args.out else None)
    finally:
        con.close()
    for w in written:
        print(f"rendered: {w}")
    return 0


def _cmd_reason(args: argparse.Namespace) -> int:
    """Run inference rules to derive new edges/claims (speculative until verified)."""
    from ingest.reason import reason
    con = open_db(read_only=not args.commit)
    try:
        out = reason(con, args.domain, only=args.rule, dry_run=not args.commit)
    finally:
        con.close()
    mode = "DERIVED" if args.commit else "would derive (dry-run)"
    for rid, n in out.items():
        print(f"{mode}: {rid} -> {n}")
    return 0


def _cmd_embed(args: argparse.Namespace) -> int:
    """Compute local fastembed vectors for a domain's documents/claims/concepts."""
    from ingest.embed import embed_domain
    kinds = tuple(args.kind.split(",")) if args.kind else ("document", "claim", "concept")
    con = open_db(read_only=False)
    try:
        n = embed_domain(con, args.domain, kinds)
    finally:
        con.close()
    print(f"embed {args.domain}: {n} vectors ({','.join(kinds)})", file=sys.stderr)
    print("# next: build the ANN index — duckdb _db/knowledge.duckdb < domains/_shared/queries/vss_index.sql", file=sys.stderr)
    return 0


def _cmd_search(args: argparse.Namespace) -> int:
    """Hybrid BM25 + vector search over a domain's documents."""
    from ingest.search import hybrid_search
    con = open_db(read_only=True)
    try:
        for r in hybrid_search(con, args.domain, args.query, args.k):
            print(f"{r['rrf']:.4f}  bm25={r['in_bm25']:d} vec={r['in_vector']:d}  {r['object_id']}")
    finally:
        con.close()
    return 0


def _cmd_gaps(args: argparse.Namespace) -> int:
    """Near-duplicate + most-isolated objects (dedup + whitespace detection)."""
    from ingest.search import gaps
    con = open_db(read_only=True)
    try:
        g = gaps(con, args.domain, args.kind or "claim")
        print("near-duplicates:")
        for a, b, s in g["near_duplicates"]:
            print(f"  {s}  {a}  ~  {b}")
        print("most-isolated (whitespace candidates):")
        for o, n in g["most_isolated"]:
            print(f"  nearest={n}  {o}")
    finally:
        con.close()
    return 0


def _cmd_snapshot(args: argparse.Namespace) -> int:
    """Write a committed parquet snapshot of the fact tables + archive changed claims."""
    from ingest.temporal import snapshot
    from ingest.paths import DOMAIN_SCHEMAS
    domains = (args.domain,) if args.domain else DOMAIN_SCHEMAS
    con = open_db(read_only=False)
    try:
        print(f"snapshot: {snapshot(con, domains, args.label)}")
    finally:
        con.close()
    return 0


def _cmd_restore(args: argparse.Namespace) -> int:
    """Rebuild the full corpus from a committed parquet snapshot (init-db first)."""
    from ingest.temporal import restore
    from ingest.paths import DOMAIN_SCHEMAS
    domains = (args.domain,) if args.domain else DOMAIN_SCHEMAS
    con = open_db(read_only=False)
    try:
        print(f"restore: {restore(con, domains, args.label)}")
    finally:
        con.close()
    return 0


def _cmd_diff(args: argparse.Namespace) -> int:
    """Diff current fact tables vs a prior snapshot label."""
    from ingest.temporal import diff
    con = open_db(read_only=True)
    try:
        print(f"diff: {diff(con, args.domain, args.since, args.table)}")
    finally:
        con.close()
    return 0


def _cmd_evidence(args: argparse.Namespace) -> int:
    """Seed claim_evidence from claim source ids; audit supported-but-not-primary-backed claims."""
    from ingest.verify import seed_claim_evidence, evidence_audit
    con = open_db(read_only=False)
    try:
        n = seed_claim_evidence(con, args.domain)
        proxy = evidence_audit(con, args.domain)
        if args.audit:
            for cid, verdict, nsup in proxy:
                print(f"PROXY-ONLY {cid}  verdict={verdict}  supporting_evidence={nsup}  (no primary backing)")
    finally:
        con.close()
    print(
        f"evidence {args.domain}: seeded {n} claim_evidence rows; "
        f"{len(proxy)} supported/equivalent claims are PROXY-ONLY (pending experimental validation)",
        file=sys.stderr,
    )
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

    p_verify = sub.add_parser("verify", help="recalibrate claims: standards + Wilson CIs + freshness")
    p_verify.add_argument("--domain", required=True)
    p_verify.add_argument("--stale-only", action="store_true", dest="stale_only")
    p_verify.set_defaults(func=_cmd_verify)

    p_cal = sub.add_parser("calibrate", help="Brier-score resolved predictive claims")
    p_cal.add_argument("--domain", required=True)
    p_cal.set_defaults(func=_cmd_calibrate)

    p_ev = sub.add_parser("evidence", help="seed claim_evidence + audit proxy-only supported claims")
    p_ev.add_argument("--domain", required=True)
    p_ev.add_argument("--audit", action="store_true")
    p_ev.set_defaults(func=_cmd_evidence)

    p_snap = sub.add_parser("snapshot", help="write a committed parquet snapshot of the fact tables")
    p_snap.add_argument("--label", required=True)
    p_snap.add_argument("--domain", default=None, help="one domain (default: all)")
    p_snap.set_defaults(func=_cmd_snapshot)

    p_restore = sub.add_parser("restore", help="rebuild the corpus from a committed parquet snapshot (init-db first)")
    p_restore.add_argument("--label", required=True)
    p_restore.add_argument("--domain", default=None, help="one domain (default: all)")
    p_restore.set_defaults(func=_cmd_restore)

    p_diff = sub.add_parser("diff", help="diff current fact tables vs a prior snapshot label")
    p_diff.add_argument("--domain", required=True)
    p_diff.add_argument("--since", required=True)
    p_diff.add_argument("--table", default="claims")
    p_diff.set_defaults(func=_cmd_diff)

    p_emb = sub.add_parser("embed", help="compute local fastembed vectors (needs the `embed` extra)")
    p_emb.add_argument("--domain", required=True)
    p_emb.add_argument("--kind", default=None, help="comma list: document,claim,concept")
    p_emb.set_defaults(func=_cmd_embed)

    p_search = sub.add_parser("search", help="hybrid BM25 + vector search over documents")
    p_search.add_argument("--domain", required=True)
    p_search.add_argument("query")
    p_search.add_argument("-k", type=int, default=10)
    p_search.set_defaults(func=_cmd_search)

    p_gaps = sub.add_parser("gaps", help="near-duplicate + most-isolated objects (dedup + whitespace)")
    p_gaps.add_argument("--domain", required=True)
    p_gaps.add_argument("--kind", default="claim")
    p_gaps.set_defaults(func=_cmd_gaps)

    p_reason = sub.add_parser("reason", help="run inference rules to derive edges/claims (dry-run unless --commit)")
    p_reason.add_argument("--domain", required=True)
    p_reason.add_argument("--rule", default=None, help="run only this rule id")
    p_reason.add_argument("--commit", action="store_true", help="actually write derived rows")
    p_reason.set_defaults(func=_cmd_reason)

    p_fc = sub.add_parser("forecast", help="register predictive claims as datable forecasts (Brier loop)")
    p_fc.add_argument("--domain", required=True)
    p_fc.add_argument("--horizon", type=int, default=365, help="days until resolves_by")
    p_fc.set_defaults(func=_cmd_forecast)

    p_sens = sub.add_parser("sensitivity", help="tornado: which model inputs drive output variance")
    p_sens.add_argument("--domain", required=True)
    p_sens.add_argument("--model", required=True)
    p_sens.add_argument("--seed", type=int, default=42)
    p_sens.add_argument("--draws", type=int, default=10000)
    p_sens.set_defaults(func=_cmd_sensitivity)

    p_watch = sub.add_parser("watch", help="competitor moves since a cutoff that erode the wedge / fire falsifiers")
    p_watch.add_argument("--since", required=True, help="cutoff date YYYY-MM-DD")
    p_watch.set_defaults(func=_cmd_watch)

    p_decide = sub.add_parser("decide", help="0/1 knapsack over recommendations under an effort budget")
    p_decide.add_argument("--budget", type=int, required=True, help="effort points (s=1 m=2 l=3 xl=5)")
    p_decide.set_defaults(func=_cmd_decide)

    p_render = sub.add_parser("render", help="project strategy.render_blocks into a non-divergent family of .md artifacts")
    p_render.add_argument("--out", default=None, help="output dir (default domains/strategy/render/)")
    p_render.set_defaults(func=_cmd_render)

    p_model = sub.add_parser("model", help="run a Monte-Carlo model from _shared/models/<id>.yaml")
    p_model.add_argument("run", nargs="?", default="run")  # `ingest model run --model ...`
    p_model.add_argument("--domain", required=True)
    p_model.add_argument("--model", required=True)
    p_model.add_argument("--seed", type=int, default=42)
    p_model.add_argument("--draws", type=int, default=10000)
    p_model.set_defaults(func=_cmd_model)

    args = p.parse_args(argv)
    return int(args.func(args))
