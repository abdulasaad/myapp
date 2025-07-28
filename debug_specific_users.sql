-- Debug Location History for Specific Users
-- Manager: user.a@test.com
-- Agent: user.agent2@test.com

-- ====================================================================
-- 1. Find the user IDs for these specific users
-- ====================================================================
SELECT 
    id,
    email,
    full_name,
    role,
    status,
    created_at
FROM profiles 
WHERE email IN ('user.a@test.com', 'user.agent2@test.com')
ORDER BY email;

-- ====================================================================
-- 2. Check location history for user.agent2@test.com
-- ====================================================================
SELECT 
    lh.id,
    lh.user_id,
    p.email,
    p.full_name,
    ST_Y(lh.location::geometry) as latitude,
    ST_X(lh.location::geometry) as longitude,
    lh.accuracy,
    lh.speed,
    lh.recorded_at,
    EXTRACT(EPOCH FROM (NOW() - lh.recorded_at))/3600 as hours_ago
FROM location_history lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE p.email = 'user.agent2@test.com'
ORDER BY lh.recorded_at DESC
LIMIT 20;

-- ====================================================================
-- 3. Check active_agents table for user.agent2@test.com
-- ====================================================================
SELECT 
    aa.id,
    aa.user_id,
    p.email,
    p.full_name,
    aa.latitude,
    aa.longitude,
    aa.last_seen,
    aa.accuracy,
    aa.battery_level,
    aa.connection_status,
    EXTRACT(EPOCH FROM (NOW() - aa.last_seen))/3600 as hours_ago
FROM active_agents aa
LEFT JOIN profiles p ON p.id = aa.user_id
WHERE p.email = 'user.agent2@test.com';

-- ====================================================================
-- 4. Check if the agent has background services running
-- ====================================================================
-- This will show recent location updates (last 24 hours)
SELECT 
    COUNT(*) as locations_last_24h,
    MAX(lh.recorded_at) as latest_location,
    MIN(lh.recorded_at) as earliest_location
FROM location_history lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE p.email = 'user.agent2@test.com'
AND lh.recorded_at >= NOW() - INTERVAL '24 hours';

-- ====================================================================
-- 5. Check all location data for the agent (summary)
-- ====================================================================
SELECT 
    COUNT(*) as total_locations,
    MIN(lh.recorded_at) as first_location,
    MAX(lh.recorded_at) as last_location,
    DATE_PART('day', MAX(lh.recorded_at) - MIN(lh.recorded_at)) as days_span
FROM location_history lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE p.email = 'user.agent2@test.com';

-- ====================================================================
-- 6. Check location data by date for the agent
-- ====================================================================
SELECT 
    DATE(lh.recorded_at) as date,
    COUNT(*) as locations_count,
    MIN(lh.recorded_at) as first_location_time,
    MAX(lh.recorded_at) as last_location_time
FROM location_history lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE p.email = 'user.agent2@test.com'
GROUP BY DATE(lh.recorded_at)
ORDER BY date DESC;

-- ====================================================================
-- 7. Check if manager can see agent's data (RLS policies)
-- ====================================================================
-- Check what groups the agent is in
SELECT 
    ug.user_id,
    ug.group_id,
    g.name as group_name,
    p.email,
    p.full_name
FROM user_groups ug
LEFT JOIN groups g ON g.id = ug.group_id
LEFT JOIN profiles p ON p.id = ug.user_id
WHERE p.email = 'user.agent2@test.com';

-- Check what groups the manager is in
SELECT 
    ug.user_id,
    ug.group_id,
    g.name as group_name,
    p.email,
    p.full_name
FROM user_groups ug
LEFT JOIN groups g ON g.id = ug.group_id
LEFT JOIN profiles p ON p.id = ug.user_id
WHERE p.email = 'user.a@test.com';

-- ====================================================================
-- 8. Test if manager can access agent's location history
-- ====================================================================
-- This simulates what the manager would see when querying
SELECT 
    lh.id,
    ST_Y(lh.location::geometry) as latitude,
    ST_X(lh.location::geometry) as longitude,
    lh.recorded_at
FROM location_history_app_format lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE p.email = 'user.agent2@test.com'
ORDER BY lh.created_at DESC
LIMIT 10;

-- ====================================================================
-- 9. Check recent system activity for debugging
-- ====================================================================
-- Check if there are any errors in location insertion
SELECT 
    COUNT(*) as recent_inserts,
    MAX(recorded_at) as latest_insert
FROM location_history 
WHERE recorded_at >= NOW() - INTERVAL '1 hour';

-- ====================================================================
-- 10. Verify the location that shows on the map (7/7/2025)
-- ====================================================================
SELECT 
    lh.id,
    p.email,
    p.full_name,
    ST_Y(lh.location::geometry) as latitude,
    ST_X(lh.location::geometry) as longitude,
    lh.recorded_at,
    ST_AsText(lh.location) as location_text
FROM location_history lh
LEFT JOIN profiles p ON p.id = lh.user_id
WHERE DATE(lh.recorded_at) = '2025-07-07'
AND p.email = 'user.agent2@test.com'
ORDER BY lh.recorded_at DESC;