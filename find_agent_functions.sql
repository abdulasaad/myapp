-- Find all functions that might be showing managers as agents

-- 1. List all functions that contain 'agent' in name or definition
SELECT 
  routine_name,
  routine_type,
  CASE 
    WHEN LENGTH(routine_definition) > 200 THEN 
      LEFT(routine_definition, 200) || '...'
    ELSE routine_definition
  END as routine_definition_preview
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND (
    routine_name ILIKE '%agent%' 
    OR routine_definition ILIKE '%agent%'
  )
ORDER BY routine_name;

-- 2. Check specifically for functions used in Flutter app
-- These are the most likely candidates for team/agent listings
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN (
    'get_agents_with_last_location',
    'get_assigned_agents', 
    'get_team_members',
    'get_group_agents',
    'get_active_agents',
    'get_agent_progress_for_campaign',
    'get_agent_tasks_for_campaign'
  );

-- 3. Test the current live map function to see if it's fixed
SELECT id, full_name, role, connection_status 
FROM get_agents_with_last_location()
ORDER BY full_name;