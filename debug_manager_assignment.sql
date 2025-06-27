-- Debug Manager Assignment Issues
-- Run these queries in Supabase SQL Editor to check the current state

-- 1. Check if assigned_manager_id column exists and has data
SELECT 
    id,
    title,
    created_by,
    assigned_manager_id,
    campaign_id,
    created_at
FROM tasks 
WHERE assigned_manager_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check all recent tasks (last 24 hours) with their assignment details
SELECT 
    t.id,
    t.title,
    t.created_by,
    t.assigned_manager_id,
    t.campaign_id,
    creator.full_name as created_by_name,
    creator.role as creator_role,
    manager.full_name as assigned_manager_name,
    manager.role as manager_role
FROM tasks t
LEFT JOIN profiles creator ON t.created_by = creator.id
LEFT JOIN profiles manager ON t.assigned_manager_id = manager.id
WHERE t.created_at > NOW() - INTERVAL '24 hours'
ORDER BY t.created_at DESC;

-- 3. Check all managers in the system
SELECT 
    id,
    full_name,
    role,
    status
FROM profiles 
WHERE role = 'manager' 
ORDER BY full_name;

-- 4. Check all standalone tasks (no campaign_id) and their assignments
SELECT 
    t.id,
    t.title,
    t.created_by,
    t.assigned_manager_id,
    t.campaign_id,
    creator.full_name as creator_name,
    creator.role as creator_role,
    manager.full_name as manager_name
FROM tasks t
LEFT JOIN profiles creator ON t.created_by = creator.id
LEFT JOIN profiles manager ON t.assigned_manager_id = manager.id
WHERE t.campaign_id IS NULL
ORDER BY t.created_at DESC
LIMIT 10;

-- 5. Check if there are any task_assignments for standalone tasks
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    ta.status,
    t.title as task_title,
    t.assigned_manager_id,
    agent.full_name as agent_name
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
LEFT JOIN profiles agent ON ta.agent_id = agent.id
WHERE t.campaign_id IS NULL
ORDER BY ta.created_at DESC
LIMIT 10;

-- 6. Check current user roles and verify manager exists
SELECT 
    'Total Users' as type, 
    COUNT(*) as count 
FROM profiles
UNION ALL
SELECT 
    'Admins' as type, 
    COUNT(*) as count 
FROM profiles WHERE role = 'admin'
UNION ALL
SELECT 
    'Managers' as type, 
    COUNT(*) as count 
FROM profiles WHERE role = 'manager'
UNION ALL
SELECT 
    'Agents' as type, 
    COUNT(*) as count 
FROM profiles WHERE role = 'agent';

-- 7. Check if assigned_manager_id column has proper foreign key constraint
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name IN ('tasks', 'campaigns')
  AND kcu.column_name LIKE '%manager%';