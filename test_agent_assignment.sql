SELECT 
    tta.id as assignment_id,
    tt.title as task_title,
    tt.required_time_minutes,
    cg.name as geofence_name,
    p.full_name as agent_name,
    p.id as agent_id,
    tta.status as assignment_status
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN campaign_geofences cg ON tt.geofence_id = cg.id
JOIN profiles p ON tta.agent_id = p.id
ORDER BY tta.assigned_at DESC;