INSERT INTO touring_task_assignments (
    touring_task_id,
    agent_id,
    assigned_by,
    status
) VALUES (
    (SELECT id FROM touring_tasks ORDER BY created_at DESC LIMIT 1),
    'b5b6a078-8c4a-4961-83a6-5d727668b27c',
    (SELECT id FROM profiles WHERE role IN ('admin', 'manager') LIMIT 1),
    'assigned'
);

SELECT 
    tta.id as assignment_id,
    tt.title as task_title,
    tt.required_time_minutes,
    cg.name as geofence_name,
    p.full_name as agent_name,
    tta.status
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN campaign_geofences cg ON tt.geofence_id = cg.id
JOIN profiles p ON tta.agent_id = p.id
WHERE tta.agent_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c';