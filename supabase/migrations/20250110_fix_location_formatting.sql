-- Fix location formatting in get_agents_with_last_location function
-- The issue is that casting POINT to TEXT gives (lng,lat) format
-- but the Flutter app expects POINT(lng lat) format

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
      -- Format the location as POINT(lng lat) instead of (lng,lat)
      CASE 
        WHEN aa.last_location IS NOT NULL THEN 
          'POINT(' || aa.last_location[0] || ' ' || aa.last_location[1] || ')'
        ELSE NULL
      END as last_location,
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