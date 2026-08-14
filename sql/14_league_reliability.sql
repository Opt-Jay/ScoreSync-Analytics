-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 14_league_reliability.sql
-- Purpose: Advanced league reliability by card, scope and recency.
--
-- Design:
-- - one canonical snapshot per fixture;
-- - separate card metrics (no misleading raw BTTS+Result average);
-- - app scope represented as a dimension rather than duplicated queries;
-- - latest seven distinct fixture dates used for the recent view.
-- ============================================================

USE scoresync_analytics;

-- PART 1: All-time reliability by league
WITH scored AS (
    SELECT
        league_name,
        country,
        CASE WHEN league_ranking_pct IS NOT NULL THEN 'IN APP' ELSE 'NOT IN APP' END AS app_scope,
        league_ranking_pct AS app_ranking,
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
        result,
        btts_actual
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND prediction_engine_version = 'v3.0'
)
SELECT
    league_name,
    country,
    app_scope,
    MAX(app_ranking) AS app_ranking,
    COUNT(*) AS fixtures,
    ROUND(100.0 * AVG(btts_correct),1) AS btts_accuracy_pct,
    ROUND(100.0 * AVG(strength_fulfilled),1) AS strength_fulfillment_pct,
    ROUND(100.0 * AVG(result_correct),1) AS result_accuracy_when_predicted_pct,
    ROUND(100.0 * AVG(result_correct IS NOT NULL),1) AS result_coverage_pct,
    ROUND(100.0 * AVG(btts_actual),1) AS actual_btts_rate_pct,
    ROUND(100.0 * AVG(result='DRAW'),1) AS draw_rate_pct,
    ROUND(100.0 * AVG(result='AWAY'),1) AS away_win_rate_pct
FROM scored
GROUP BY league_name, country, app_scope
HAVING COUNT(*) >= 5
ORDER BY btts_accuracy_pct DESC, result_accuracy_when_predicted_pct DESC;

-- PART 2: Card-specific percentile ranks.
-- Percentiles make cross-league comparison possible without pretending that
-- equal raw percentages have equal meaning across different prediction tasks.
WITH league_card AS (
    SELECT league_name, country, 'BTTS' AS card,
           COUNT(*) AS observations, 100.0 * AVG(prediction_correct) AS metric_pct
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND prediction_engine_version='v3.0'
    GROUP BY league_name,country
    HAVING COUNT(*) >= 5

    UNION ALL

    SELECT league_name, country, 'Strength',
           COUNT(*),
           100.0 * AVG(CASE
               WHEN overall_home > overall_away AND result='HOME' THEN 1
               WHEN overall_away > overall_home AND result='AWAY' THEN 1
               ELSE 0 END)
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND prediction_engine_version='v3.0'
      AND overall_home <> overall_away
    GROUP BY league_name,country
    HAVING COUNT(*) >= 5

    UNION ALL

    SELECT league_name, country, 'Result',
           COUNT(*),
           100.0 * AVG(CASE
               WHEN result_home > result_draw AND result_home > result_away THEN result='HOME'
               WHEN result_draw > result_home AND result_draw > result_away THEN result='DRAW'
               WHEN result_away > result_home AND result_away > result_draw THEN result='AWAY'
               ELSE NULL END)
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND prediction_engine_version='v3.0'
    GROUP BY league_name,country
    HAVING COUNT(*) >= 5
)
SELECT
    league_name, country, card, observations,
    ROUND(metric_pct,1) AS metric_pct,
    ROUND(100.0 * PERCENT_RANK() OVER (PARTITION BY card ORDER BY metric_pct),1) AS card_percentile
FROM league_card
ORDER BY card, card_percentile DESC, observations DESC;

-- PART 3: Recent reliability — latest seven distinct fixture dates
WITH recent_dates AS (
    SELECT fixture_date
    FROM (
        SELECT DISTINCT fixture_date
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result <> ''
          AND prediction_engine_version='v3.0'
          AND fixture_date IS NOT NULL
        ORDER BY fixture_date DESC
        LIMIT 7
    ) d
),
recent AS (
    SELECT m.*
    FROM mip_evaluation_latest m
    JOIN recent_dates d ON d.fixture_date=m.fixture_date
    WHERE m.result IS NOT NULL AND m.result <> ''
      AND m.prediction_engine_version='v3.0'
)
SELECT
    league_name,
    country,
    CASE WHEN league_ranking_pct IS NOT NULL THEN 'IN APP' ELSE 'NOT IN APP' END AS app_scope,
    COUNT(*) AS fixtures,
    ROUND(100.0 * AVG(prediction_correct),1) AS recent_btts_accuracy_pct,
    ROUND(100.0 * AVG(CASE
        WHEN overall_home = overall_away THEN NULL
        WHEN overall_home > overall_away AND result='HOME' THEN 1
        WHEN overall_away > overall_home AND result='AWAY' THEN 1
        ELSE 0 END),1) AS recent_strength_fulfillment_pct,
    ROUND(100.0 * AVG(CASE
        WHEN result_home > result_draw AND result_home > result_away THEN result='HOME'
        WHEN result_draw > result_home AND result_draw > result_away THEN result='DRAW'
        WHEN result_away > result_home AND result_away > result_draw THEN result='AWAY'
        ELSE NULL END),1) AS recent_result_accuracy_pct
FROM recent
GROUP BY league_name, country,
         CASE WHEN league_ranking_pct IS NOT NULL THEN 'IN APP' ELSE 'NOT IN APP' END
HAVING COUNT(*) >= 5
ORDER BY recent_btts_accuracy_pct DESC, recent_result_accuracy_pct DESC;

-- PART 4: Away-result signal
SELECT
    league_name,
    country,
    COUNT(*) AS away_predictions,
    SUM(result='AWAY') AS correct_away_predictions,
    ROUND(100.0 * AVG(result='AWAY'),1) AS away_prediction_accuracy_pct,
    ROUND(AVG(result_away),1) AS avg_predicted_away_probability
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version='v3.0'
  AND result_away > result_home
  AND result_away > result_draw
GROUP BY league_name,country
HAVING COUNT(*) >= 3
ORDER BY away_prediction_accuracy_pct DESC, away_predictions DESC;
