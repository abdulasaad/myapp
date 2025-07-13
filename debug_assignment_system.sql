-- Debug Assignment System - Check current database setup
-- Run these queries to understand the current state

-- 1. Check the task_assignments table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'task_assignments' 
ORDER BY ordinal_position;

-- 2. Check current task assignments and their statuses
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    ta.status,
    ta.created_at,
    ta.started_at,
    t.title as task_title,
    p.full_name as agent_name,
    p.role as agent_role
FROM task_assignments ta
LEFT JOIN tasks t ON ta.task_id = t.id
LEFT JOIN profiles p ON ta.agent_id = p.id
ORDER BY ta.created_at DESC
LIMIT 20;

-- 3. Check for pending assignments specifically
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    ta.status,
    t.title as task_title,
    p.full_name as agent_name
FROM task_assignments ta
LEFT JOIN tasks t ON ta.task_id = t.id
LEFT JOIN profiles p ON ta.agent_id = p.id
WHERE ta.status = 'pending'
ORDER BY ta.created_at DESC;

-- 4. Check RLS policies on task_assignments table
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'task_assignments';

-- 5. Check if there are triggers on task_assignments
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'task_assignments';

-- 6. Check campaign_agents table for campaign assignments
SELECT 
    ca.campaign_id,
    ca.agent_id,
    c.title as campaign_title,
    p.full_name as agent_name,
    p.role
FROM campaign_agents ca
LEFT JOIN campaigns c ON ca.campaign_id = c.id
LEFT JOIN profiles p ON ca.agent_id = p.id
ORDER BY ca.created_at DESC
LIMIT 10;

-- 7. Check tasks and their campaign associations
SELECT 
    t.id,
    t.title,
    t.campaign_id,
    c.title as campaign_title,
    t.created_by,
    p.full_name as creator_name
FROM tasks t
LEFT JOIN campaigns c ON t.campaign_id = c.id
LEFT JOIN profiles p ON t.created_by = p.id
ORDER BY t.created_at DESC
LIMIT 10;

-- 8. Check for any functions that might be controlling access
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name LIKE '%task%' 
   OR routine_name LIKE '%assignment%'
   OR routine_name LIKE '%access%'
ORDER BY routine_name;

-- 9. Look for any assignment approval or status-related functions
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_definition ILIKE '%pending%'
   OR routine_definition ILIKE '%approval%'
   OR routine_definition ILIKE '%status%'
ORDER BY routine_name;

-- 10. Check the profiles table to understand user roles
SELECT 
    id,
    full_name,
    role,
    created_at
FROM profiles 
WHERE role IN ('agent', 'manager', 'admin')
ORDER BY created_at DESC
LIMIT 10;