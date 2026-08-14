-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 09_result_confidence_validation.sql
-- Purpose: Validate that result_confidence_label correctly
--          identifies when the HOME/DRAW/AWAY prediction is reliable
-- ============================================================

USE scoresync_analytics;

-- ── PART 1: Result accuracy by confidence tier ───────────────────────────
SELECT
    result_confidence_label AS confidence_tier,
    result_confidence_source AS source,
    COUNT(*) AS fixtures,
    SUM(
        CASE
            WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
            WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
            WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
            ELSE 0
        END
    ) AS correct,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS result_accuracy_pct,
    ROUND(AVG(result_confidence_score), 1) AS avg_confidence_score
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_label IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY result_confidence_label, result_confidence_source
ORDER BY result_accuracy_pct DESC;

-- ── PART 1b: Result accuracy by confidence tier (ScoreSync App)───────────────────────────
SELECT
    result_confidence_label AS confidence_tier,
    result_confidence_source AS source,
    COUNT(*) AS fixtures,
    SUM(
        CASE
            WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
            WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
            WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
            ELSE 0
        END
    ) AS correct,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS result_accuracy_pct,
    ROUND(AVG(result_confidence_score), 1) AS avg_confidence_score
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_label IS NOT NULL
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY result_confidence_label, result_confidence_source
ORDER BY result_accuracy_pct DESC;

-- ── PART 2: Accuracy by predicted result within each tier ────────────────
-- Draws are notoriously harder — watch for draw performance specifically
SELECT
    result_confidence_label AS confidence_tier,
    CASE
        WHEN result_home > result_draw AND result_home > result_away THEN 'HOME predicted'
        WHEN result_away > result_home AND result_away > result_draw THEN 'AWAY predicted'
        WHEN result_draw > result_home AND result_draw > result_away THEN 'DRAW predicted'
        ELSE 'No clear prediction'
    END AS predicted_result,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_label IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY result_confidence_label, predicted_result
ORDER BY result_confidence_label, accuracy_pct DESC;

-- ── PART 2b: Accuracy by predicted result within each tier (ScoreSync App)────────────────
-- Draws are notoriously harder — watch for draw performance specifically
SELECT
    result_confidence_label AS confidence_tier,
    CASE
        WHEN result_home > result_draw AND result_home > result_away THEN 'HOME predicted'
        WHEN result_away > result_home AND result_away > result_draw THEN 'AWAY predicted'
        WHEN result_draw > result_home AND result_draw > result_away THEN 'DRAW predicted'
        ELSE 'No clear prediction'
    END AS predicted_result,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_label IS NOT NULL
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY result_confidence_label, predicted_result
ORDER BY result_confidence_label, accuracy_pct DESC;

-- ── PART 3: Score band granularity ───────────────────────────────────────
SELECT
    CASE
        WHEN result_confidence_score >= 80 THEN '80-100 (very high)'
        WHEN result_confidence_score >= 70 THEN '70-79'
        WHEN result_confidence_score >= 60 THEN '60-69'
        WHEN result_confidence_score >= 50 THEN '50-59'
        WHEN result_confidence_score >= 40 THEN '40-49'
        ELSE 'below 40'
    END AS score_band,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_score IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY score_band
ORDER BY MIN(result_confidence_score) DESC;

-- ── PART 3b: Score band granularity(ScoreSync App) ───────────────────────────────────────
SELECT
    CASE
        WHEN result_confidence_score >= 80 THEN '80-100 (very high)'
        WHEN result_confidence_score >= 70 THEN '70-79'
        WHEN result_confidence_score >= 60 THEN '60-69'
        WHEN result_confidence_score >= 50 THEN '50-59'
        WHEN result_confidence_score >= 40 THEN '40-49'
        ELSE 'below 40'
    END AS score_band,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN result_home > result_draw AND result_home > result_away AND result = 'HOME' THEN 1
                WHEN result_away > result_home AND result_away > result_draw AND result = 'AWAY' THEN 1
                WHEN result_draw > result_home AND result_draw > result_away AND result = 'DRAW' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND result_confidence_source = 'result_confidence_v1'
  AND result_confidence_score IS NOT NULL
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
  AND (
      (result_home > result_draw AND result_home > result_away) OR
      (result_draw > result_home AND result_draw > result_away) OR
      (result_away > result_home AND result_away > result_draw)
  )
GROUP BY score_band
ORDER BY MIN(result_confidence_score) DESC;

