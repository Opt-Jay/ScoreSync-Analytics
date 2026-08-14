-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 05_btts_confidence_validation.sql
-- Purpose: Validate that btts_confidence_label correctly
--          separates reliable BTTS picks from unreliable ones
-- ============================================================
--
-- WHAT THIS ANALYSES:
-- The new confidenceEngine.js calculateBttsConfidence() assigns
-- each prediction a btts_confidence_label (high/medium/low) and
-- a btts_confidence_score (0-100) based on BTTS-specific signals:
--   - Distance of btts_yes from 50% (edge)
--   - League BTTS historical accuracy
--   - Data quality (REAL_DATA / PARTIAL / FULL_ESTIMATE)
--   - Team scoring/conceding sample size
--   - Validation score
--
-- This script checks whether those labels actually separate
-- accurate predictions from inaccurate ones.
--
-- EXPECTED RESULT (good validation):
--   high   → accuracy significantly above overall average
--   medium → accuracy near overall average
--   low    → accuracy below overall average
--
-- If all three tiers cluster within 5 points, the scoring
-- thresholds need adjustment.
-- ============================================================

USE scoresync_analytics;

-- ── PART 1: Accuracy by BTTS confidence tier ─────────────────────────────
SELECT
    btts_confidence_label AS confidence_tier,
    btts_confidence_source AS source,
    COUNT(*) AS total_predictions,
    SUM(prediction_correct) AS correct,
    ROUND(SUM(prediction_correct) / COUNT(*) * 100, 1) AS accuracy_pct,
    ROUND(AVG(btts_confidence_score), 1) AS avg_confidence_score,
    ROUND(AVG(btts_yes), 1) AS avg_btts_yes_pct,
    ROUND(SUM(btts_actual) / COUNT(*) * 100, 1) AS actual_btts_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND btts_confidence_source = 'btts_confidence_v1'
  AND btts_confidence_label IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY btts_confidence_label, btts_confidence_source
ORDER BY accuracy_pct DESC;

-- ── PART 2: Accuracy by score band (granular threshold check) ────────────
-- Use this to fine-tune where high/medium/low cutoffs should sit.
-- Currently: score >= 70 = high, >= 50 = medium, < 50 = low
SELECT
    CASE
        WHEN btts_confidence_score >= 90 THEN '90-100 (very high)'
        WHEN btts_confidence_score >= 80 THEN '80-89'
        WHEN btts_confidence_score >= 70 THEN '70-79 (high threshold)'
        WHEN btts_confidence_score >= 60 THEN '60-69'
        WHEN btts_confidence_score >= 50 THEN '50-59 (medium threshold)'
        WHEN btts_confidence_score >= 40 THEN '40-49'
        WHEN btts_confidence_score >= 30 THEN '30-39'
        ELSE 'below 30 (very low)'
    END AS score_band,
    COUNT(*) AS total,
    SUM(prediction_correct) AS correct,
    ROUND(SUM(prediction_correct) / COUNT(*) * 100, 1) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND btts_confidence_source = 'btts_confidence_v1'
  AND btts_confidence_score IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY score_band
ORDER BY MIN(btts_confidence_score) DESC;

-- ── PART 3: Accuracy by confidence tier AND league ───────────────────────
-- Shows which leagues the BTTS confidence model performs best in,
-- broken down by tier. Min 3 fixtures per group.
SELECT
    btts_confidence_label AS confidence_tier,
    league_name,
    country,
    COUNT(*) AS fixtures,
    ROUND(SUM(prediction_correct) / COUNT(*) * 100, 1) AS accuracy_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND btts_confidence_source = 'btts_confidence_v1'
  AND btts_confidence_label IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY btts_confidence_label, league_name, country
HAVING fixtures >= 3
ORDER BY btts_confidence_label, accuracy_pct DESC;
