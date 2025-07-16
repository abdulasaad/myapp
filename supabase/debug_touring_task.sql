-- Debug touring task status
-- Check all touring tasks named "test"
SELECT 
    tt.id,
    tt.title,
    tt.points,
    tt.campaign_id,
    tt.status as task_status
FROM touring_tasks tt
WHERE tt.title ILIKE '%test%'
ORDER BY tt.created_at DESC;

-- Check all touring task assignments for "test" task
SELECT 
    tta.id,
    tta.status,
    tta.assigned_at,
    tta.completed_at,
    tt.title as task_name,
    tt.points,
    p.full_name as agent_name,
    p.id as agent_id
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
WHERE tt.title ILIKE '%test%'
ORDER BY tta.assigned_at DESC;

-- Check if there are any completed touring tasks at all
SELECT 
    tta.id,
    tta.status,
    tta.assigned_at,
    tta.completed_at,
    tt.title as task_name,
    p.full_name as agent_name
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
ORDER BY tta.assigned_at DESC
LIMIT 10;