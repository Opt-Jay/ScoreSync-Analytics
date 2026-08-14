-- ============================================================
-- ScoreSync Analytics v3.0
-- Script: 06_team_strength_accuracy.sql
-- Purpose: Analyse how well team strength ratings predict
--          match outcomes
-- ============================================================
--
-- WHAT THIS ANALYSES:
-- The team strength model assigns overall, attack, defence, and
-- form ratings to each team. This script checks whether the
-- stronger-rated team actually wins more often, and how much
-- the size of the gap matters.
--
-- Key question: Is a bigger strength gap a better predictor?
-- From v2.0 analysis we already know the answer is YES —
-- this confirms it holds in the v3.0 clean dataset too.
--
-- SECTIONS IN THIS SCRIPT:
--   Part 1   Stronger team win rate — overall
--   Part 1b  Stronger team win rate — in-app leagues only
--   Part 2   Win rate by strength gap band
--   Part 2b  Win rate by strength gap band — in-app leagues only
--   Part 3   Home win strength analysis (per league)
--   Part 4   Away win strength analysis (per league)
--   Part 5   Draw analysis (per league)
--   Part 6   Stronger team win rate — ALL vs IN-APP scope comparison
--   Part 7   Draw rate — ALL vs IN-APP scope comparison
--   Part 8   Stronger team win rate — per league (in-app) + min/max range
--   Part 9   Stronger HOME team win rate — ALL vs IN-APP
--   Part 10  Strength gap range — win vs upset (breakeven analysis)
--   Part 11  Team strength range per league (rating spread)
--   Part 12  Home win rate — min/max range across leagues, ALL vs IN-APP
--   Part 13  Away win rate — min/max range across leagues, ALL vs IN-APP
--   Part 14  Draw rate — min/max range across leagues, ALL vs IN-APP
--   Part 15  Draw rate by strength gap band
--   Part 16  Executive summary dashboard — ALL vs IN-APP, all metrics
-- ============================================================

USE scoresync_analytics;

-- ── PART 1: Does the stronger team win? Overall ───────────────────────────
SELECT
    prediction_engine_version,
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
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
GROUP BY prediction_engine_version;


-- ── PART 1b: Does the stronger team win? IN-APP LEAGUES ONLY ─────────────
-- Same as Part 1 but filtered to leagues that appear in the ScoreSync app
-- (league_ranking_pct IS NOT NULL). This isolates model performance on the
-- leagues users actually see and bet on — the most commercially relevant view.
SELECT
    prediction_engine_version,
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
    COUNT(DISTINCT league_name) AS in_app_leagues
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY prediction_engine_version;

-- ── PART 2: Win rate by strength gap band ────────────────────────────────
-- Does a bigger gap mean a more reliable prediction?
-- Expected: clear staircase from very close → huge mismatch
SELECT
    CASE
        WHEN ABS(strength_difference) <= 5  THEN '01: Very close (0-5)'
        WHEN ABS(strength_difference) <= 10 THEN '02: Close (6-10)'
        WHEN ABS(strength_difference) <= 20 THEN '03: Moderate (11-20)'
        WHEN ABS(strength_difference) <= 30 THEN '04: Large (21-30)'
        ELSE '05: Huge mismatch (30+)'
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
    ) AS stronger_team_win_rate,
    ROUND(AVG(ABS(score_home - score_away)), 2) AS avg_goal_margin
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
GROUP BY strength_gap_band
ORDER BY strength_gap_band;

-- ── PART 2b: Win rate by strength gap band — IN-APP LEAGUES ONLY ────────
-- Does a bigger gap mean a more reliable prediction?
-- (league_ranking_pct IS NOT NULL). This isolates model performance on the
-- Expected: clear staircase from very close → huge mismatch
SELECT
    CASE
        WHEN ABS(strength_difference) <= 5  THEN '01: Very close (0-5)'
        WHEN ABS(strength_difference) <= 10 THEN '02: Close (6-10)'
        WHEN ABS(strength_difference) <= 20 THEN '03: Moderate (11-20)'
        WHEN ABS(strength_difference) <= 30 THEN '04: Large (21-30)'
        ELSE '05: Huge mismatch (30+)'
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
    ) AS stronger_team_win_rate,
    ROUND(AVG(ABS(score_home - score_away)), 2) AS avg_goal_margin
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
	AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY strength_gap_band
ORDER BY strength_gap_band;

-- ── PART 3: Home win strength analysis ───────────────────────────────────
SELECT
    m.league_name,
    m.country,
    COUNT(*) AS home_wins,
    total.total_fixtures,
    ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS home_win_rate_pct,
    ROUND(AVG(m.overall_home - m.overall_away), 1) AS avg_home_strength_advantage,
    ROUND(AVG(m.score_home - m.score_away), 2) AS avg_goal_margin
FROM mip_evaluation_latest m
JOIN (
    SELECT league_name, country, COUNT(*) AS total_fixtures
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result != ''
      AND prediction_engine_version = 'v3.0'
    GROUP BY league_name, country
) AS total ON m.league_name = total.league_name AND m.country = total.country
WHERE m.result = 'HOME'
  AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
  AND m.prediction_engine_version = 'v3.0'
GROUP BY m.league_name, m.country, total.total_fixtures
HAVING total.total_fixtures >= 5
ORDER BY home_win_rate_pct DESC;

-- ── PART 4: Away win strength analysis ───────────────────────────────────
SELECT
    m.league_name,
    m.country,
    COUNT(*) AS away_wins,
    total.total_fixtures,
    ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS away_win_rate_pct,
    ROUND(AVG(m.overall_away - m.overall_home), 1) AS avg_away_strength_advantage,
    ROUND(AVG(m.score_away - m.score_home), 2) AS avg_goal_margin
FROM mip_evaluation_latest m
JOIN (
    SELECT league_name, country, COUNT(*) AS total_fixtures
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result != ''
      AND prediction_engine_version = 'v3.0'
    GROUP BY league_name, country
) AS total ON m.league_name = total.league_name AND m.country = total.country
WHERE m.result = 'AWAY'
  AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
  AND m.prediction_engine_version = 'v3.0'
GROUP BY m.league_name, m.country, total.total_fixtures
HAVING total.total_fixtures >= 5
ORDER BY away_win_rate_pct DESC;

-- ── PART 5: Draw analysis ─────────────────────────────────────────────────
SELECT
    m.league_name,
    m.country,
    COUNT(*) AS draws,
    total.total_fixtures,
    ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS draw_rate_pct,
    ROUND(AVG(ABS(m.overall_home - m.overall_away)), 1) AS avg_strength_gap_abs,
    ROUND(AVG(m.score_home + m.score_away), 2) AS avg_total_goals
FROM mip_evaluation_latest m
JOIN (
    SELECT league_name, country, COUNT(*) AS total_fixtures
    FROM mip_evaluation_latest
    WHERE result IS NOT NULL AND result != ''
      AND prediction_engine_version = 'v3.0'
    GROUP BY league_name, country
) AS total ON m.league_name = total.league_name AND m.country = total.country
WHERE m.result = 'DRAW'
  AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
  AND m.prediction_engine_version = 'v3.0'
GROUP BY m.league_name, m.country, total.total_fixtures
HAVING total.total_fixtures >= 5
ORDER BY draw_rate_pct DESC;


-- ============================================================
-- NEW ANALYSES — v3.0 EXTENDED SET
-- ============================================================

-- ── PART 6: Stronger team win rate — ALL vs IN-APP scope comparison ─────
-- Puts Part 1 and Part 1b side by side in one result set for a quick
-- gut-check on whether in-app leagues behave differently from the
-- full dataset.
SELECT
    'ALL LEAGUES' AS scope,
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
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
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
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0';


-- ── PART 7: Draw rate — ALL vs IN-APP scope comparison ──────────────────
-- Are draws more or less common once you narrow to the leagues users
-- actually see in ScoreSync?
SELECT
    'ALL LEAGUES' AS scope,
    COUNT(*) AS total_fixtures,
    SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) AS draws,
    ROUND(SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS draw_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
    COUNT(*) AS total_fixtures,
    SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) AS draws,
    ROUND(SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS draw_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0';


-- ── PART 8: Stronger team win rate — per league (IN-APP) + range ────────
-- 8a: per-league breakdown, so you can see which in-app leagues the model
-- reads well vs poorly.
SELECT
    league_name,
    country,
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
    ) AS stronger_team_win_rate
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0'
GROUP BY league_name, country
HAVING total_fixtures >= 5
ORDER BY stronger_team_win_rate DESC;

-- 8b: min/max/avg range across those in-app leagues — tells you the
-- best-case and worst-case league for this metric, not just the average.
SELECT
    MIN(stronger_team_win_rate) AS lowest_league_win_rate,
    MAX(stronger_team_win_rate) AS highest_league_win_rate,
    ROUND(AVG(stronger_team_win_rate), 1) AS avg_across_leagues,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        league_name,
        country,
        COUNT(*) AS total_fixtures,
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
      AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
      AND league_ranking_pct IS NOT NULL
      AND prediction_engine_version = 'v3.0'
    GROUP BY league_name, country
    HAVING total_fixtures >= 5
) AS league_rates;


-- ── PART 9: Stronger HOME team win rate — ALL vs IN-APP ─────────────────
-- Narrower than Part 1: this ONLY looks at fixtures where the home team
-- is rated stronger, then checks how often they actually convert that
-- into a home win (vs drawing or being upset). Useful for spotting
-- whether home advantage is being double-counted or under-counted.
SELECT
    'ALL LEAGUES' AS scope,
    COUNT(*) AS fixtures_where_home_is_stronger,
    SUM(CASE WHEN result = 'HOME' THEN 1 ELSE 0 END) AS home_wins,
    SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) AS draws,
    SUM(CASE WHEN result = 'AWAY' THEN 1 ELSE 0 END) AS upset_away_wins,
    ROUND(SUM(CASE WHEN result = 'HOME' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS stronger_home_win_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND overall_home > overall_away
  AND prediction_engine_version = 'v3.0'

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
    COUNT(*) AS fixtures_where_home_is_stronger,
    SUM(CASE WHEN result = 'HOME' THEN 1 ELSE 0 END) AS home_wins,
    SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) AS draws,
    SUM(CASE WHEN result = 'AWAY' THEN 1 ELSE 0 END) AS upset_away_wins,
    ROUND(SUM(CASE WHEN result = 'HOME' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS stronger_home_win_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND overall_home > overall_away
  AND league_ranking_pct IS NOT NULL
  AND prediction_engine_version = 'v3.0';


-- ── PART 10: Strength gap range — win vs upset (breakeven analysis) ─────
-- Two questions in one: how SMALL a gap can be and the stronger team
-- still wins, and how BIG a gap can be and the stronger team still
-- gets upset? Where these two ranges overlap is the "danger zone" for
-- the model — gaps in that zone don't reliably predict the outcome.
SELECT
    'Stronger team WON' AS outcome,
    COUNT(*) AS fixtures,
    MIN(ABS(strength_difference)) AS min_gap,
    MAX(ABS(strength_difference)) AS max_gap,
    ROUND(AVG(ABS(strength_difference)), 1) AS avg_gap
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
  AND (
      (overall_home > overall_away AND result = 'HOME')
      OR (overall_away > overall_home AND result = 'AWAY')
  )

UNION ALL

SELECT
    'Stronger team LOST (upset)' AS outcome,
    COUNT(*) AS fixtures,
    MIN(ABS(strength_difference)) AS min_gap,
    MAX(ABS(strength_difference)) AS max_gap,
    ROUND(AVG(ABS(strength_difference)), 1) AS avg_gap
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
  AND (
      (overall_home > overall_away AND result = 'AWAY')
      OR (overall_away > overall_home AND result = 'HOME')
  )

UNION ALL

SELECT
    'Ended in DRAW' AS outcome,
    COUNT(*) AS fixtures,
    MIN(ABS(strength_difference)) AS min_gap,
    MAX(ABS(strength_difference)) AS max_gap,
    ROUND(AVG(ABS(strength_difference)), 1) AS avg_gap
FROM mip_evaluation_latest
WHERE result = 'DRAW'
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0';


-- ── PART 11: Team strength range per league (rating spread) ─────────────
-- Combines every home AND away rating seen in a league into one pool,
-- then reports the min/max/avg. A wide range means the league has both
-- very weak and very strong teams (top-heavy); a narrow range means
-- the league is tightly matched top to bottom.
SELECT
    league_name,
    country,
    COUNT(*) AS rating_observations,
    MIN(rating) AS min_team_strength,
    MAX(rating) AS max_team_strength,
    (MAX(rating) - MIN(rating)) AS strength_range,
    ROUND(AVG(rating), 1) AS avg_team_strength
FROM (
    SELECT league_name, country, overall_home AS rating
    FROM mip_evaluation_latest
    WHERE overall_home IS NOT NULL AND prediction_engine_version = 'v3.0'

    UNION ALL

    SELECT league_name, country, overall_away AS rating
    FROM mip_evaluation_latest
    WHERE overall_away IS NOT NULL AND prediction_engine_version = 'v3.0'
) AS ratings
GROUP BY league_name, country
ORDER BY strength_range DESC;


-- ── PART 12: Home win rate — min/max range across leagues, ALL vs IN-APP ─
-- Extends Part 3: instead of just listing every league, this pulls out
-- the single lowest and highest home win rate league, so you can see
-- how wide the spread really is.
SELECT
    'ALL LEAGUES' AS scope,
    MIN(home_win_rate_pct) AS lowest_home_win_rate,
    MAX(home_win_rate_pct) AS highest_home_win_rate,
    ROUND(AVG(home_win_rate_pct), 1) AS avg_home_win_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS home_win_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'HOME'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_home_rates

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
    MIN(home_win_rate_pct) AS lowest_home_win_rate,
    MAX(home_win_rate_pct) AS highest_home_win_rate,
    ROUND(AVG(home_win_rate_pct), 1) AS avg_home_win_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS home_win_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'HOME'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.league_ranking_pct IS NOT NULL
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_home_rates_inapp;


-- ── PART 13: Away win rate — min/max range across leagues, ALL vs IN-APP ─
SELECT
    'ALL LEAGUES' AS scope,
    MIN(away_win_rate_pct) AS lowest_away_win_rate,
    MAX(away_win_rate_pct) AS highest_away_win_rate,
    ROUND(AVG(away_win_rate_pct), 1) AS avg_away_win_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS away_win_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'AWAY'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_away_rates

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
    MIN(away_win_rate_pct) AS lowest_away_win_rate,
    MAX(away_win_rate_pct) AS highest_away_win_rate,
    ROUND(AVG(away_win_rate_pct), 1) AS avg_away_win_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS away_win_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'AWAY'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.league_ranking_pct IS NOT NULL
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_away_rates_inapp;


-- ── PART 14: Draw rate — min/max range across leagues, ALL vs IN-APP ────
SELECT
    'ALL LEAGUES' AS scope,
    MIN(draw_rate_pct) AS lowest_draw_rate,
    MAX(draw_rate_pct) AS highest_draw_rate,
    ROUND(AVG(draw_rate_pct), 1) AS avg_draw_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS draw_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'DRAW'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_draw_rates

UNION ALL

SELECT
    'IN-APP LEAGUES' AS scope,
    MIN(draw_rate_pct) AS lowest_draw_rate,
    MAX(draw_rate_pct) AS highest_draw_rate,
    ROUND(AVG(draw_rate_pct), 1) AS avg_draw_rate,
    COUNT(*) AS leagues_counted
FROM (
    SELECT
        m.league_name,
        m.country,
        ROUND(COUNT(*) / total.total_fixtures * 100, 1) AS draw_rate_pct
    FROM mip_evaluation_latest m
    JOIN (
        SELECT league_name, country, COUNT(*) AS total_fixtures
        FROM mip_evaluation_latest
        WHERE result IS NOT NULL AND result != ''
          AND prediction_engine_version = 'v3.0'
        GROUP BY league_name, country
    ) AS total ON m.league_name = total.league_name AND m.country = total.country
    WHERE m.result = 'DRAW'
      AND m.overall_home IS NOT NULL AND m.overall_away IS NOT NULL
  AND m.overall_home <> m.overall_away
      AND m.league_ranking_pct IS NOT NULL
      AND m.prediction_engine_version = 'v3.0'
    GROUP BY m.league_name, m.country, total.total_fixtures
    HAVING total.total_fixtures >= 5
) AS league_draw_rates_inapp;


-- ── PART 15: Draw rate by strength gap band ──────────────────────────────
-- Mirrors Part 2, but for draws instead of stronger-team wins.
-- Expected: draw rate should SHRINK as the gap grows (mismatched teams
-- rarely draw). If it doesn't, that's a validation flag worth chasing —
-- similar in spirit to the BTTS NO misvalidation already on the list.
SELECT
    CASE
        WHEN ABS(strength_difference) <= 5  THEN '01: Very close (0-5)'
        WHEN ABS(strength_difference) <= 10 THEN '02: Close (6-10)'
        WHEN ABS(strength_difference) <= 20 THEN '03: Moderate (11-20)'
        WHEN ABS(strength_difference) <= 30 THEN '04: Large (21-30)'
        ELSE '05: Huge mismatch (30+)'
    END AS strength_gap_band,
    COUNT(*) AS fixtures,
    SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) AS draws,
    ROUND(SUM(CASE WHEN result = 'DRAW' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS draw_rate_pct
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != ''
  AND strength_difference IS NOT NULL
  AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND prediction_engine_version = 'v3.0'
GROUP BY strength_gap_band
ORDER BY strength_gap_band;


-- ── PART 16: Executive summary dashboard — ALL vs IN-APP, all metrics ───
-- One table, four core rates, two scopes. Meant as the "read this first"
-- section — everything above is the drill-down if a number here looks off.
SELECT 'ALL LEAGUES' AS scope, 'Stronger team wins' AS metric,
    ROUND(SUM(CASE WHEN (overall_home > overall_away AND result='HOME') OR (overall_away > overall_home AND result='AWAY') THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS rate_pct,
    COUNT(*) AS fixtures
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'ALL LEAGUES', 'Home win',
    ROUND(SUM(CASE WHEN result='HOME' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'ALL LEAGUES', 'Away win',
    ROUND(SUM(CASE WHEN result='AWAY' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'ALL LEAGUES', 'Draw',
    ROUND(SUM(CASE WHEN result='DRAW' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'IN-APP LEAGUES', 'Stronger team wins',
    ROUND(SUM(CASE WHEN (overall_home > overall_away AND result='HOME') OR (overall_away > overall_home AND result='AWAY') THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'IN-APP LEAGUES', 'Home win',
    ROUND(SUM(CASE WHEN result='HOME' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'IN-APP LEAGUES', 'Away win',
    ROUND(SUM(CASE WHEN result='AWAY' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL AND prediction_engine_version = 'v3.0'

UNION ALL
SELECT 'IN-APP LEAGUES', 'Draw',
    ROUND(SUM(CASE WHEN result='DRAW' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1),
    COUNT(*)
FROM mip_evaluation_latest
WHERE result IS NOT NULL AND result != '' AND overall_home IS NOT NULL AND overall_away IS NOT NULL
  AND overall_home <> overall_away
  AND league_ranking_pct IS NOT NULL AND prediction_engine_version = 'v3.0'

ORDER BY scope, metric;
