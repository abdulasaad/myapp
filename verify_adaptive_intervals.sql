-- Verify adaptive intervals are working by checking location update frequency

-- 1. Check update intervals for a specific agent
WITH location_intervals AS (
    SELECT 
        recorded_at,
        LAG(recorded_at) OVER (ORDER BY recorded_at) as prev_recorded_at,
        EXTRACT(EPOCH FROM (recorded_at - LAG(recorded_at) OVER (ORDER BY recorded_at))) as seconds_between_updates
    FROM location_history
    WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with agent ID
    AND recorded_at > NOW() - INTERVAL '2 hours'
    ORDER BY recorded_at DESC
)
SELECT 
    recorded_at,
    ROUND(seconds_between_updates) as seconds_between,
    CASE 
        WHEN seconds_between_updates < 45 THEN 'Normal (30s base)'
        WHEN seconds_between_updates BETWEEN 45 AND 90 THEN 'Slow 2x (60s)'
        WHEN seconds_between_updates BETWEEN 90 AND 150 THEN 'Slow 4x (120s)'
        WHEN seconds_between_updates > 150 THEN 'Slow 6x (180s)'
        ELSE 'First update'
    END as interval_type
FROM location_intervals
ORDER BY recorded_at DESC
LIMIT 20;

-- 2. Check average update frequency over time
SELECT 
    DATE_TRUNC('hour', recorded_at) as hour,
    COUNT(*) as updates_count,
    ROUND(3600.0 / COUNT(*)) as avg_seconds_between
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with agent ID
AND recorded_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', recorded_at)
ORDER BY hour DESC;