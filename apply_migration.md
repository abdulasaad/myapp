# Apply Database Migration for Team Member Details

## Current Status
The database functions `get_agents_in_manager_groups` and `get_all_agents_for_admin` are missing the `email` and `created_at` fields that the team members screen needs.

## Migration File
The migration file has been created at:
`/Users/abdullahsaad/AL-Tijwal/myapp/myapp/supabase/migrations/20250710_235803_fix_team_member_details.sql`

## How to Apply the Migration

### Option 1: Using Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/jnuzpixgfskjcoqmgkxb/sql/new
2. Copy the contents of the migration file
3. Execute the SQL in the SQL editor

### Option 2: Using Supabase CLI (if you have the database password)
```bash
supabase db push --linked
```

### Option 3: Direct SQL execution
Copy and paste the following SQL into the Supabase SQL editor:

```sql
-- Fix team member details by adding missing fields to database functions
-- This adds email and created_at fields that the team members screen needs

-- 1. Update function for managers to include email and created_at
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
    p.email,
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

-- 2. Update function for admins to include email and created_at
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
    p.email,
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
```

## Verification
After applying the migration, you can test the updated functions with these queries:

```sql
-- Test manager function
SELECT id, full_name, email, username, created_at, group_name 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
ORDER BY full_name;

-- Test admin function  
SELECT id, full_name, email, username, created_at
FROM get_all_agents_for_admin()
ORDER BY full_name;
```