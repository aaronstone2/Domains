"""Layer 4 — hybrid retrieval + gap detection over the embeddings + FTS indexes.

hybrid_search fuses BM25 (the existing fts_<domain>_documents index) with vector cosine search via
reciprocal-rank fusion. gaps finds near-duplicate objects (dedup) and low-density "whitespace"
objects (semantically isolated — candidate uncovered regions).
"""

import duckdb

from ingest.embed import DIM, embed_query

_RRF_K = 60


def vector_search(
    con: duckdb.DuckDBPyConnection, domain: str, query: str, kind: str = "document", k: int = 10
) -> list[tuple[str, float]]:
    qv = embed_query(query)
    rows = con.execute(
        f"""
        SELECT object_id, array_cosine_similarity(vector, CAST(? AS FLOAT[{DIM}])) AS sim
        FROM {domain}.embeddings WHERE object_kind = ?
        ORDER BY sim DESC LIMIT ?
        """,
        [qv, kind, k],
    ).fetchall()
    return [(r[0], r[1]) for r in rows]


def bm25_search(
    con: duckdb.DuckDBPyConnection, domain: str, query: str, k: int = 10
) -> list[tuple[str, float]]:
    try:
        rows = con.execute(
            f"""
            SELECT source_id, score FROM (
              SELECT source_id, fts_{domain}_documents.match_bm25(source_id, ?) AS score
              FROM {domain}.documents
            ) WHERE score IS NOT NULL ORDER BY score DESC LIMIT ?
            """,
            [query, k],
        ).fetchall()
        return [(r[0], r[1]) for r in rows]
    except duckdb.Error:
        return []  # FTS index not built for this domain


def hybrid_search(
    con: duckdb.DuckDBPyConnection, domain: str, query: str, k: int = 10
) -> list[dict]:
    """Reciprocal-rank fusion of BM25 (documents) and vector (document embeddings)."""
    bm = bm25_search(con, domain, query, k * 2)
    ve = vector_search(con, domain, query, "document", k * 2)
    score: dict[str, float] = {}
    for rank, (oid, _) in enumerate(bm):
        score[oid] = score.get(oid, 0.0) + 1.0 / (_RRF_K + rank)
    for rank, (oid, _) in enumerate(ve):
        score[oid] = score.get(oid, 0.0) + 1.0 / (_RRF_K + rank)
    fused = sorted(score.items(), key=lambda x: -x[1])[:k]
    in_bm = {o for o, _ in bm}
    in_ve = {o for o, _ in ve}
    return [
        {"object_id": o, "rrf": round(s, 4), "in_bm25": o in in_bm, "in_vector": o in in_ve}
        for o, s in fused
    ]


def gaps(
    con: duckdb.DuckDBPyConnection, domain: str, kind: str = "claim", dup_thresh: float = 0.93
) -> dict:
    """Near-duplicate pairs (cosine >= dup_thresh) and isolated objects (max-neighbour cosine low)."""
    dups = con.execute(
        f"""
        WITH e AS (SELECT object_id, vector FROM {domain}.embeddings WHERE object_kind = ?)
        SELECT a.object_id, b.object_id, array_cosine_similarity(a.vector, b.vector) AS sim
        FROM e a JOIN e b ON a.object_id < b.object_id
        WHERE array_cosine_similarity(a.vector, b.vector) >= ?
        ORDER BY sim DESC LIMIT 50
        """,
        [kind, dup_thresh],
    ).fetchall()
    isolated = con.execute(
        f"""
        WITH e AS (SELECT object_id, vector FROM {domain}.embeddings WHERE object_kind = ?)
        SELECT a.object_id, MAX(array_cosine_similarity(a.vector, b.vector)) AS nearest
        FROM e a JOIN e b ON a.object_id <> b.object_id
        GROUP BY a.object_id ORDER BY nearest ASC LIMIT 15
        """,
        [kind],
    ).fetchall()
    return {
        "near_duplicates": [(a, b, round(s, 3)) for a, b, s in dups],
        "most_isolated": [(o, round(n, 3)) for o, n in isolated],
    }
