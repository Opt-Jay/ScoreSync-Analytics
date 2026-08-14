-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 01_create_database.sql
-- Purpose: Create the analytics database safely.
-- MySQL 8+
-- ============================================================

CREATE DATABASE IF NOT EXISTS scoresync_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE scoresync_analytics;

SELECT 'Database scoresync_analytics is ready.' AS status;

-- Destructive reset logic is intentionally excluded from the normal setup.
-- If a full rebuild is required, perform it explicitly outside this workflow.
