-- Check location_history table structure and recent data
-- This will help us understand the timestamp discrepancy

-- 1. Check the location_history table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'location_history'
ORDER BY ordinal_position;

-- 2. Check recent location updates to see timestamp differences
SELECT 
    user_id,
    recorded_at,
    created_at,
    accuracy,
    EXTRACT(EPOCH FROM (NOW() - recorded_at)) as seconds_since_recorded,
    EXTRACT(EPOCH FROM (NOW() - created_at)) as seconds_since_created,
    CASE 
        WHEN recorded_at > NOW() THEN 'FUTURE TIMESTAMP!'
        ELSE 'OK'
    END as timestamp_check
FROM location_history
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 20;

-- 3. Check the RPC function definition (if it exists)
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'get_agents_with_last_location'
AND routine_schema = 'public';

-- 4. If the function doesn't exist, here's what it should look like
-- This function should use recorded_at, not created_at
/*
CREATE OR REPLACE FUNCTION get_agents_with_last_location()
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    last_location TEXT,
    last_seen TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (p.id)
        p.id,
        p.full_name,
        ST_AsText(lh.location) as last_location,
        lh.recorded_at as last_seen  -- IMPORTANT: Use recorded_at, not created_at
    FROM profiles p
    LEFT JOIN location_history lh ON p.id = lh.user_id
    WHERE p.role = 'agent'
    ORDER BY p.id, lh.recorded_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/