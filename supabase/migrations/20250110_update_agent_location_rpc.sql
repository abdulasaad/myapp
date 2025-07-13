-- Drop the existing function first to avoid return type conflicts
DROP FUNCTION IF EXISTS get_agents_with_last_location();

-- Create the updated get_agents_with_last_location function to include status information
CREATE OR REPLACE FUNCTION get_agents_with_last_location()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  role TEXT,
  status TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if active_agents table exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') THEN
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.status,
      p.connection_status,
      p.last_heartbeat,
      aa.last_location::TEXT,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST,
      aa.last_seen DESC NULLS LAST;
  ELSE
    -- Fallback when active_agents table doesn't exist
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.status,
      p.connection_status,
      p.last_heartbeat,
      NULL::TEXT as last_location,
      NULL::TIMESTAMP WITH TIME ZONE as last_seen
    FROM profiles p
    WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST;
  END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;