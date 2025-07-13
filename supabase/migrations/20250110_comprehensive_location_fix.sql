-- Comprehensive fix for live map location tracking
-- 1. Filter out agents who never logged in
-- 2. Add debug function to monitor location updates
-- 3. Optimize the main function for better performance

-- Update the main function with better filtering and performance
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
      -- Determine connection status based on heartbeat (more granular timing)
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 'offline'
        WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
        WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
        ELSE 'offline'
      END as connection_status,
      p.last_heartbeat,
      -- Format the location as POINT(lng lat) - only if location exists
      CASE 
        WHEN aa.last_location IS NOT NULL THEN 
          'POINT(' || aa.last_location[0] || ' ' || aa.last_location[1] || ')'
        ELSE NULL
      END as last_location,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    WHERE p.status = 'active' 
      AND p.role IN ('agent', 'manager')
      AND p.last_heartbeat IS NOT NULL  -- Only show agents who have logged in at least once
      AND p.last_heartbeat > NOW() - INTERVAL '24 hours'  -- Only show agents active in last 24 hours
    ORDER BY 
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 4
        WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
        WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
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
        WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
        WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
        ELSE 'offline'
      END as connection_status,
      p.last_heartbeat,
      NULL::TEXT as last_location,
      NULL::TIMESTAMP WITH TIME ZONE as last_seen
    FROM profiles p
    WHERE p.status = 'active' 
      AND p.role IN ('agent', 'manager')
      AND p.last_heartbeat IS NOT NULL  -- Only show agents who have logged in at least once
      AND p.last_heartbeat > NOW() - INTERVAL '24 hours'  -- Only show agents active in last 24 hours
    ORDER BY 
      CASE 
        WHEN p.last_heartbeat IS NULL THEN 4
        WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
        WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
        ELSE 3
      END,
      p.last_heartbeat DESC NULLS LAST;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;

-- Create a debug function to monitor location update frequency
CREATE OR REPLACE FUNCTION debug_location_updates()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  role TEXT,
  heartbeat_status TEXT,
  heartbeat_age_minutes NUMERIC,
  location_status TEXT,
  location_age_minutes NUMERIC,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location_update TIMESTAMP WITH TIME ZONE
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
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'NEVER'
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as heartbeat_status,
    EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) / 60 as heartbeat_age_minutes,
    CASE 
      WHEN aa.last_seen IS NULL THEN 'NO LOCATION'
      WHEN NOW() - aa.last_seen < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - aa.last_seen < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - aa.last_seen < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as location_status,
    EXTRACT(EPOCH FROM (NOW() - aa.last_seen)) / 60 as location_age_minutes,
    p.last_heartbeat,
    aa.last_seen
  FROM profiles p
  LEFT JOIN active_agents aa ON p.id = aa.user_id
  WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
  ORDER BY 
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 3
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 0
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 1
      ELSE 2
    END,
    p.last_heartbeat DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_location_updates TO authenticated;

-- Add index for better performance on location queries
CREATE INDEX IF NOT EXISTS idx_profiles_heartbeat_status ON profiles(last_heartbeat, status, role) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_active_agents_last_seen ON active_agents(last_seen DESC, user_id);