SELECT COUNT(*) as campaign_count FROM campaigns;
SELECT COUNT(*) as geofence_count FROM campaign_geofences;

SELECT 
    c.id as campaign_id,
    c.name as campaign_name
FROM campaigns c
LIMIT 3;

SELECT 
    cg.id as geofence_id,
    cg.name as geofence_name,
    cg.campaign_id
FROM campaign_geofences cg
LIMIT 3;