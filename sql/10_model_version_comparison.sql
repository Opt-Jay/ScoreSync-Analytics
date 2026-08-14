-- ============================================================
-- ScoreSync Analytics
-- Script: 10_model_version_comparison.sql
-- Purpose: Compare engine/model versions across all three prediction cards.
-- ============================================================

USE scoresync_analytics;

WITH scored AS (
    SELECT
        prediction_engine_version,
        model_version,
        fixture_date,
        prediction_correct AS btts_correct,
        CASE
            WHEN overall_home = overall_away THEN NULL
            WHEN overall_home > overall_away AND result = 'HOME' THEN 1
            WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
            ELSE 0
        END AS strength_fulfilled,
        CASE
            WHEN result_home > result_draw AND result_home > result_away THEN
                CASE WHEN result = 'HOME' THEN 1 ELSE 0 END
            WHEN result_draw > result_home AND result_draw > result_away THEN
                CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END
            WHEN result_away > result_home AND result_away > result_draw THEN
                CASE WHEN result = 'AWAY' THEN 1 ELSE 0 END
            ELSE NULL
        END AS result_correct
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
)
SELECT
    prediction_engine_version,
    COALESCE(model_version, '(not recorded)') AS model_version,
    COUNT(*) AS completed_fixtures,
    MIN(fixture_date) AS first_fixture_date,
    MAX(fixture_date) AS last_fixture_date,
    ROUND(100.0 * AVG(btts_correct), 1) AS btts_accuracy_pct,
    ROUND(100.0 * AVG(strength_fulfilled), 1) AS strength_fulfillment_pct,
    ROUND(100.0 * AVG(result_correct), 1) AS result_accuracy_when_predicted_pct,
    ROUND(100.0 * AVG(result_correct IS NOT NULL), 1) AS result_coverage_pct
FROM scored
GROUP BY prediction_engine_version, model_version
ORDER BY prediction_engine_version, model_version;

-- High-confidence performance by engine and card
SELECT
    prediction_engine_version,
    card,
    COUNT(*) AS high_conf_predictions,
    ROUND(100.0 * AVG(fulfilled), 1) AS fulfillment_rate_pct,
    ROUND(AVG(confidence_score), 1) AS avg_confidence_score,
    ROUND(AVG(confidence_score) - 100.0 * AVG(fulfilled), 1) AS confidence_gap_pp
FROM (
    SELECT prediction_engine_version, 'BTTS' AS card,
           prediction_correct AS fulfilled, btts_confidence_score AS confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND btts_confidence_label = 'high'

    UNION ALL

    SELECT prediction_engine_version, 'Strength',
           CASE
               WHEN overall_home > overall_away AND result = 'HOME' THEN 1
               WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
               ELSE 0
           END,
           team_strength_confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND team_strength_confidence_label = 'high'
      AND overall_home <> overall_away

    UNION ALL

    SELECT prediction_engine_version, 'Result',
           CASE
               WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
               WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
               WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
               ELSE NULL
           END,
           result_confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND result_confidence_label = 'high'
) x
WHERE fulfilled IS NOT NULL
GROUP BY prediction_engine_version, card
ORDER BY prediction_engine_version, fulfillment_rate_pct DESC;
