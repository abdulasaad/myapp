-- Fix type mismatch by casting email to TEXT

-- 1. Drop existing function for managers
DROP FUNCTION IF EXISTS get_agents_in_manager_groups(UUID);

-- 2. Create new function for managers with proper type casting
CREATE FUNCTION get_agents_in_manager_groups(manager_user_id UUID)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  email TEXT,
  role TEXT,
  status TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
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
    COALESCE(u.email, p.email)::TEXT as email,  -- Cast to TEXT to match return type
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
    p.created_at,
    g.name as group_name
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
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

-- 3. Drop existing function for admins
DROP FUNCTION IF EXISTS get_all_agents_for_admin();

-- 4. Create new function for admins with proper type casting
CREATE FUNCTION get_all_agents_for_admin()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  email TEXT,
  role TEXT,
  status TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE
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
    COALESCE(u.email, p.email)::TEXT as email,  -- Cast to TEXT to match return type
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
    p.created_at
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
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

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION get_agents_in_manager_groups TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_agents_for_admin TO authenticated;

-- 6. Test the functions to verify email is now included
SELECT 'Testing email retrieval' as info;
SELECT id, full_name, email, username, group_name 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
ORDER BY full_name;

-- 7. Verify the email data exists in auth.users
SELECT 'Checking auth.users emails' as info;
SELECT u.id, u.email, p.full_name
FROM auth.users u
JOIN profiles p ON p.id = u.id
WHERE p.role = 'agent'
LIMIT 5;