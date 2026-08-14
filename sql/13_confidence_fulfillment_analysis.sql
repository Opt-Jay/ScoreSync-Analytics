-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 13_confidence_fulfillment_analysis.sql
-- Purpose: Validate confidence fulfilment across BTTS, Strength and Result.
-- ============================================================

USE scoresync_analytics;

-- PART 1: Confidence-tier fulfilment by card
SELECT confidence_tier, card, COUNT(*) AS total,
       SUM(fulfilled) AS fulfilled,
       ROUND(100.0 * AVG(fulfilled), 1) AS fulfillment_rate_pct,
       ROUND(AVG(confidence_score), 1) AS avg_confidence_score,
       ROUND(AVG(confidence_score) - 100.0 * AVG(fulfilled), 1) AS confidence_gap_pp
FROM (
    SELECT btts_confidence_label AS confidence_tier, 'BTTS' AS card,
           prediction_correct AS fulfilled, btts_confidence_score AS confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND btts_confidence_label IS NOT NULL

    UNION ALL

    SELECT team_strength_confidence_label, 'Strength',
           CASE
               WHEN overall_home > overall_away AND result = 'HOME' THEN 1
               WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
               ELSE 0
           END,
           team_strength_confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND team_strength_confidence_label IS NOT NULL
      AND overall_home <> overall_away

    UNION ALL

    SELECT result_confidence_label, 'Result',
           CASE
               WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
               WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
               WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
               ELSE NULL
           END,
           result_confidence_score
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND result_confidence_label IS NOT NULL
) x
WHERE fulfilled IS NOT NULL
GROUP BY confidence_tier, card
ORDER BY FIELD(confidence_tier, 'high','medium','low'), card;

-- PART 2: Which combination of cards was fulfilled?
-- No precedence bias: simultaneous successes are represented explicitly.
WITH f AS (
    SELECT
        fixture_id, fixture_date, league_name, country,
        prediction_correct AS btts_ok,
        CASE
            WHEN overall_home = overall_away THEN NULL
            WHEN overall_home > overall_away AND result = 'HOME' THEN 1
            WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
            ELSE 0
        END AS strength_ok,
        CASE
            WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
            WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
            WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
            ELSE NULL
        END AS result_ok
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND prediction_engine_version = 'v3.0'
)
SELECT
    CASE
        WHEN btts_ok=1 AND strength_ok=1 AND result_ok=1 THEN 'All three'
        WHEN btts_ok=1 AND strength_ok=1 AND COALESCE(result_ok,0)=0 THEN 'BTTS + Strength'
        WHEN btts_ok=1 AND COALESCE(strength_ok,0)=0 AND result_ok=1 THEN 'BTTS + Result'
        WHEN COALESCE(btts_ok,0)=0 AND strength_ok=1 AND result_ok=1 THEN 'Strength + Result'
        WHEN btts_ok=1 AND COALESCE(strength_ok,0)=0 AND COALESCE(result_ok,0)=0 THEN 'BTTS only'
        WHEN COALESCE(btts_ok,0)=0 AND strength_ok=1 AND COALESCE(result_ok,0)=0 THEN 'Strength only'
        WHEN COALESCE(btts_ok,0)=0 AND COALESCE(strength_ok,0)=0 AND result_ok=1 THEN 'Result only'
        ELSE 'None'
    END AS fulfillment_combination,
    COUNT(*) AS fixtures,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_fixtures
FROM f
GROUP BY fulfillment_combination
ORDER BY fixtures DESC;

-- PART 3: League/card fulfilment (minimum five valid observations)
SELECT league_name, country, card, confidence_tier,
       COUNT(*) AS total,
       ROUND(100.0 * AVG(fulfilled), 1) AS fulfillment_rate_pct
FROM (
    SELECT league_name, country, 'BTTS' AS card,
           btts_confidence_label AS confidence_tier,
           prediction_correct AS fulfilled
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND btts_confidence_label IS NOT NULL

    UNION ALL

    SELECT league_name, country, 'Strength',
           team_strength_confidence_label,
           CASE
               WHEN overall_home > overall_away AND result = 'HOME' THEN 1
               WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
               ELSE 0
           END
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> ''
      AND team_strength_confidence_label IS NOT NULL
      AND overall_home <> overall_away

    UNION ALL

    SELECT league_name, country, 'Result',
           result_confidence_label,
           CASE
               WHEN result_home > result_draw AND result_home > result_away THEN result = 'HOME'
               WHEN result_draw > result_home AND result_draw > result_away THEN result = 'DRAW'
               WHEN result_away > result_home AND result_away > result_draw THEN result = 'AWAY'
               ELSE NULL
           END
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND result_confidence_label IS NOT NULL
) x
WHERE fulfilled IS NOT NULL
GROUP BY league_name, country, card, confidence_tier
HAVING COUNT(*) >= 5
ORDER BY league_name, card, FIELD(confidence_tier,'high','medium','low');

-- PART 4: Daily performance
WITH daily AS (
    SELECT fixture_date, 'BTTS' AS card, 100.0 * AVG(prediction_correct) AS daily_fulfillment
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND fixture_date IS NOT NULL
    GROUP BY fixture_date

    UNION ALL

    SELECT fixture_date, 'Strength',
           100.0 * AVG(CASE
               WHEN overall_home > overall_away AND result='HOME' THEN 1
               WHEN overall_away > overall_home AND result='AWAY' THEN 1
               ELSE 0 END)
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND fixture_date IS NOT NULL
      AND overall_home <> overall_away
    GROUP BY fixture_date

    UNION ALL

    SELECT fixture_date, 'Result',
           100.0 * AVG(CASE
               WHEN result_home > result_draw AND result_home > result_away THEN result='HOME'
               WHEN result_draw > result_home AND result_draw > result_away THEN result='DRAW'
               WHEN result_away > result_home AND result_away > result_draw THEN result='AWAY'
               ELSE NULL END)
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND fixture_date IS NOT NULL
    GROUP BY fixture_date
)
SELECT fixture_date, card, ROUND(daily_fulfillment,1) AS daily_fulfillment_pct
FROM daily
ORDER BY fixture_date, card;

-- PART 5: Genuine rolling 7-calendar-day average.
-- Correlated date range handles missing match dates correctly.
WITH daily AS (
    SELECT fixture_date, 'BTTS' AS card, 100.0 * AVG(prediction_correct) AS daily_fulfillment
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result <> '' AND fixture_date IS NOT NULL
    GROUP BY fixture_date
)
SELECT
    d.fixture_date,
    d.card,
    ROUND(d.daily_fulfillment,1) AS daily_fulfillment_pct,
    ROUND((
        SELECT AVG(d2.daily_fulfillment)
        FROM daily d2
        WHERE d2.card=d.card
          AND d2.fixture_date BETWEEN DATE_SUB(d.fixture_date, INTERVAL 6 DAY) AND d.fixture_date
    ),1) AS rolling_7_calendar_day_avg
FROM daily d
ORDER BY d.fixture_date;
