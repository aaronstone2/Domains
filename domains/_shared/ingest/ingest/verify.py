"""Layer 6 — verification recalibration.

The adversarial skeptic *panels* still run as workflows (LLM agents prompted to refute a claim
against the ingested corpus). This module owns the *mechanical, deterministic* recalibration that
runs over the result: assign a per-claim verification standard, compute a confidence interval
(not just a point agreement_score), and a freshness/decay flag. All set-based SQL, idempotent.

Verification standards (encoded here and in domains/_shared/sessions/depth-profiles.md):
  descriptive  — a fact (a price, a funding amount, a measured number): verified by >=2-source cross-check.
  evaluative   — an interpretive/strategic judgement: verified by a diverse-lens skeptic panel.
  predictive   — a claim about the future: logged to forecast_log and scored (Brier) when it resolves.
"""

import duckdb

# z for a 95% Wilson interval
_Z2 = 3.8416  # 1.96^2


def assign_standards(con: duckdb.DuckDBPyConnection, domain: str) -> int:
    """Set claims.verification_standard from claim_type / statement shape (only where NULL)."""
    con.execute(
        f"""
        UPDATE {domain}.claims SET verification_standard = CASE
          WHEN claim_type IN ('predictive') THEN 'predictive'
          WHEN claim_type IN ('strategic','theoretical','evaluative') THEN 'evaluative'
          WHEN claim_type IN ('empirical','quantitative','descriptive') THEN 'descriptive'
          WHEN regexp_matches(lower(statement), '(\\bwill\\b|by 20[0-9]{{2}}|expected to|projected|forecast)') THEN 'predictive'
          ELSE 'evaluative' END
        WHERE verification_standard IS NULL
        """
    )
    return con.execute(
        f"SELECT count(*) FROM {domain}.claims WHERE verification_standard IS NOT NULL"
    ).fetchone()[0]


def recompute_freshness(con: duckdb.DuckDBPyConnection, domain: str) -> int:
    """Set a default decay half-life per claim (where NULL) and recompute the `stale` flag.

    stale = no last_verified OR aged past its half-life. (A source-content-change trigger needs a
    stored verified-at hash; tracked as a follow-up — age-based decay is live now.)
    """
    con.execute(
        f"""
        UPDATE {domain}.claims SET decay_halflife_days = COALESCE(decay_halflife_days, CASE
          WHEN verification_standard = 'predictive' THEN 180
          WHEN evidence_grade IN ('vendor-claim','review-mining','anecdote','g2-aggregate') THEN 270
          WHEN verification_standard = 'descriptive' THEN 365
          ELSE 540 END)
        """
    )
    con.execute(
        f"""
        UPDATE {domain}.claims
        SET stale = (last_verified IS NULL OR (CURRENT_DATE - last_verified) > decay_halflife_days)
        """
    )
    return con.execute(f"SELECT count(*) FROM {domain}.claims WHERE stale").fetchone()[0]


def recompute_ci(con: duckdb.DuckDBPyConnection, domain: str) -> None:
    """Compute a Wilson 95% interval [confidence_low, confidence_high] for each claim.

    p = agreement_score (fallback confidence, fallback 0.5); n = #supporting + #contradicting
    sources (min 1) — so a claim backed by one blog gets a wide interval, one backed by ten
    cross-checked sources a tight one. This is the honest replacement for a bare point score.
    """
    con.execute(
        f"""
        WITH b AS (
          SELECT id,
            COALESCE(agreement_score, confidence, 0.5) AS p,
            GREATEST(1, COALESCE(len(supporting_source_ids),0) + COALESCE(len(contradicting_source_ids),0)) AS n
          FROM {domain}.claims
        )
        UPDATE {domain}.claims c SET
          confidence_low  = GREATEST(0.0, ((b.p + {_Z2}/(2*b.n)) - 1.96*sqrt((b.p*(1-b.p) + {_Z2}/(4*b.n))/b.n)) / (1 + {_Z2}/b.n)),
          confidence_high = LEAST(1.0,  ((b.p + {_Z2}/(2*b.n)) + 1.96*sqrt((b.p*(1-b.p) + {_Z2}/(4*b.n))/b.n)) / (1 + {_Z2}/b.n))
        FROM b WHERE c.id = b.id
        """
    )


def recalibrate(con: duckdb.DuckDBPyConnection, domain: str) -> dict[str, int]:
    """Run the full mechanical recalibration. Returns a small summary."""
    assigned = assign_standards(con, domain)
    recompute_ci(con, domain)
    stale = recompute_freshness(con, domain)
    by_std = dict(
        con.execute(
            f"SELECT verification_standard, count(*) FROM {domain}.claims GROUP BY 1"
        ).fetchall()
    )
    return {"standards_assigned": assigned, "stale": stale, **{f"std:{k}": v for k, v in by_std.items()}}


def calibrate(con: duckdb.DuckDBPyConnection, domain: str) -> dict[str, float]:
    """Score resolved predictive claims (Brier) and report mean calibration."""
    con.execute(
        f"UPDATE {domain}.forecast_log SET brier = power(predicted_prob - outcome, 2) "
        f"WHERE resolved AND outcome IS NOT NULL"
    )
    row = con.execute(
        f"SELECT count(*), avg(brier) FROM {domain}.forecast_log WHERE resolved AND brier IS NOT NULL"
    ).fetchone()
    return {"resolved_forecasts": row[0] or 0, "mean_brier": row[1] if row[1] is not None else float("nan")}
