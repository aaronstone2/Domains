-- MetroGraph market corpus — the "insane queries" over the algebra of facts.
-- Run:  duckdb -readonly _db/knowledge.duckdb < domains/market/queries/insights.sql
-- Grades map A..F -> 5..1 via the gmap() pattern inlined below.

-- 1. WHITESPACE: high-pain features where NO competitor executes well (best quality <= C),
--    i.e. the gap MetroGraph can own.
CREATE OR REPLACE TEMP MACRO qg(g) AS (CASE g WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 WHEN 'D' THEN 2 WHEN 'F' THEN 1 ELSE 0 END);
.print '== 1. WHITESPACE (high pain, no competitor > C) =='
SELECT f.name, f.pain_score, COALESCE(MAX(qg(pf.quality_grade)),0) AS best_competitor_q, COUNT(pf.product_id) AS n_competitors_with
FROM market.features f
LEFT JOIN market.product_features pf ON pf.feature_id=f.id
LEFT JOIN market.products p ON pf.product_id=p.id AND p.is_self=false
WHERE f.pain_score >= 0.7
GROUP BY 1,2 HAVING COALESCE(MAX(qg(pf.quality_grade)),0) <= 3
ORDER BY f.pain_score DESC;

.print '== 2. SEGMENT ATTRACTIVENESS (size x growth x WTP x our_fit / competition) =='
SELECT s.name, s.priority, s.size_usd, s.growth_rate,
       s.willingness_to_pay AS wtp, s.our_fit, s.competition_density,
       (CASE s.willingness_to_pay WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END
        * CASE s.our_fit WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END
        * (1+COALESCE(s.growth_rate,0))
        / CASE s.competition_density WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) AS score
FROM market.segments s ORDER BY score DESC;

.print '== 3. DIFFERENTIATION MATRIX (MetroGraph hci_cost edge vs competitor avg, pain-weighted) =='
WITH us AS (SELECT feature_id, qg(hci_cost) uc FROM market.product_features WHERE product_id='market.product.us'),
     them AS (SELECT pf.feature_id, AVG(qg(pf.hci_cost)) tc FROM market.product_features pf JOIN market.products p ON pf.product_id=p.id WHERE p.is_self=false GROUP BY 1)
SELECT f.name, us.uc AS us_hci, ROUND(them.tc,2) AS their_avg_hci, ROUND((us.uc-them.tc)*f.pain_score,2) AS weighted_edge
FROM us JOIN them USING(feature_id) JOIN market.features f ON f.id=us.feature_id
ORDER BY weighted_edge DESC LIMIT 25;

.print '== 4. PRICING GAP (model-type mix + free-tier norms by archetype) =='
SELECT pm.model_type, COUNT(*) n, SUM(CASE WHEN pm.has_free_tier THEN 1 ELSE 0 END) AS with_free_tier
FROM market.pricing_models pm GROUP BY 1 ORDER BY 2 DESC;

.print '== 5. HCI-COST RANKING (most friction flows: clicks + drop-off) =='
SELECT p.name AS product, fl.flow_name, fl.total_clicks, fl.drop_off_risk, fl.hci_cost
FROM market.ux_flows fl JOIN market.products p ON fl.product_id=p.id
WHERE p.is_self=false ORDER BY fl.total_clicks DESC NULLS LAST LIMIT 20;

.print '== 6. THEORY GROUNDING OF CLAIMS (supported claims + their theory anchors) =='
SELECT c.category, COUNT(*) AS supported_claims, SUM(CASE WHEN len(c.theory_concept_ids)>0 THEN 1 ELSE 0 END) AS theory_grounded
FROM market.claims c WHERE c.verdict='supported' GROUP BY 1 ORDER BY 2 DESC;

.print '== 7. FUNDING / COMPANY LANDSCAPE by category =='
SELECT category, COUNT(*) n_companies FROM market.companies GROUP BY 1 ORDER BY 2 DESC;

.print '== 8. UX ANTIPATTERN PREVALENCE (the endless-panes catalog) =='
SELECT pattern, len(exemplar_product_ids) AS n_products, hci_cost, our_stance
FROM market.ux_patterns WHERE is_antipattern ORDER BY n_products DESC LIMIT 20;

.print '== 9. JOBS->FEATURES TRACEABILITY (high-severity pains MetroGraph relieves) =='
SELECT j.severity, j.statement, j.relief_strength, len(j.addressed_by_feature_ids) AS n_features
FROM market.jobs_pains_gains j WHERE j.kind='pain' AND j.severity IN ('high','critical')
ORDER BY j.severity DESC, n_features DESC LIMIT 25;

.print '== 10. COOPETITION (companies that are both competitor and partner) =='
SELECT DISTINCT co.name FROM market.companies co
JOIN market.competitors cp ON cp.company_id=co.id
JOIN market.partners pa ON pa.partner_company_id=co.id;

.print '== 11. EVIDENCE AUDIT (claims by verdict + agreement) =='
SELECT verdict, COUNT(*) n, ROUND(AVG(agreement_score),2) AS avg_agreement
FROM market.claims GROUP BY 1 ORDER BY 2 DESC;

.print '== 12. BMC COMPLETENESS (9 blocks present for MetroGraph) =='
SELECT block, len(items) AS n_items FROM market.bmc_blocks ORDER BY block;

.print '== 13. MARKET SIZING (TAM/CAGR metrics for the paper) =='
SELECT metric, subject_id, value, unit, as_of FROM market.market_metrics
WHERE metric IN ('tam','sam','som','cagr') ORDER BY value DESC NULLS LAST LIMIT 30;
