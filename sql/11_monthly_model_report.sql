-- ============================================================
-- ScoreSync Analytics
-- Script: 11_monthly_model_report.sql
-- Purpose: Monthly executive KPI report across BTTS, Strength and Result.
-- ============================================================

USE scoresync_analytics;

WITH scored AS (
    SELECT
        DATE_FORMAT(fixture_date, '%Y-%m') AS month,
        league_name,
        prediction_correct AS btts_correct,
        CASE
            WHEN overall_home = overall_away THEN NULL
            WHEN overall_home > overall_away AND result = 'HOME' THEN 1
            WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
            ELSE 0
        END AS strength_fulfilled,
        CASE
            WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
            WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
            WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
            ELSE NULL
        END AS result_correct,
        CASE WHEN btts_confidence_label = 'high' THEN prediction_correct END AS btts_high_correct,
        CASE WHEN team_strength_confidence_label = 'high' AND overall_home <> overall_away THEN
            CASE
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        END AS strength_high_correct,
        CASE WHEN result_confidence_label = 'high' THEN
            CASE
                WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
                WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
                WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
                ELSE NULL
            END
        END AS result_high_correct
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND fixture_date IS NOT NULL
      AND prediction_engine_version = 'v3.0'
)
SELECT
    month,
    COUNT(*) AS completed_fixtures,
    COUNT(DISTINCT league_name) AS leagues_analysed,
    ROUND(100.0 * AVG(btts_correct), 1) AS btts_accuracy_pct,
    ROUND(100.0 * AVG(strength_fulfilled), 1) AS strength_fulfillment_pct,
    ROUND(100.0 * AVG(result_correct), 1) AS result_accuracy_when_predicted_pct,
    ROUND(100.0 * AVG(result_correct IS NOT NULL), 1) AS result_coverage_pct,
    ROUND(100.0 * AVG(btts_high_correct), 1) AS btts_high_conf_accuracy_pct,
    ROUND(100.0 * AVG(strength_high_correct), 1) AS strength_high_conf_fulfillment_pct,
    ROUND(100.0 * AVG(result_high_correct), 1) AS result_high_conf_accuracy_pct
FROM scored
GROUP BY month
ORDER BY month;
