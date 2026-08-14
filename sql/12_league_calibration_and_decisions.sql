-- ============================================================
-- ScoreSync Analytics
-- Script: 12_league_calibration_and_decisions.sql
-- Purpose: Evidence-aware, self-recalibrating league decisions.
--
-- Method:
--   1) absolute floor prevents a weak population redefining "good";
--   2) population percentiles adapt to current model performance;
--   3) minimum evidence prevents tiny samples driving decisions.
-- ============================================================

USE scoresync_analytics;

WITH league_metrics AS (
    SELECT
        league_name,
        country,
        CASE WHEN league_ranking_pct IS NOT NULL THEN 'IN APP' ELSE 'NOT IN APP' END AS app_status,
        MAX(league_ranking_pct) AS app_ranking,
        COUNT(*) AS fixtures,
        100.0 * AVG(prediction_correct) AS btts_accuracy,
        100.0 * AVG(
            CASE
                WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
                WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
                WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
                ELSE NULL
            END
        ) AS result_accuracy,
        100.0 * AVG(
            CASE
                WHEN overall_home = overall_away THEN NULL
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        ) AS strength_fulfillment
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND prediction_engine_version = 'v3.0'
    GROUP BY league_name, country,
             CASE WHEN league_ranking_pct IS NOT NULL THEN 'IN APP' ELSE 'NOT IN APP' END
),
scored AS (
    SELECT
        *,
        -- Equal weighting only after each card has been measured on its own valid denominator.
        (btts_accuracy + result_accuracy + strength_fulfillment) / 3.0 AS reliability_score
    FROM league_metrics
    WHERE fixtures >= 5
      AND btts_accuracy IS NOT NULL
      AND result_accuracy IS NOT NULL
      AND strength_fulfillment IS NOT NULL
),
ranked AS (
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY reliability_score) AS population_percentile
    FROM scored
)
SELECT
    league_name,
    country,
    app_status,
    app_ranking,
    fixtures,
    ROUND(btts_accuracy, 1) AS btts_accuracy_pct,
    ROUND(result_accuracy, 1) AS result_accuracy_pct,
    ROUND(strength_fulfillment, 1) AS strength_fulfillment_pct,
    ROUND(reliability_score, 1) AS reliability_score,
    ROUND(population_percentile * 100, 1) AS population_percentile_pct,
    CASE
        WHEN fixtures < 10 THEN 'WATCH'
        WHEN reliability_score < 45 THEN 'POOR'
        WHEN reliability_score >= 55 AND population_percentile >= 0.67 THEN 'GOOD'
        WHEN population_percentile < 0.20 THEN 'POOR'
        ELSE 'WATCH'
    END AS decision_band,
    CASE
        WHEN fixtures < 10 THEN 'Collect more evidence'
        WHEN reliability_score < 45 THEN 'Tune or deprioritise'
        WHEN reliability_score >= 55 AND population_percentile >= 0.67 THEN
            CASE WHEN app_status = 'IN APP' THEN 'Keep / prioritise' ELSE 'Candidate for app' END
        WHEN population_percentile < 0.20 THEN 'Tune or deprioritise'
        ELSE 'Monitor'
    END AS recommended_action
FROM ranked
ORDER BY
    CASE decision_band WHEN 'GOOD' THEN 1 WHEN 'WATCH' THEN 2 ELSE 3 END,
    reliability_score DESC,
    fixtures DESC;
