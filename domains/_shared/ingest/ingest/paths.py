from pathlib import Path


def find_repo_root(start: Path | None = None) -> Path:
    """Walk upward looking for `pnpm-workspace.yaml` (the unambiguous repo-root marker)."""
    p = (start or Path(__file__)).resolve()
    for parent in (p, *p.parents):
        if (parent / "pnpm-workspace.yaml").is_file():
            return parent
    raise RuntimeError(f"Could not find repo root (no pnpm-workspace.yaml above {p}).")


REPO_ROOT: Path = find_repo_root()
DOMAINS_DIR: Path = REPO_ROOT / "domains"
SHARED_DIR: Path = DOMAINS_DIR / "_shared"
SHARED_SOURCES: Path = SHARED_DIR / "sources.yaml"
SHARED_SCHEMA_SQL: Path = SHARED_DIR / "schema.sql"
SHARED_QUERIES: Path = SHARED_DIR / "queries"
DB_DIR: Path = REPO_ROOT / "_db"
DB_PATH: Path = DB_DIR / "knowledge.duckdb"
RAW_DIR: Path = DB_DIR / "raw"
STAGING_DIR: Path = DB_DIR / "staging"
# Layer 2 — committed columnar history (the one genuinely new durable state; small parquet).
SNAPSHOTS_DIR: Path = SHARED_DIR / "snapshots"


def discover_domains() -> tuple[str, ...]:
    """Every domain folder under domains/ (sorted), excluding `_shared` and dotfiles.

    A domain == a top-level folder, so dropping a new folder under domains/ auto-registers
    it everywhere the schema list is consumed (init-db, meta views, FTS). Folder names are
    used verbatim as DuckDB schema identifiers, so they must be SQL-safe (the CLI's
    `^[a-z0-9][a-z0-9-]*$` rule guarantees this for single-word domains; avoid hyphens in
    domain — not leaf — names).
    """
    if not DOMAINS_DIR.is_dir():
        return ()
    return tuple(
        sorted(
            e.name
            for e in DOMAINS_DIR.iterdir()
            if e.is_dir() and not e.name.startswith((".", "_"))
        )
    )


def domain_schema_extension(domain: str) -> Path | None:
    """Optional per-domain DDL applied on top of the shared base schema.

    Extensibility hook: a domain may declare its own tables (e.g. exercise's `muscles`,
    `exercises`) in `domains/<domain>/schema.<domain>.sql`. The `{{schema}}` placeholder is
    substituted with the domain name, exactly like the base schema. Returns None if absent.
    """
    p = DOMAINS_DIR / domain / f"schema.{domain}.sql"
    return p if p.is_file() else None


# Schemas applied to the DuckDB file (excluding `meta`, which is views-only). Auto-discovered
# from the domain folders so the engine stays extensible — no hardcoded domain list to maintain.
DOMAIN_SCHEMAS: tuple[str, ...] = discover_domains()
