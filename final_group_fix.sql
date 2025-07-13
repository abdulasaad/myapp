-- FINAL GROUP VISIBILITY FIX
-- Run this in Supabase Dashboard SQL Editor

-- 1. Function for managers to see agents in their groups
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
    aa.last_seen,
    g.name as group_name
  FROM profiles p
  LEFT JOIN active_agents aa ON aa.user_id = p.id
  JOIN user_groups ug_agent ON ug_agent.user_id = p.id
  JOIN user_groups ug_manager ON ug_manager.group_id = ug_agent.group_id
  JOIN groups g ON g.id = ug_agent.group_id
  WHERE ug_manager.user_id = manager_user_id
    AND p.status = 'active' 
    AND p.role = 'agent'
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

-- 2. Function for admins to see all agents
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
    AND p.role = 'agent'
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
GRANT EXECUTE ON FUNCTION get_all_agents_for_admin TO authenticated;

-- 3. Test Mostafa's function (should return 3 agents)
SELECT 'Mostafa should see these agents:' as test_result;
SELECT id, full_name, connection_status, group_name 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
ORDER BY full_name;