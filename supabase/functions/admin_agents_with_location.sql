-- Create RPC function for admin to get all agents with location data
-- This function runs with SECURITY DEFINER to bypass RLS policies

CREATE OR REPLACE FUNCTION get_all_agents_with_location_for_admin(requesting_user_id UUID)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    role TEXT,
    status TEXT,
    last_heartbeat TIMESTAMP WITH TIME ZONE,
    last_location TEXT,
    last_seen TIMESTAMP WITH TIME ZONE,
    connection_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Check if the requesting user is an admin
    SELECT p.role INTO user_role
    FROM profiles p
    WHERE p.id = requesting_user_id;
    
    -- Only allow admin users to access this function
    IF user_role != 'admin' THEN
        RETURN;
    END IF;
    
    -- Return all agents with their location data
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        p.role,
        p.status,
        p.last_heartbeat,
        COALESCE(
            CASE 
                WHEN lh.latitude IS NOT NULL AND lh.longitude IS NOT NULL 
                THEN 'POINT(' || lh.longitude || ' ' || lh.latitude || ')'
                ELSE aa.last_location::TEXT
            END
        ) as last_location,
        COALESCE(lh.recorded_at, aa.last_seen) as last_seen,
        CASE 
            WHEN p.last_heartbeat IS NULL THEN 'offline'
            WHEN EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) < 45 THEN 'active'
            WHEN EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) < 600 THEN 'away'
            ELSE 'offline'
        END as connection_status
    FROM profiles p
    LEFT JOIN LATERAL (
        SELECT latitude, longitude, recorded_at
        FROM location_history lh_sub
        WHERE lh_sub.user_id = p.id
        ORDER BY lh_sub.recorded_at DESC
        LIMIT 1
    ) lh ON true
    LEFT JOIN active_agents aa ON aa.agent_id = p.id
    WHERE p.role = 'agent'
    ORDER BY p.full_name;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_agents_with_location_for_admin(UUID) TO authenticated;