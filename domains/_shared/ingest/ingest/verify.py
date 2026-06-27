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


def seed_claim_evidence(con: duckdb.DuckDBPyConnection, domain: str) -> int:
    """Backfill claim_evidence from each claim's supporting/contradicting_source_ids.

    Idempotent (deterministic row ids + ON CONFLICT DO NOTHING). Also defaults any NULL
    sources.evidence_class to 'secondary' (analyst/docs/blogs are not behavioral evidence).
    """
    con.execute(f"UPDATE {domain}.sources SET evidence_class = 'secondary' WHERE evidence_class IS NULL")
    cls = dict(
        con.execute(f"SELECT id, COALESCE(evidence_class,'secondary') FROM {domain}.sources").fetchall()
    )
    rows = con.execute(
        f"SELECT id, supporting_source_ids, contradicting_source_ids FROM {domain}.claims"
    ).fetchall()
    ins = 0
    for cid, sup, contra in rows:
        for stance, lst in (("supports", sup or []), ("contradicts", contra or [])):
            for i, sid in enumerate(lst):
                ec = cls.get(sid, "secondary")
                ceid = f"{cid}.ce.{stance[:3]}.{i}"
                con.execute(
                    f"INSERT INTO {domain}.claim_evidence "
                    f"(id, claim_id, evidence_id, evidence_class, stance, weight, is_primary, note) "
                    f"VALUES (?,?,?,?,?,?,?,?) ON CONFLICT (id) DO NOTHING",
                    [ceid, cid, sid, ec, stance, 0.5, ec == "primary", "seeded from claim source ids"],
                )
                ins += 1
    return ins


def evidence_audit(con: duckdb.DuckDBPyConnection, domain: str) -> list[tuple]:
    """Claims asserted supported/equivalent but NOT primary-backed → these are 'supported-by-proxy'.

    This is the honesty cap mechanized: such claims (the MetroGraph wedge among them) can never read
    as experimentally proven until a real primary_studies row backs them. Returns the offending claims.
    """
    return con.execute(
        f"""
        SELECT c.id, c.verdict, g.n_supporting_evidence
        FROM {domain}.claims c JOIN {domain}.v_claim_grade g ON g.claim_id = c.id
        WHERE c.verdict IN ('supported','equivalent') AND NOT g.is_primary_backed
        ORDER BY c.id
        """
    ).fetchall()


def register_forecasts(con: duckdb.DuckDBPyConnection, domain: str, horizon_days: int = 365) -> dict[str, int]:
    """Turn predictive claims into datable, scoreable forecasts in forecast_log (idempotent).

    Every claim whose verification_standard is 'predictive' (or whose verdict is 'speculative') becomes a
    forecast with predicted_prob seeded from its confidence (default 0.5) and a resolves_by horizon. This
    is what gives the Brier calibration loop something to score — without it, forecast_log stays empty and
    'predictive' verification is aspirational. Outcomes are filled in later (resolve), never auto-assumed.
    """
    rows = con.execute(
        f"""
        SELECT id, COALESCE(confidence, 0.5), COALESCE(last_verified, CURRENT_DATE)
        FROM {domain}.claims
        WHERE COALESCE(verification_standard, '') = 'predictive' OR verdict = 'speculative'
        """
    ).fetchall()
    n = 0
    for cid, conf, asof in rows:
        prob = min(0.95, max(0.05, float(conf)))
        con.execute(
            f"INSERT INTO {domain}.forecast_log "
            f"(id, claim_id, predicted_prob, predicted_at, resolves_by, resolved, notes) "
            f"VALUES (?,?,?,?, CAST(? AS DATE) + INTERVAL ({horizon_days}) DAY, FALSE, 'auto-registered from predictive claim') "
            f"ON CONFLICT (id) DO UPDATE SET predicted_prob = excluded.predicted_prob, resolves_by = excluded.resolves_by",
            [f"{domain}.fc.{cid.split('.')[-1]}", cid, prob, asof, asof],
        )
        n += 1
    return {"forecasts_registered": n, "horizon_days": horizon_days}


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
