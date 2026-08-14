USE scoresync_analytics;

SELECT
    tracking_date,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN btts_confidence_label IS NOT NULL THEN 1 ELSE 0 END) AS has_btts_conf,
    SUM(CASE WHEN result IS NOT NULL AND result != '' THEN 1 ELSE 0 END) AS has_result,
    SUM(CASE WHEN result IS NULL OR result = '' THEN 1 ELSE 0 END) AS pending_result
FROM mip_tracker
GROUP BY tracking_date
ORDER BY tracking_date;