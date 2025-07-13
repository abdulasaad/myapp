-- Debug why managers can't see agents in their groups

-- 1. Check all group memberships
SELECT 
  ug.group_id,
  g.name as group_name,
  p.id as user_id,
  p.full_name,
  p.role,
  p.status,
  p.last_heartbeat,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'NEVER_LOGGED_IN'
    WHEN NOW() - p.last_heartbeat < INTERVAL '1 hour' THEN 'RECENT_HEARTBEAT' 
    ELSE 'OLD_HEARTBEAT'
  END as heartbeat_status
FROM user_groups ug
JOIN groups g ON ug.group_id = g.id
JOIN profiles p ON ug.user_id = p.id
WHERE p.status = 'active'
ORDER BY g.name, p.role, p.full_name;

-- 2. Check what get_agents_with_last_location returns now
SELECT id, full_name, role, connection_status, last_heartbeat
FROM get_agents_with_last_location()
ORDER BY full_name;

-- 3. Check which agents have heartbeats vs which are in groups
SELECT 
  p.id,
  p.full_name,
  p.role,
  p.status,
  p.last_heartbeat,
  CASE WHEN ug.user_id IS NOT NULL THEN 'IN_GROUP' ELSE 'NOT_IN_GROUP' END as group_status,
  CASE 
    WHEN p.last_heartbeat IS NULL THEN 'NO_HEARTBEAT'
    WHEN NOW() - p.last_heartbeat < INTERVAL '24 hours' THEN 'HAS_RECENT_HEARTBEAT'
    ELSE 'OLD_HEARTBEAT'
  END as heartbeat_status
FROM profiles p
LEFT JOIN user_groups ug ON p.id = ug.user_id
WHERE p.status = 'active' AND p.role = 'agent'
ORDER BY heartbeat_status, group_status, p.full_name;

-- 4. Check specific manager's groups (Mostafa)
SELECT 
  'Manager Groups:' as info,
  ug.group_id,
  g.name as group_name
FROM user_groups ug
JOIN groups g ON ug.group_id = g.id
JOIN profiles p ON ug.user_id = p.id
WHERE p.full_name = 'Mostafa' AND p.role = 'manager';

-- 5. Check agents in Mostafa's groups
SELECT 
  'Agents in Mostafas Groups:' as info,
  p.id,
  p.full_name,
  p.role,
  p.last_heartbeat,
  g.name as group_name
FROM user_groups ug_manager
JOIN user_groups ug_agent ON ug_manager.group_id = ug_agent.group_id
JOIN profiles p ON ug_agent.user_id = p.id
JOIN groups g ON ug_manager.group_id = g.id
JOIN profiles manager ON ug_manager.user_id = manager.id
WHERE manager.full_name = 'Mostafa' 
  AND manager.role = 'manager'
  AND p.role = 'agent'
  AND p.status = 'active'
ORDER BY p.full_name;