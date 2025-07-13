-- Update the status determination to be based on last_heartbeat instead of connection_status
-- This way, the status is determined by when the last heartbeat was received, not by the app's local state

-- First update the heartbeat function to ignore the status parameter
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);

CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_user_id UUID,
  p_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Ignore the status parameter - we determine status from heartbeat timestamp
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;

-- Drop and recreate the user_status_view to use heartbeat-based status
DROP VIEW IF EXISTS user_status_view;

CREATE OR REPLACE VIEW user_status_view AS
SELECT 
  p.id,
  p.full_name,
  p.username,
  p.role,
  -- Determine status based on last heartbeat time
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'offline'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'active'
    WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'away'
    ELSE 'offline'
  END as connection_status,
  p.last_heartbeat,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'Offline'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'Online'
    WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'Away'
    ELSE 'Offline'
  END as status_display,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'Never'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'Just now'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 hour' THEN 
      CONCAT(EXTRACT(MINUTE FROM NOW() - p.last_heartbeat)::INT, ' minutes ago')
    WHEN NOW() - p.last_heartbeat < INTERVAL '24 hours' THEN 
      CONCAT(EXTRACT(HOUR FROM NOW() - p.last_heartbeat)::INT, ' hours ago')
    ELSE 
      CONCAT(EXTRACT(DAY FROM NOW() - p.last_heartbeat)::INT, ' days ago')
  END as last_seen_text,
  CASE 
    WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') 
    THEN aa.last_location
    ELSE NULL
  END as last_location,
  CASE 
    WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') 
    THEN aa.last_seen
    ELSE NULL
  END as location_last_seen
FROM profiles p
LEFT JOIN (
  SELECT * FROM active_agents 
  WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents')
) aa ON aa.user_id = p.id
WHERE p.status = 'active';

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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;

-- Create a function to get the real-time status based on heartbeat
CREATE OR REPLACE FUNCTION get_user_realtime_status(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_last_heartbeat TIMESTAMP WITH TIME ZONE;
BEGIN
  SELECT last_heartbeat INTO v_last_heartbeat
  FROM profiles
  WHERE id = p_user_id;
  
  IF v_last_heartbeat IS NULL THEN
    RETURN 'offline';
  ELSIF NOW() - v_last_heartbeat < INTERVAL '1 minute' THEN
    RETURN 'active';
  ELSIF NOW() - v_last_heartbeat < INTERVAL '15 minutes' THEN
    RETURN 'away';
  ELSE
    RETURN 'offline';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_realtime_status TO authenticated;