-- Test the geofence function to check the actual data
SELECT 
    geofence_id,
    geofence_name,
    LEFT(geofence_area_wkt, 100) as wkt_preview,
    geofence_type,
    geofence_color,
    campaign_name,
    touring_tasks_info,
    is_active
FROM get_all_geofences_wkt();

-- Check the raw campaign_geofences table
SELECT 
    id,
    name,
    LEFT(area_text, 100) as area_preview,
    color,
    is_active,
    campaign_id
FROM campaign_geofences 
WHERE is_active = true;

-- Check if area_text contains valid WKT data
SELECT 
    id,
    name,
    CASE 
        WHEN area_text IS NULL THEN 'NULL'
        WHEN area_text = '' THEN 'EMPTY'
        WHEN area_text LIKE 'POLYGON%' THEN 'VALID WKT'
        ELSE 'INVALID FORMAT'
    END as area_status,
    LENGTH(area_text) as area_length
FROM campaign_geofences 
WHERE is_active = true;