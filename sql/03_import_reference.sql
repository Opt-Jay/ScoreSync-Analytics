-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 03_import_reference.sql
-- Purpose: Reference template showing column mapping for imports
-- NOTE: Actual imports are done via the Python import script.
--       This file documents the expected CSV column names and
--       how they map to mip_tracker table columns.
-- ============================================================

USE scoresync_analytics;

-- ============================================================
-- COLUMN MAPPING REFERENCE
-- CSV Column Name              → mip_tracker Column
-- ============================================================
-- fixture_id                   → fixture_id
-- fixture_date                 → fixture_date         (parsed from JS date string)
-- tracking_date                → tracking_date        (parsed from JS date string)
-- league_name                  → league_name
-- country                      → country
-- competition_type             → competition_type
-- home_team                    → home_team
-- away_team                    → away_team
-- venue                        → venue
-- btts_yes                     → btts_yes
-- btts_no                      → btts_no
-- btts_verdict                 → btts_verdict
-- league_ranking_percentage    → league_ranking_pct
-- confidence                   → confidence
-- matches_analysed             → matches_analysed
-- result_home                  → result_home
-- result_draw                  → result_draw
-- result_away                  → result_away
-- attack_home                  → attack_home
-- attack_away                  → attack_away
-- defence_home                 → defence_home
-- defence_away                 → defence_away
-- form_home                    → form_home
-- form_away                    → form_away
-- overall_home                 → overall_home
-- overall_away                 → overall_away
-- strength_difference          → strength_difference
-- strength_verdict             → strength_verdict
-- confidence_source            → confidence_source
-- btts_confidence_label        → btts_confidence_label
-- btts_confidence_score        → btts_confidence_score
-- btts_confidence_source       → btts_confidence_source
-- team_strength_confidence_label  → team_strength_confidence_label
-- team_strength_confidence_score  → team_strength_confidence_score
-- team_strength_confidence_source → team_strength_confidence_source
-- result_confidence_label      → result_confidence_label
-- result_confidence_score      → result_confidence_score
-- result_confidence_source     → result_confidence_source
-- score_home                   → score_home
-- away_score                   → score_away           (NOTE: CSV uses away_score)
-- outcome_home                 → outcome_home
-- outcome_away                 → outcome_away
-- result                       → result
-- model_version                → model_version
-- ============================================================

-- ============================================================
-- IMPORT AUDIT COLUMNS (added automatically by Python script)
-- import_batch_id     = YYYYMMDD of the import date
-- source_file_name    = original CSV filename
-- imported_at         = timestamp of import
-- prediction_engine_version = 'v3.0' (hardcoded for all v3.0 imports)
-- ============================================================

-- ============================================================
-- VERIFICATION QUERIES
-- Run these after each daily import to confirm data landed correctly
-- ============================================================

-- 1. Check latest import batch
SELECT
    import_batch_id,
    source_file_name,
    MIN(imported_at) AS import_started,
    COUNT(*) AS rows_imported,
    COUNT(DISTINCT fixture_date) AS fixture_dates_covered
FROM mip_tracker
GROUP BY import_batch_id, source_file_name
ORDER BY import_batch_id DESC
LIMIT 10;

-- 2. Check new confidence columns are populated
SELECT
    tracking_date,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN btts_confidence_label IS NOT NULL THEN 1 ELSE 0 END) AS has_btts_conf,
    SUM(CASE WHEN team_strength_confidence_label IS NOT NULL THEN 1 ELSE 0 END) AS has_strength_conf,
    SUM(CASE WHEN result_confidence_label IS NOT NULL THEN 1 ELSE 0 END) AS has_result_conf,
    SUM(CASE WHEN result IS NOT NULL AND result != '' THEN 1 ELSE 0 END) AS has_result,
    SUM(CASE WHEN result IS NULL OR result = '' THEN 1 ELSE 0 END) AS pending_result
FROM mip_tracker
GROUP BY tracking_date
ORDER BY tracking_date DESC
LIMIT 10;

-- 3. Engine version distribution
SELECT
    prediction_engine_version,
    model_version,
    COUNT(*) AS fixtures,
    MIN(tracking_date) AS first_seen,
    MAX(tracking_date) AS last_seen
FROM mip_tracker
GROUP BY prediction_engine_version, model_version
ORDER BY prediction_engine_version, model_version;


-- PORTFOLIO DATA-TYPE NOTE
-- league_ranking_pct is DECIMAL(5,2) in the analytics schema.
-- The import process should normalise source values to a numeric percentage
-- (for example 72.5, not '72.5%') and use NULL when no app ranking exists.
