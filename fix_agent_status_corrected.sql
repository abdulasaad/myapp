-- Fix for agent status showing "active" when offline - Corrected for actual schema
-- Based on actual database inspection showing location_history table structure

-- Step 1: Check the current get_agents_with_last_location function
SELECT routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'get_agents_with_last_location';

-- Step 2: Fix future timestamps (82 records found with future dates)
-- Since there's no created_at column, we'll set future timestamps to NOW()
UPDATE location_history
SET recorded_at = NOW()
WHERE recorded_at > NOW() + INTERVAL '5 minutes';

-- Step 3: Verify the fix worked
SELECT 
    COUNT(*) as total_rows,
    COUNT(CASE WHEN recorded_at > NOW() + INTERVAL '1 minute' THEN 1 END) as remaining_future_timestamps
FROM location_history;

-- Step 4: Create/update the RPC function to ensure it uses recorded_at properly
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
        CASE 
            WHEN lh.location IS NOT NULL THEN ST_AsText(lh.location::geometry)
            ELSE NULL
        END as last_location,
        lh.recorded_at as last_seen  -- Ensure we use recorded_at
    FROM profiles p
    LEFT JOIN LATERAL (
        SELECT location, recorded_at
        FROM location_history
        WHERE user_id = p.id
        ORDER BY recorded_at DESC
        LIMIT 1
    ) lh ON true
    WHERE p.role = 'agent'
    ORDER BY p.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Add constraint to prevent future timestamps (after fixing existing ones)
ALTER TABLE location_history 
ADD CONSTRAINT check_recorded_at_not_future 
CHECK (recorded_at <= NOW() + INTERVAL '5 minutes');

-- Step 6: Create optimized index for agent location queries
CREATE INDEX IF NOT EXISTS idx_location_history_user_recorded 
ON location_history(user_id, recorded_at DESC);

-- Step 7: Grant permissions
GRANT EXECUTE ON FUNCTION get_agents_with_last_location() TO authenticated;

-- Step 8: Test the function works correctly
SELECT 
    id,
    full_name,
    last_location,
    last_seen,
    EXTRACT(EPOCH FROM (NOW() - last_seen)) as seconds_ago,
    CASE 
        WHEN last_seen IS NULL THEN 'Offline'
        WHEN EXTRACT(EPOCH FROM (NOW() - last_seen)) <= 45 THEN 'Active'
        WHEN EXTRACT(EPOCH FROM (NOW() - last_seen)) < 900 THEN 'Away'
        ELSE 'Offline'
    END as calculated_status
FROM get_agents_with_last_location()
ORDER BY last_seen DESC NULLS LAST
LIMIT 10;