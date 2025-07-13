INSERT INTO touring_task_assignments (
    touring_task_id,
    agent_id,
    assigned_by,
    status
) VALUES (
    (SELECT id FROM touring_tasks ORDER BY created_at DESC LIMIT 1),
    (SELECT id FROM profiles WHERE email = 'user.agent2@test.com'),
    (SELECT id FROM profiles WHERE role IN ('admin', 'manager') LIMIT 1),
    'assigned'
);

SELECT 
    tta.id as assignment_id,
    tt.title as task_title,
    tt.required_time_minutes,
    cg.name as geofence_name,
    p.full_name as agent_name,
    p.email as agent_email,
    tta.status
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN campaign_geofences cg ON tt.geofence_id = cg.id
JOIN profiles p ON tta.agent_id = p.id
WHERE p.email = 'user.agent2@test.com';