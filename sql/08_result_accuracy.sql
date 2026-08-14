-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 08_result_accuracy.sql
-- Purpose: Evaluate HOME/DRAW/AWAY predictions.
-- Separates prediction coverage from accuracy.
-- ============================================================

USE scoresync_analytics;

-- PART 1: Actual result distribution
SELECT
    result,
    COUNT(*) AS fixtures,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
GROUP BY result
ORDER BY fixtures DESC;

-- PART 2: Coverage: did the model produce a unique highest probability?
SELECT
    COUNT(*) AS completed_fixtures,
    SUM(
        CASE WHEN
            (result_home > result_draw AND result_home > result_away) OR
            (result_draw > result_home AND result_draw > result_away) OR
            (result_away > result_home AND result_away > result_draw)
        THEN 1 ELSE 0 END
    ) AS clear_predictions,
    ROUND(100.0 * AVG(
        CASE WHEN
            (result_home > result_draw AND result_home > result_away) OR
            (result_draw > result_home AND result_draw > result_away) OR
            (result_away > result_home AND result_away > result_draw)
        THEN 1 ELSE 0 END
    ), 1) AS prediction_coverage_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0';

-- PART 3: Accuracy conditional on a clear prediction
SELECT
    COUNT(*) AS clear_predictions,
    SUM(
        CASE
            WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
            WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
            WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
            ELSE 0
        END
    ) AS correct_predictions,
    ROUND(100.0 * AVG(
        CASE
            WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
            WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
            WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
            ELSE 0
        END
    ), 1) AS result_accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  );

-- PART 4: Accuracy and coverage by league
SELECT
    league_name,
    country,
    COUNT(*) AS completed_fixtures,
    SUM(clear_prediction) AS clear_predictions,
    ROUND(100.0 * AVG(clear_prediction), 1) AS coverage_pct,
    ROUND(
        100.0 * SUM(correct_prediction) / NULLIF(SUM(clear_prediction), 0),
        1
    ) AS accuracy_when_predicted_pct
FROM (
    SELECT
        league_name, country,
        CASE WHEN
            (result_home > result_draw AND result_home > result_away) OR
            (result_draw > result_home AND result_draw > result_away) OR
            (result_away > result_home AND result_away > result_draw)
        THEN 1 ELSE 0 END AS clear_prediction,
        CASE
            WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
            WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
            WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
            ELSE 0
        END AS correct_prediction
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND prediction_engine_version = 'v3.0'
) x
GROUP BY league_name, country
HAVING COUNT(*) >= 5
ORDER BY accuracy_when_predicted_pct DESC, coverage_pct DESC;

-- PART 5: Competition outcome profile
SELECT
    competition_type,
    COUNT(*) AS fixtures,
    ROUND(AVG(score_home + score_away), 2) AS avg_total_goals,
    ROUND(100.0 * AVG(btts_actual), 1) AS btts_rate_pct,
    ROUND(100.0 * AVG(result = 'HOME'), 1) AS home_win_rate_pct,
    ROUND(100.0 * AVG(result = 'DRAW'), 1) AS draw_rate_pct,
    ROUND(100.0 * AVG(result = 'AWAY'), 1) AS away_win_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
  AND competition_type IS NOT NULL
GROUP BY competition_type
ORDER BY fixtures DESC;
