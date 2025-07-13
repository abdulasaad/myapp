SELECT 
    tta.*,
    tt.title,
    tt.required_time_minutes,
    tt.movement_timeout_seconds,
    tt.min_movement_threshold,
    tt.points,
    cg.id as geofence_id,
    cg.name as geofence_name,
    cg.area_text,
    cg.color
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN campaign_geofences cg ON tt.geofence_id = cg.id
WHERE tta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND tta.status = 'assigned';