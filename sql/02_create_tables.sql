-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 02_create_tables.sql
-- Purpose: Create all tables for the v3.0 analytics baseline
-- Run this ONCE after 01_create_database.sql
-- ============================================================

USE scoresync_analytics;

-- ============================================================
-- TABLE 1: mip_engine_versions
-- Master registry of every prediction engine version ever used.
-- Every mip_tracker row references a version_code from this table.
-- ============================================================

CREATE TABLE IF NOT EXISTS mip_engine_versions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    version_code    VARCHAR(20) NOT NULL UNIQUE,
    description     VARCHAR(255),
    live_from       DATE,
    live_to         DATE,
    is_active       TINYINT(1) DEFAULT 0,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed with known versions
INSERT INTO mip_engine_versions
    (version_code, description, live_from, live_to, is_active, notes)
VALUES
    ('v1.0', 'Original confidence engine — venue/count-based confidence label',
     '2026-06-01', '2026-06-24', 0,
     'Confidence was based on data completeness (venueMatchCount), not predictive accuracy. Flat calibration across all tiers.'),

    ('v2.0', 'Strength gap confidence engine — strength_gap_v2',
     '2026-06-25', '2026-07-01', 0,
     'Confidence recalculated from ABS(strength_difference): >20=high, 11-20=medium, <=10=low. Improved staircase but single generic label for all cards.'),

    ('v3.0', 'Card-specific confidence engine — btts/strength/result confidence',
     '2026-07-02', NULL, 1,
     'Three separate confidence scores per fixture: btts_confidence, team_strength_confidence, result_confidence. Each has its own label, score, source, and reasons. Clean analytics baseline.');


-- ============================================================
-- TABLE 2: mip_tracker
-- One row per fixture per tracking date.
-- This is the core analytics table for all v3.0 analysis.
-- ============================================================

CREATE TABLE IF NOT EXISTS mip_tracker (

    -- Primary key
    id                              INT AUTO_INCREMENT PRIMARY KEY,

    -- ── Fixture identity ──────────────────────────────────
    fixture_id                      BIGINT,
    fixture_date                    DATE,
    tracking_date                   DATE,

    -- ── Match context ─────────────────────────────────────
    league_name                     VARCHAR(150),
    country                         VARCHAR(100),
    competition_type                VARCHAR(50),
    home_team                       VARCHAR(100),
    away_team                       VARCHAR(100),
    venue                           VARCHAR(150),

    -- ── BTTS prediction ───────────────────────────────────
    btts_yes                        INT,
    btts_no                         INT,
    btts_verdict                    VARCHAR(80),

    -- ── League context ────────────────────────────────────
    league_ranking_pct              DECIMAL(5,2),
    matches_analysed                INT,

    -- ── Result probabilities ──────────────────────────────
    result_home                     INT,
    result_draw                     INT,
    result_away                     INT,

    -- ── Team strength ratings ─────────────────────────────
    attack_home                     INT,
    attack_away                     INT,
    defence_home                    INT,
    defence_away                    INT,
    form_home                       INT,
    form_away                       INT,
    overall_home                    INT,
    overall_away                    INT,
    strength_difference             INT,
    strength_verdict                VARCHAR(50),

    -- ── Legacy confidence (kept for backward compat) ──────
    confidence                      VARCHAR(20),
    confidence_source               VARCHAR(50),

    -- ── BTTS confidence (v3.0+) ───────────────────────────
    btts_confidence_label           VARCHAR(20),
    btts_confidence_score           INT,
    btts_confidence_source          VARCHAR(50),

    -- ── Team strength confidence (v3.0+) ──────────────────
    team_strength_confidence_label  VARCHAR(20),
    team_strength_confidence_score  INT,
    team_strength_confidence_source VARCHAR(50),

    -- ── Result confidence (v3.0+) ─────────────────────────
    result_confidence_label         VARCHAR(20),
    result_confidence_score         INT,
    result_confidence_source        VARCHAR(50),

    -- ── Actual result (populated when match completes) ────
    score_home                      INT,
    score_away                      INT,
    outcome_home                    VARCHAR(10),
    outcome_away                    VARCHAR(10),
    result                          VARCHAR(10),

    -- ── Model/engine versioning ───────────────────────────
    model_version                   VARCHAR(50),
    prediction_engine_version       VARCHAR(20) DEFAULT 'v3.0',

    -- ── Import audit trail ────────────────────────────────
    import_batch_id                 VARCHAR(20),
    source_file_name                VARCHAR(200),
    imported_at                     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- ── Computed fields ───────────────────────────────────
    -- Did both teams score? (1=yes, 0=no, NULL=pending)
    btts_actual                     TINYINT GENERATED ALWAYS AS (
        CASE
            WHEN score_home IS NOT NULL AND score_away IS NOT NULL
                AND score_home > 0 AND score_away > 0 THEN 1
            WHEN score_home IS NOT NULL AND score_away IS NOT NULL THEN 0
            ELSE NULL
        END
    ) STORED,

    -- Was the BTTS prediction correct? (1=yes, 0=no, NULL=pending)
    prediction_correct              TINYINT GENERATED ALWAYS AS (
        CASE
            WHEN score_home IS NULL OR score_away IS NULL THEN NULL
            WHEN btts_yes >= 50 AND score_home > 0 AND score_away > 0 THEN 1
            WHEN btts_yes < 50 AND NOT (score_home > 0 AND score_away > 0) THEN 1
            ELSE 0
        END
    ) STORED,

    -- ── Indexes ───────────────────────────────────────────
    INDEX idx_fixture_id            (fixture_id),
    INDEX idx_fixture_date          (fixture_date),
    INDEX idx_tracking_date         (tracking_date),
    INDEX idx_league                (league_name),
    INDEX idx_country               (country),
    INDEX idx_engine_version        (prediction_engine_version),
    INDEX idx_model_version         (model_version),
    INDEX idx_result                (result),
    INDEX idx_btts_conf_label       (btts_confidence_label),
    INDEX idx_result_conf_label     (result_confidence_label),
    INDEX idx_strength_conf_label   (team_strength_confidence_label),
    INDEX idx_import_batch          (import_batch_id),

    -- Prevent duplicate imports of same fixture on same tracking date
    UNIQUE KEY uq_fixture_tracking  (fixture_id, tracking_date)
);

-- ============================================================
-- CANONICAL EVALUATION VIEW
-- One observation per fixture: the latest tracked prediction snapshot.
-- This prevents repeatedly tracked fixtures from being overweighted in
-- model-performance metrics. Raw import QA should continue to use mip_tracker.
-- ============================================================

CREATE OR REPLACE VIEW mip_evaluation_latest AS
SELECT ranked.*
FROM (
    SELECT
        m.*,
        ROW_NUMBER() OVER (
            PARTITION BY m.fixture_id
            ORDER BY m.tracking_date DESC, m.imported_at DESC, m.id DESC
        ) AS evaluation_snapshot_rank
    FROM mip_tracker AS m
) AS ranked
WHERE ranked.evaluation_snapshot_rank = 1;

SELECT 'Tables and canonical evaluation view created successfully.' AS status;
