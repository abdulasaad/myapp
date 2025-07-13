-- Final fix for heartbeat function - single parameter version
-- This creates a simplified heartbeat function that only takes user_id

DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID);

CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;

-- Update the get_agents_with_last_location function to use heartbeat-based status
DROP FUNCTION IF EXISTS get_agents_with_last_location();

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
      -- Determine connection status based on heartbeat
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 'offline'
        WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'active'
        WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'away'
        ELSE 'offline'
      END as connection_status,
      p.last_heartbeat,
      aa.last_location::TEXT,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
    ORDER BY 
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 4
        WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 1
        WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 2
        ELSE 3
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
      -- Determine connection status based on heartbeat
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 'offline'
        WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'active'
        WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'away'
        ELSE 'offline'
      END as connection_status,
      p.last_heartbeat,
      NULL::TEXT as last_location,
      NULL::TIMESTAMP WITH TIME ZONE as last_seen
    FROM profiles p
    WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
    ORDER BY 
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 4
        WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 1
        WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 2
        ELSE 3
      END,
      p.last_heartbeat DESC NULLS LAST;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;

-- Create a debug function to check heartbeat status
CREATE OR REPLACE FUNCTION debug_heartbeat_status()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  role TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  minutes_since_heartbeat NUMERIC,
  calculated_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.role,
    p.last_heartbeat,
    EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) / 60 as minutes_since_heartbeat,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'offline'
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'active'
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'away'
      ELSE 'offline'
    END as calculated_status
  FROM profiles p
  WHERE p.status = 'active'
  ORDER BY p.last_heartbeat DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_heartbeat_status TO authenticated;