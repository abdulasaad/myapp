SELECT COUNT(*) as campaign_count FROM campaigns;
SELECT COUNT(*) as geofence_count FROM campaign_geofences;
SELECT COUNT(*) as touring_task_count FROM touring_tasks;

SELECT 
    c.id as campaign_id,
    c.name as campaign_name,
    cg.id as geofence_id,
    cg.name as geofence_name
FROM campaigns c
LEFT JOIN campaign_geofences cg ON c.id = cg.campaign_id
LIMIT 5;