-- Fix for agent status showing "active" when they're actually offline
-- The issue: The RPC function might be using wrong timestamp field

-- Step 1: Create or replace the RPC function to use recorded_at instead of created_at
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
        lh.recorded_at as last_seen  -- Use recorded_at, not created_at
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

-- Step 2: Fix any existing future timestamps FIRST
UPDATE location_history
SET recorded_at = CASE 
    WHEN created_at IS NOT NULL AND created_at <= NOW() THEN created_at
    ELSE NOW()
END
WHERE recorded_at > NOW() + INTERVAL '5 minutes';

-- Step 3: Now add the constraint to prevent future timestamps
ALTER TABLE location_history 
ADD CONSTRAINT check_recorded_at_not_future 
CHECK (recorded_at <= NOW() + INTERVAL '5 minutes');

-- Step 4: Create an index for better performance
CREATE INDEX IF NOT EXISTS idx_location_history_user_recorded 
ON location_history(user_id, recorded_at DESC);

-- Step 5: Grant execute permission
GRANT EXECUTE ON FUNCTION get_agents_with_last_location() TO authenticated;

-- Step 6: Add a helper function to get agent status directly
CREATE OR REPLACE FUNCTION get_agent_status(agent_id UUID)
RETURNS TEXT AS $$
DECLARE
    last_update TIMESTAMP WITH TIME ZONE;
    time_diff INTERVAL;
BEGIN
    SELECT recorded_at INTO last_update
    FROM location_history
    WHERE user_id = agent_id
    ORDER BY recorded_at DESC
    LIMIT 1;
    
    IF last_update IS NULL THEN
        RETURN 'Offline';
    END IF;
    
    time_diff := NOW() - last_update;
    
    IF time_diff <= INTERVAL '45 seconds' THEN
        RETURN 'Active';
    ELSIF time_diff < INTERVAL '15 minutes' THEN
        RETURN 'Away';
    ELSE
        RETURN 'Offline';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_agent_status(UUID) TO authenticated;