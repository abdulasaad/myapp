-- Debug the client campaign issue
-- Campaign ID from logs: bd5b8f5e-7e08-4c03-b73e-42626d2ad2bb

-- 1. Check the campaign details
SELECT 
    id,
    name,
    description,
    client_id,
    created_by,
    created_at
FROM campaigns 
WHERE id = 'bd5b8f5e-7e08-4c03-b73e-42626d2ad2bb';

-- 2. Check if there are any tasks for this campaign
SELECT 
    id,
    title,
    campaign_id,
    created_at
FROM tasks 
WHERE campaign_id = 'bd5b8f5e-7e08-4c03-b73e-42626d2ad2bb';

-- 3. Check task assignments for this campaign
SELECT 
    ta.id,
    ta.agent_id,
    ta.task_id,
    ta.status,
    t.title as task_title,
    t.campaign_id,
    p.full_name as agent_name
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
LEFT JOIN profiles p ON ta.agent_id = p.id
WHERE t.campaign_id = 'bd5b8f5e-7e08-4c03-b73e-42626d2ad2bb';

-- 4. Check if there are any agents in the system
SELECT 
    id,
    full_name,
    role,
    status
FROM profiles 
WHERE role = 'agent' 
AND status = 'active'
LIMIT 5;

-- 5. Check all campaigns with client assignments
SELECT 
    c.id,
    c.name,
    c.client_id,
    p.full_name as client_name
FROM campaigns c
LEFT JOIN profiles p ON c.client_id = p.id
WHERE c.client_id IS NOT NULL;