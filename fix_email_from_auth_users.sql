-- Fix email issue by getting it from auth.users table
-- Supabase stores emails in auth.users, not in profiles table

-- 1. Update function for managers to get email from auth.users
CREATE OR REPLACE FUNCTION get_agents_in_manager_groups(manager_user_id UUID)
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
    COALESCE(u.email, p.email) as email,  -- Try auth.users first, then profiles
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
  LEFT JOIN auth.users u ON p.id = u.id  -- Join with auth.users to get email
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

-- 2. Update function for admins to get email from auth.users
CREATE OR REPLACE FUNCTION get_all_agents_for_admin()
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
    COALESCE(u.email, p.email) as email,  -- Try auth.users first, then profiles
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
  LEFT JOIN auth.users u ON p.id = u.id  -- Join with auth.users to get email
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

-- 3. Test the updated functions to verify email is now included
SELECT 'Testing email retrieval from auth.users' as info;
SELECT id, full_name, email, username, group_name 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
ORDER BY full_name;