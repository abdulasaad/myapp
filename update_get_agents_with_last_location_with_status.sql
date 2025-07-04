-- Update the get_agents_with_last_location function to include agent status
-- This will allow the live map to show online agents in green and offline agents in red

-- First, drop the existing function
DROP FUNCTION IF EXISTS get_agents_with_last_location();

-- Recreate with the new return type including status
CREATE FUNCTION get_agents_with_last_location()
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    last_location TEXT,
    last_seen TIMESTAMP WITH TIME ZONE,
    status TEXT  -- Add status from profiles table
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        ST_AsText(lh.location) AS last_location,
        lh.recorded_at AS last_seen,
        p.status  -- Include profile status
    FROM profiles p
    LEFT JOIN LATERAL (
        SELECT 
            location,
            recorded_at
        FROM location_history
        WHERE user_id = p.id
        ORDER BY recorded_at DESC
        LIMIT 1
    ) lh ON true
    WHERE p.role = 'agent'
    ORDER BY p.full_name;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agents_with_last_location() TO authenticated;