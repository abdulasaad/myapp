SELECT COUNT(*) as touring_task_count FROM touring_tasks;
SELECT COUNT(*) as assignment_count FROM touring_task_assignments;
SELECT COUNT(*) as agent_count FROM profiles WHERE role = 'agent';

SELECT 
    id as task_id,
    title,
    campaign_id,
    geofence_id,
    status
FROM touring_tasks
ORDER BY created_at DESC
LIMIT 3;

SELECT 
    id as agent_id,
    full_name,
    role
FROM profiles 
WHERE role = 'agent'
LIMIT 3;