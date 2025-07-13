SELECT 
    tt.id as task_id,
    tt.title,
    tt.required_time_minutes,
    cg.name as geofence_name
FROM touring_tasks tt
JOIN campaign_geofences cg ON tt.geofence_id = cg.id
ORDER BY tt.created_at DESC
LIMIT 1;

SELECT 
    id as agent_id,
    full_name
FROM profiles 
WHERE role = 'agent'
LIMIT 5;