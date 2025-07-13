-- Fix managers appearing in agent lists
-- Update functions to only return agents where appropriate

-- 1. Fix the live map function to only show agents (not managers)
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
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.username,
    p.role,
    p.status,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'offline'
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
      ELSE 'offline'
    END as connection_status,
    p.last_heartbeat,
    CASE 
      WHEN aa.last_location IS NOT NULL THEN 
        'POINT(' || aa.last_location[0] || ' ' || aa.last_location[1] || ')'
      ELSE NULL
    END as last_location,
    aa.last_seen
  FROM profiles p
  LEFT JOIN active_agents aa ON aa.user_id = p.id
  WHERE p.status = 'active' 
    AND p.role = 'agent'  -- ONLY AGENTS, NOT MANAGERS
    AND p.last_heartbeat IS NOT NULL
    AND p.last_heartbeat > NOW() - INTERVAL '24 hours'
  ORDER BY 
    CASE 
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
      ELSE 3
    END,
    p.last_heartbeat DESC NULLS LAST,
    aa.last_seen DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;

-- 2. Check if there are other functions that might be returning managers in agent lists
-- Let's find all functions that might be used for agent listing
SELECT 
  routine_name,
  routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_type = 'FUNCTION'
  AND (
    routine_name ILIKE '%agent%' 
    OR routine_definition ILIKE '%role%agent%'
    OR routine_definition ILIKE '%IN (''agent'', ''manager'')%'
  )
ORDER BY routine_name;

-- 3. Update debug function to show the difference
DROP FUNCTION IF EXISTS debug_location_updates();

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
  WHERE p.status = 'active' 
    AND p.role = 'agent'  -- ONLY AGENTS FOR DEBUGGING
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

-- 4. Test the fix - should only show agents now
SELECT id, full_name, role, connection_status 
FROM get_agents_with_last_location()
ORDER BY full_name;