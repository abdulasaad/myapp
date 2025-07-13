-- COMPLETE FIX: Apply both database functions and test

-- 1. Create function to get agents by group (includes agents without heartbeats)
CREATE OR REPLACE FUNCTION get_agents_in_manager_groups(manager_user_id UUID)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  role TEXT,
  status TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE,
  group_name TEXT
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
    -- Determine connection status based on heartbeat
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
    aa.last_seen,
    g.name as group_name
  FROM profiles p
  LEFT JOIN active_agents aa ON aa.user_id = p.id
  -- Join through group membership
  JOIN user_groups ug_agent ON ug_agent.user_id = p.id
  JOIN user_groups ug_manager ON ug_manager.group_id = ug_agent.group_id
  JOIN groups g ON g.id = ug_agent.group_id
  WHERE ug_manager.user_id = manager_user_id  -- Manager must be in the same group
    AND p.status = 'active' 
    AND p.role = 'agent'  -- Only agents, not managers
  ORDER BY 
    CASE 
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
      ELSE 3
    END,
    p.last_heartbeat DESC NULLS LAST,
    aa.last_seen DESC NULLS LAST,
    p.full_name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_agents_in_manager_groups TO authenticated;

-- 2. Create function for admins to see all agents (with or without heartbeats)
CREATE OR REPLACE FUNCTION get_all_agents_for_admin()
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
    -- Determine connection status based on heartbeat
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
    AND p.role = 'agent'  -- Only agents
  ORDER BY 
    CASE 
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
      ELSE 3
    END,
    p.last_heartbeat DESC NULLS LAST,
    aa.last_seen DESC NULLS LAST,
    p.full_name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_agents_for_admin TO authenticated;

-- 3. Test the new functions with Mostafa (manager)
SELECT 'TEST: Agents in Mostafas groups' as test_info;
SELECT id, full_name, connection_status, last_heartbeat, group_name 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
ORDER BY connection_status, full_name;

-- 4. Test admin function
SELECT 'TEST: All agents for admin' as test_info;
SELECT id, full_name, connection_status, last_heartbeat 
FROM get_all_agents_for_admin()
ORDER BY connection_status, full_name;

-- 5. Compare with original function (should show fewer results)
SELECT 'TEST: Original function (only with heartbeats)' as test_info;
SELECT id, full_name, connection_status, last_heartbeat 
FROM get_agents_with_last_location()
ORDER BY connection_status, full_name;