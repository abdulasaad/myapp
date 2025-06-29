-- Debug script for agent showing offline when actually online
-- This will help identify why location updates aren't being sent/received

-- 1. Check the most recent location updates for all agents
SELECT 
    p.full_name,
    p.id as user_id,
    lh.recorded_at,
    lh.accuracy,
    lh.speed,
    EXTRACT(EPOCH FROM (NOW() - lh.recorded_at)) as seconds_ago,
    CASE 
        WHEN lh.recorded_at IS NULL THEN 'No Location Data'
        WHEN EXTRACT(EPOCH FROM (NOW() - lh.recorded_at)) <= 45 THEN 'Should be Active'
        WHEN EXTRACT(EPOCH FROM (NOW() - lh.recorded_at)) < 900 THEN 'Should be Away'
        ELSE 'Should be Offline'
    END as expected_status
FROM profiles p
LEFT JOIN LATERAL (
    SELECT recorded_at, accuracy, speed
    FROM location_history
    WHERE user_id = p.id
    ORDER BY recorded_at DESC
    LIMIT 1
) lh ON true
WHERE p.role = 'agent'
ORDER BY lh.recorded_at DESC NULLS LAST;

-- 2. Check if location updates are being inserted at all (last 10 minutes)
SELECT 
    user_id,
    COUNT(*) as updates_count,
    MIN(recorded_at) as first_update,
    MAX(recorded_at) as last_update,
    AVG(EXTRACT(EPOCH FROM (recorded_at - LAG(recorded_at) OVER (PARTITION BY user_id ORDER BY recorded_at)))) as avg_interval_seconds
FROM location_history
WHERE recorded_at > NOW() - INTERVAL '10 minutes'
GROUP BY user_id
ORDER BY last_update DESC;

-- 3. Check for any constraint violations or errors
SELECT 
    COUNT(*) as total_recent_updates,
    COUNT(CASE WHEN recorded_at > NOW() + INTERVAL '1 minute' THEN 1 END) as future_timestamps,
    COUNT(CASE WHEN recorded_at < NOW() - INTERVAL '1 hour' THEN 1 END) as very_old_timestamps
FROM location_history
WHERE recorded_at > NOW() - INTERVAL '10 minutes';

-- 4. Check what the RPC function actually returns right now
SELECT * FROM get_agents_with_last_location() ORDER BY last_seen DESC NULLS LAST LIMIT 5;

-- 5. Test if we can manually insert a location update (to verify constraints work)
-- This will help us understand if the issue is with sending or receiving
-- NOTE: Replace the user_id with an actual agent ID from step 1
/*
INSERT INTO location_history (user_id, location, accuracy, speed, recorded_at)
VALUES (
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1', -- Replace with actual agent ID
    ST_GeomFromText('POINT(44.3868346 33.3166855)', 4326),
    10.0,
    0.0,
    NOW()
);
*/