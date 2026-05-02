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

# Schemas applied to the DuckDB file (excluding `meta`, which is views-only and
# created by queries/cross_domain.sql).
DOMAIN_SCHEMAS: tuple[str, ...] = ("devin", "docker", "linux", "k8s", "methodology")
