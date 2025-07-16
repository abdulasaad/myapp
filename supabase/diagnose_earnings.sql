-- Diagnostic queries to find the actual data
-- Run these in your Supabase SQL Editor

-- 1. Find all tasks with "test" in the name
SELECT id, title, points, campaign_id, status, created_at
FROM tasks 
WHERE title ILIKE '%test%'
ORDER BY created_at DESC;

-- 2. Find all task assignments regardless of status
SELECT 
    ta.id,
    ta.status,
    ta.created_at,
    ta.completed_at,
    t.title as task_name,
    p.full_name as agent_name,
    c.name as campaign_name
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
LEFT JOIN campaigns c ON t.campaign_id = c.id
ORDER BY ta.created_at DESC
LIMIT 10;

-- 3. Check touring task assignments
SELECT 
    tta.id,
    tta.status,
    tta.created_at,
    tta.completed_at,
    tt.title as task_name,
    p.full_name as agent_name,
    c.name as campaign_name
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
LEFT JOIN campaigns c ON tt.campaign_id = c.id
ORDER BY tta.created_at DESC
LIMIT 10;

-- 4. Check what's in campaign_agents table
SELECT 
    ca.*,
    p.full_name as agent_name,
    c.name as campaign_name
FROM campaign_agents ca
JOIN profiles p ON ca.agent_id = p.id
JOIN campaigns c ON ca.campaign_id = c.id
ORDER BY ca.assigned_at DESC;

-- 5. Check all campaigns
SELECT id, name, start_date, end_date, created_at
FROM campaigns
ORDER BY created_at DESC;

-- 6. Check all agents (profiles)
SELECT id, full_name, role, created_at
FROM profiles
WHERE role = 'agent'
ORDER BY created_at DESC;

-- 7. Check for completed tasks specifically
SELECT 
    ta.id,
    ta.status,
    ta.created_at,
    ta.completed_at,
    t.title as task_name,
    t.points,
    p.full_name as agent_name
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
WHERE ta.status = 'completed'
ORDER BY ta.completed_at DESC;