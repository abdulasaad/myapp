-- Check for completed touring tasks
SELECT 
    tta.id,
    tta.status,
    tta.completed_at,
    tt.title as task_name,
    tt.points,
    p.full_name as agent_name,
    p.id as agent_id
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
WHERE tta.status = 'completed'
ORDER BY tta.completed_at DESC;

-- Check earnings for all agents with touring tasks
SELECT 
    tta.agent_id,
    p.full_name as agent_name,
    SUM(tt.points) as touring_points
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
WHERE tta.status = 'completed'
GROUP BY tta.agent_id, p.full_name;