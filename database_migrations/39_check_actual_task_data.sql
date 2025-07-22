-- Check if tasks and task assignments actually exist for the agent
-- Run as ADMIN to see the real data

-- 1. Check if tasks exist for agent's campaigns
SELECT 'Tasks in agent campaigns (admin view):' as info;
SELECT 
    c.name as campaign_name,
    c.id as campaign_id,
    t.id as task_id,
    t.title,
    ca.agent_id
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
LEFT JOIN tasks t ON t.campaign_id = c.id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali's ID
ORDER BY c.name, t.title;

-- 2. Check if task assignments exist for this agent
SELECT 'Task assignments for agent (admin view):' as info;
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    t.title as task_title,
    c.name as campaign_name
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
JOIN campaigns c ON c.id = t.campaign_id
WHERE ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali's ID
ORDER BY c.name, t.title;

-- 3. Check total counts
SELECT 'Data summary:' as info;
SELECT 
    COUNT(DISTINCT c.id) as campaigns_assigned,
    COUNT(DISTINCT t.id) as tasks_in_campaigns,
    COUNT(DISTINCT ta.id) as task_assignments
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
LEFT JOIN tasks t ON t.campaign_id = c.id
LEFT JOIN task_assignments ta ON ta.task_id = t.id AND ta.agent_id = ca.agent_id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 4. If no tasks exist, let's create a test task for the agent
-- This might be why the agent's campaign tab is showing an error
INSERT INTO tasks (
    campaign_id,
    title,
    description,
    points,
    status,
    start_date,
    end_date,
    required_evidence_count,
    enforce_geofence,
    created_by
) 
SELECT 
    c.id,
    'Test Task for ' || c.name,
    'A test task to verify agent access',
    10,
    'active',
    NOW(),
    NOW() + INTERVAL '7 days',
    1,
    true,
    c.created_by
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND NOT EXISTS (
    SELECT 1 FROM tasks t WHERE t.campaign_id = c.id
)
RETURNING id, title, campaign_id;

-- 5. Create task assignments if tasks exist but no assignments
INSERT INTO task_assignments (task_id, agent_id, assigned_by, status)
SELECT 
    t.id,
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1',
    t.created_by,
    'assigned'
FROM tasks t
JOIN campaigns c ON c.id = t.campaign_id
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND NOT EXISTS (
    SELECT 1 FROM task_assignments ta 
    WHERE ta.task_id = t.id 
    AND ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
)
RETURNING id, task_id, agent_id;