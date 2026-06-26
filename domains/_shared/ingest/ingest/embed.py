"""Layer 4 — local semantic embeddings (fastembed, ONNX/CPU, no API key).

Embeds documents / claims / concepts into <domain>.embeddings as fixed-width FLOAT[384] vectors so
DuckDB's vss HNSW index can do ANN search. One model per index (BAAI/bge-small-en-v1.5, 384-dim).
Vectors are 100% derived from committed content — gitignore the DB, regenerate with `ingest embed`.
"""

import duckdb

MODEL = "BAAI/bge-small-en-v1.5"
DIM = 384
_model = None


def _get_model():
    global _model
    if _model is None:
        from fastembed import TextEmbedding  # lazy: only when embedding

        _model = TextEmbedding(MODEL)
    return _model


def _items(con: duckdb.DuckDBPyConnection, domain: str, kind: str) -> list[tuple[str, str]]:
    """(object_id, text) pairs to embed for a given object kind."""
    if kind == "document":
        rows = con.execute(
            f"SELECT source_id, string_agg(content_md, ' ') FROM {domain}.documents GROUP BY 1"
        ).fetchall()
        return [(r[0], (r[1] or "")[:2000]) for r in rows if (r[1] or "").strip()]
    if kind == "claim":
        rows = con.execute(f"SELECT id, statement FROM {domain}.claims").fetchall()
        return [(r[0], r[1] or "") for r in rows if (r[1] or "").strip()]
    if kind == "concept":
        rows = con.execute(
            f"SELECT id, COALESCE(name,'') || '. ' || COALESCE(description,'') FROM {domain}.concepts"
        ).fetchall()
        return [(r[0], r[1]) for r in rows if (r[1] or "").strip()]
    return []


def embed_domain(
    con: duckdb.DuckDBPyConnection, domain: str, kinds: tuple[str, ...] = ("document", "claim", "concept")
) -> int:
    """Compute + upsert embeddings for the requested object kinds. Returns rows embedded."""
    model = _get_model()
    total = 0
    for kind in kinds:
        items = _items(con, domain, kind)
        if not items:
            continue
        texts = [t for _, t in items]
        vecs = list(model.embed(texts))
        for (oid, _), vec in zip(items, vecs):
            eid = f"{domain}.emb.{kind}.{oid}"
            v = [float(x) for x in vec]
            con.execute(
                f"INSERT INTO {domain}.embeddings (id, object_kind, object_id, model, dim, vector, content_hash) "
                f"VALUES (?, ?, ?, ?, ?, CAST(? AS FLOAT[{DIM}]), NULL) "
                f"ON CONFLICT (id) DO UPDATE SET vector = excluded.vector, model = excluded.model, dim = excluded.dim",
                [eid, kind, oid, MODEL, DIM, v],
            )
            total += 1
    return total


def embed_query(text: str) -> list[float]:
    """Embed a single query string to a FLOAT[384] list for vector search."""
    vec = list(_get_model().embed([text]))[0]
    return [float(x) for x in vec]
