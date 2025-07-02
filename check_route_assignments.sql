-- Check route assignments and assigned agents
-- This will help diagnose why assigned agents list is empty

-- 1. Check all route assignments
SELECT 
    ra.id,
    ra.route_id,
    ra.agent_id,
    ra.status,
    ra.assigned_at,
    ra.assigned_by,
    r.name as route_name,
    p.full_name as agent_name,
    p.email as agent_email
FROM route_assignments ra
LEFT JOIN routes r ON ra.route_id = r.id
LEFT JOIN profiles p ON ra.agent_id = p.id
ORDER BY ra.assigned_at DESC;

-- 2. Check route assignments with the exact query structure used in Flutter
SELECT 
    ra.id, 
    ra.status, 
    ra.assigned_at, 
    ra.started_at, 
    ra.completed_at,
    ra.agent_id,
    p.id as profile_id,
    p.full_name,
    p.email
FROM route_assignments ra
LEFT JOIN profiles p ON ra.agent_id = p.id
ORDER BY ra.assigned_at DESC;

-- 3. Check if profiles table has the correct foreign key relationship
SELECT 
    constraint_name,
    table_name,
    column_name,
    foreign_table_name,
    foreign_column_name
FROM information_schema.key_column_usage
WHERE table_name = 'route_assignments' 
AND constraint_name LIKE '%fkey%';

-- 4. Check specific route assignments for a route (replace with actual route ID)
SELECT 
    ra.*,
    p.full_name as agent_name
FROM route_assignments ra
LEFT JOIN profiles p ON ra.agent_id = p.id
WHERE ra.route_id = (SELECT id FROM routes ORDER BY created_at DESC LIMIT 1);

-- 5. Debug: Check if agent_id in route_assignments matches id in profiles
SELECT 
    ra.agent_id,
    p.id as profile_id,
    CASE WHEN p.id IS NULL THEN 'NO PROFILE FOUND' ELSE 'Profile exists' END as status
FROM route_assignments ra
LEFT JOIN profiles p ON ra.agent_id = p.id;

-- 6. Count assignments by route
SELECT 
    r.id,
    r.name,
    COUNT(ra.id) as assigned_agents_count
FROM routes r
LEFT JOIN route_assignments ra ON r.id = ra.route_id
GROUP BY r.id, r.name
ORDER BY r.created_at DESC;