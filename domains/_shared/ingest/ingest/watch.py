"""Layer 8 — watch. The piece that makes the corpus a *self-updating* strategy OS rather than a snapshot.

`ingest watch --since <DATE>` scans the temporal layer for competitor moves observed after a cutoff that
(a) erode a MetroGraph wedge feature, or (b) fire a standing red-team falsifier wired to a compintel
signal — and reports which recommendations / wedge claims those changes invalidate and should be
recomputed. Read-only: it raises alerts, it does not silently mutate the synthesis (a human/rerun
disposes). This closes the loop reason→render: new facts surface as actionable deltas, not silent drift.
"""

import duckdb


def watch(con: duckdb.DuckDBPyConnection, since: str) -> dict:
    # (a) wedge-eroding moves since the cutoff
    erosions = con.execute(
        """
        SELECT ch.id, ch.observed_date, ch.signal_strength, ch.detail, ch.wedge_feature_ids
        FROM compintel.changes ch
        WHERE ch.affects_wedge AND ch.observed_date > CAST(? AS DATE)
        ORDER BY ch.observed_date DESC
        """,
        [since],
    ).fetchall()

    # (b) falsifiers whose wired compintel signal landed after the cutoff (newly firing)
    new_falsifiers = con.execute(
        """
        SELECT rt.id, rt.kind, rt.severity, rt.statement, ch.observed_date, ch.id
        FROM strategy.red_team_findings rt
        JOIN compintel.changes ch ON ch.id = rt.watch_signal_id
        WHERE rt.fired AND ch.observed_date > CAST(? AS DATE)
        ORDER BY ch.observed_date DESC
        """,
        [since],
    ).fetchall()

    # which wedge features got hit, and the recommendations that should recompute
    hit_features = sorted({f for _, _, _, _, fids in erosions for f in (fids or [])})
    affected_recs = con.execute(
        """
        SELECT id, kind, priority_score, statement
        FROM strategy.recommendations
        WHERE kind IN ('positioning', 'build')
        ORDER BY priority_score DESC
        """
    ).fetchall() if erosions else []

    return {
        "since": since,
        "erosions": [
            {"change": e[0], "date": str(e[1]), "strength": e[2], "detail": (e[3] or "")[:80], "features": e[4]}
            for e in erosions
        ],
        "new_falsifiers": [
            {"finding": f[0], "kind": f[1], "severity": f[2], "fired_on": f[5], "on_date": str(f[4])}
            for f in new_falsifiers
        ],
        "hit_wedge_features": hit_features,
        "recompute": [{"rec": r[0], "kind": r[1], "priority": r[2]} for r in affected_recs],
    }
