-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 04_btts_accuracy.sql
-- Purpose: Evaluate BTTS classification accuracy and probability calibration.
-- Uses one canonical prediction snapshot per fixture.
-- ============================================================

USE scoresync_analytics;

-- PART 1: Headline classification accuracy
SELECT
    prediction_engine_version,
    COUNT(*) AS total_predictions,
    SUM(prediction_correct) AS correct_predictions,
    ROUND(100.0 * AVG(prediction_correct), 2) AS classification_accuracy_pct,
    ROUND(100.0 * AVG(btts_actual), 2) AS observed_btts_rate_pct,
    ROUND(AVG(btts_yes), 2) AS avg_predicted_btts_yes_pct,
    ROUND(AVG(btts_yes) - 100.0 * AVG(btts_actual), 2) AS calibration_gap_pp
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
GROUP BY prediction_engine_version
ORDER BY prediction_engine_version;

-- PART 2: Verdict performance
SELECT
    btts_verdict,
    COUNT(*) AS fixtures,
    SUM(prediction_correct) AS correct,
    ROUND(100.0 * AVG(prediction_correct), 1) AS classification_accuracy_pct,
    ROUND(AVG(btts_yes), 1) AS avg_predicted_yes_pct,
    ROUND(100.0 * AVG(btts_actual), 1) AS observed_btts_rate_pct,
    ROUND(AVG(btts_yes) - 100.0 * AVG(btts_actual), 1) AS calibration_gap_pp
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
GROUP BY btts_verdict
ORDER BY avg_predicted_yes_pct DESC;

-- PART 3: Probability calibration bands
SELECT
    CASE
        WHEN btts_yes >= 85 THEN '85-100'
        WHEN btts_yes >= 70 THEN '70-84'
        WHEN btts_yes >= 60 THEN '60-69'
        WHEN btts_yes >= 50 THEN '50-59'
        WHEN btts_yes >= 40 THEN '40-49'
        WHEN btts_yes >= 30 THEN '30-39'
        ELSE '0-29'
    END AS predicted_yes_band,
    COUNT(*) AS fixtures,
    ROUND(AVG(btts_yes), 1) AS avg_predicted_yes_pct,
    ROUND(100.0 * AVG(btts_actual), 1) AS observed_btts_rate_pct,
    ROUND(AVG(btts_yes) - 100.0 * AVG(btts_actual), 1) AS calibration_gap_pp,
    ROUND(100.0 * AVG(prediction_correct), 1) AS classification_accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
GROUP BY predicted_yes_band
ORDER BY MIN(btts_yes) DESC;

-- PART 4: League performance (minimum 5 independent fixtures)
SELECT
    league_name,
    country,
    COUNT(*) AS fixtures,
    ROUND(100.0 * AVG(prediction_correct), 1) AS classification_accuracy_pct,
    ROUND(AVG(btts_yes), 1) AS avg_predicted_yes_pct,
    ROUND(100.0 * AVG(btts_actual), 1) AS observed_btts_rate_pct,
    ROUND(AVG(btts_yes) - 100.0 * AVG(btts_actual), 1) AS calibration_gap_pp
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
GROUP BY league_name, country
HAVING COUNT(*) >= 5
ORDER BY classification_accuracy_pct DESC, fixtures DESC;

-- PART 5: Fixture-date trend (not repeated tracking snapshots)
SELECT
    fixture_date,
    COUNT(*) AS completed_fixtures,
    SUM(prediction_correct) AS correct,
    ROUND(100.0 * AVG(prediction_correct), 1) AS daily_accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
  AND fixture_date IS NOT NULL
GROUP BY fixture_date
ORDER BY fixture_date;

-- PART 6: Day-of-week patterns
SELECT
    DAYNAME(fixture_date) AS day_of_week,
    COUNT(*) AS fixtures,
    ROUND(100.0 * AVG(prediction_correct), 1) AS accuracy_pct,
    ROUND(100.0 * AVG(btts_actual), 1) AS observed_btts_rate_pct,
    ROUND(AVG(score_home + score_away), 2) AS avg_total_goals
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result <> ''
  AND prediction_engine_version = 'v3.0'
  AND fixture_date IS NOT NULL
GROUP BY DAYNAME(fixture_date), DAYOFWEEK(fixture_date)
ORDER BY DAYOFWEEK(fixture_date);
