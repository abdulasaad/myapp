INSERT INTO touring_task_assignments (
    touring_task_id,
    agent_id,
    assigned_by,
    status
) 
SELECT 
    (SELECT id FROM touring_tasks ORDER BY created_at DESC LIMIT 1) as touring_task_id,
    (SELECT id FROM profiles WHERE role = 'agent' LIMIT 1) as agent_id,
    (SELECT id FROM profiles WHERE role IN ('admin', 'manager') LIMIT 1) as assigned_by,
    'assigned' as status;

SELECT 
    tta.id as assignment_id,
    tt.title as task_title,
    p.full_name as agent_name,
    tta.status
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id;