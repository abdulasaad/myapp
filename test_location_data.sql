-- Query to check recent location data from agents
-- Run this in Supabase SQL editor to verify location tracking is working

-- First, check what location tables exist
SELECT table_name, column_name, data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name LIKE '%location%'
ORDER BY table_name, ordinal_position;

-- Check recent location_history entries (last 10 minutes)
-- Using recorded_at instead of created_at based on schema
SELECT 
    lh.user_id,
    p.full_name,
    p.role,
    lh.location,
    lh.accuracy,
    lh.speed,
    lh.recorded_at
FROM location_history lh
JOIN profiles p ON lh.user_id = p.id
WHERE lh.recorded_at > NOW() - INTERVAL '10 minutes'
    AND p.role = 'agent'
ORDER BY lh.recorded_at DESC
LIMIT 20;

-- Count location updates by user in last hour
SELECT 
    p.full_name,
    p.role,
    COUNT(*) as location_updates,
    MAX(lh.recorded_at) as latest_update
FROM location_history lh
JOIN profiles p ON lh.user_id = p.id
WHERE lh.recorded_at > NOW() - INTERVAL '1 hour'
    AND p.role = 'agent'
GROUP BY lh.user_id, p.full_name, p.role
ORDER BY location_updates DESC;

-- Check if active_agents table exists, if so show its data
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'active_agents' AND table_schema = 'public') THEN
        RAISE NOTICE 'Active agents table exists, showing data...';
        PERFORM * FROM active_agents LIMIT 1;
    ELSE
        RAISE NOTICE 'Active agents table does not exist in this database';
    END IF;
END $$;
EOF < /dev/null