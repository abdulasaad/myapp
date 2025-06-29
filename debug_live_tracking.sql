-- Debug live tracking to see if locations are actually updating

-- 1. Check recent location updates for a specific agent (replace with actual agent ID)
SELECT 
    recorded_at,
    ST_AsText(location::geometry) as location_text,
    accuracy,
    speed,
    EXTRACT(EPOCH FROM (recorded_at - LAG(recorded_at) OVER (ORDER BY recorded_at))) as seconds_between_updates
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with actual agent ID
ORDER BY recorded_at DESC
LIMIT 10;

-- 2. Check if agent is moving (distance between consecutive points)
WITH location_changes AS (
    SELECT 
        recorded_at,
        location,
        LAG(location) OVER (ORDER BY recorded_at) as prev_location,
        CASE 
            WHEN LAG(location) OVER (ORDER BY recorded_at) IS NOT NULL THEN
                ST_Distance(
                    location::geography,
                    LAG(location) OVER (ORDER BY recorded_at)::geography
                )
            ELSE 0
        END as distance_moved_meters
    FROM location_history
    WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with actual agent ID
    AND recorded_at > NOW() - INTERVAL '30 minutes'
    ORDER BY recorded_at DESC
)
SELECT 
    recorded_at,
    ST_AsText(location::geometry) as current_location,
    ROUND(distance_moved_meters::numeric, 2) as meters_moved,
    CASE 
        WHEN distance_moved_meters < 5 THEN 'Stationary'
        WHEN distance_moved_meters < 50 THEN 'Walking'
        ELSE 'Moving'
    END as movement_type
FROM location_changes
WHERE prev_location IS NOT NULL
ORDER BY recorded_at DESC
LIMIT 10;

-- 3. Check what the RPC function returns for the agent
SELECT 
    id,
    full_name,
    last_location,
    last_seen,
    EXTRACT(EPOCH FROM (NOW() - last_seen)) as seconds_ago
FROM get_agents_with_last_location()
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with actual agent ID
OR full_name ILIKE '%agentc%';

-- 4. Check if there are multiple recent locations with same coordinates
SELECT 
    ST_AsText(location::geometry) as location_text,
    COUNT(*) as frequency,
    MIN(recorded_at) as first_seen,
    MAX(recorded_at) as last_seen
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Replace with actual agent ID
AND recorded_at > NOW() - INTERVAL '1 hour'
GROUP BY location
ORDER BY frequency DESC;