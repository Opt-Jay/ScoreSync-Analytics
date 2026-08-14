-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 07_strength_confidence_validation.sql
-- Purpose: Validate that team_strength_confidence_label correctly
--          identifies when the strength comparison can be trusted
-- ============================================================
--
-- WHAT THIS ANALYSES:
-- calculateTeamStrengthConfidence() scores each fixture based on:
--   - ABS(strength_difference): the primary driver
--   - Data quality (REAL_DATA / PARTIAL / FULL_ESTIMATE)
--   - Team sample size
--   - Whether ratings are real or estimated
--
-- Key question: Do "high" strength confidence fixtures have a
-- meaningfully higher stronger-team win rate than "low" ones?
--
-- EXPECTED RESULT:
--   high   → stronger team wins ~70-80% of the time
--   medium → stronger team wins ~55-65% of the time
--   low    → stronger team wins ~40-50% of the time
-- ============================================================

USE scoresync_analytics;

-- ── PART 1: Stronger team win rate by confidence tier ────────────────────
SELECT
    team_strength_confidence_label AS confidence_tier,
    team_strength_confidence_source AS source,
    COUNT(*) AS total_fixtures,
    SUM(
        CASE
            WHEN overall_home > overall_away AND result = 'HOME' THEN 1
            WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
            ELSE 0
        END
    ) AS stronger_team_won,
    ROUND(
        SUM(
            CASE
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS stronger_team_win_rate,
    ROUND(AVG(ABS(strength_difference)), 1) AS avg_strength_gap,
    ROUND(AVG(team_strength_confidence_score), 1) AS avg_confidence_score
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND team_strength_confidence_source = 'team_strength_confidence_v1'
  AND team_strength_confidence_label IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
GROUP BY team_strength_confidence_label, team_strength_confidence_source
ORDER BY stronger_team_win_rate DESC;

-- ── PART 1b: Stronger team win rate by confidence tier (LEAGUES CONFIGURED IN ScoreSync)────────────────────
SELECT
    team_strength_confidence_label AS confidence_tier,
    team_strength_confidence_source AS source,
    COUNT(*) AS total_fixtures,
    SUM(
        CASE
            WHEN overall_home > overall_away AND result = 'HOME' THEN 1
            WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
            ELSE 0
        END
    ) AS stronger_team_won,
    ROUND(
        SUM(
            CASE
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS stronger_team_win_rate,
    ROUND(AVG(ABS(strength_difference)), 1) AS avg_strength_gap,
    ROUND(AVG(team_strength_confidence_score), 1) AS avg_confidence_score
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND team_strength_confidence_source = 'team_strength_confidence_v1'
  AND team_strength_confidence_label IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY team_strength_confidence_label, team_strength_confidence_source
ORDER BY stronger_team_win_rate DESC;

-- ── PART 2: Cross-reference confidence tier vs strength gap band ──────────
SELECT
    team_strength_confidence_label AS confidence_tier,
    CASE
        WHEN ABS(strength_difference) <= 5  THEN '01: Very close (0-5)'
        WHEN ABS(strength_difference) <= 10 THEN '02: Close (6-10)'
        WHEN ABS(strength_difference) <= 20 THEN '03: Moderate (11-20)'
        WHEN ABS(strength_difference) <= 30 THEN '04: Large (21-30)'
        ELSE '05: Huge (30+)'
    END AS strength_gap_band,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND team_strength_confidence_source = 'team_strength_confidence_v1'
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
GROUP BY team_strength_confidence_label, strength_gap_band
ORDER BY team_strength_confidence_label, strength_gap_band;

-- ── PART 2b: Cross-reference confidence tier vs strength gap band (LEAGUES CONFIGURED IN ScoreSync)──────────
SELECT
    team_strength_confidence_label AS confidence_tier,
    CASE
        WHEN ABS(strength_difference) <= 5  THEN '01: Very close (0-5)'
        WHEN ABS(strength_difference) <= 10 THEN '02: Close (6-10)'
        WHEN ABS(strength_difference) <= 20 THEN '03: Moderate (11-20)'
        WHEN ABS(strength_difference) <= 30 THEN '04: Large (21-30)'
        ELSE '05: Huge (30+)'
    END AS strength_gap_band,
    COUNT(*) AS fixtures,
    ROUND(
        SUM(
            CASE
                WHEN overall_home > overall_away AND result = 'HOME' THEN 1
                WHEN overall_away > overall_home AND result = 'AWAY' THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100, 1
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND team_strength_confidence_source = 'team_strength_confidence_v1'
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY team_strength_confidence_label, strength_gap_band
ORDER BY team_strength_confidence_label, strength_gap_band;
