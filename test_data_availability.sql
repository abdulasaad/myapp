SELECT COUNT(*) as campaign_count FROM campaigns;
SELECT COUNT(*) as geofence_count FROM campaign_geofences;
SELECT COUNT(*) as touring_task_count FROM touring_tasks;

SELECT 
    c.id as campaign_id,
    c.name as campaign_name,
    COUNT(cg.id) as geofence_count
FROM campaigns c
LEFT JOIN campaign_geofences cg ON c.id = cg.campaign_id
GROUP BY c.id, c.name
LIMIT 5;

SELECT 
    cg.id as geofence_id,
    cg.name as geofence_name,
    cg.campaign_id,
    CASE WHEN cg.area_text IS NOT NULL THEN 'HAS_AREA' ELSE 'NO_AREA' END as area_status
FROM campaign_geofences cg
LIMIT 5;