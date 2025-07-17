-- 1. Check the geofence function output
SELECT * FROM get_all_geofences_wkt();

-- 2. Check campaign_geofences table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'campaign_geofences'
ORDER BY ordinal_position;

-- 3. Check raw geofence data
SELECT 
    id,
    name,
    area_text,
    color,
    is_active,
    campaign_id,
    created_at
FROM campaign_geofences
WHERE is_active = true;

-- 4. Check if area_text contains valid WKT
SELECT 
    id,
    name,
    LEFT(area_text, 100) as area_preview,
    LENGTH(area_text) as area_length,
    CASE 
        WHEN area_text IS NULL THEN 'NULL'
        WHEN area_text = '' THEN 'EMPTY'
        WHEN area_text LIKE 'POLYGON%' THEN 'VALID WKT'
        ELSE 'INVALID FORMAT'
    END as wkt_status
FROM campaign_geofences
WHERE is_active = true;

-- 5. Check campaigns linked to geofences
SELECT 
    c.id as campaign_id,
    c.name as campaign_name,
    COUNT(cg.id) as geofence_count
FROM campaigns c
LEFT JOIN campaign_geofences cg ON c.id = cg.campaign_id
WHERE cg.is_active = true
GROUP BY c.id, c.name;

-- 6. Check touring tasks linked to geofences
SELECT 
    tt.id,
    tt.title,
    tt.geofence_id,
    cg.name as geofence_name,
    tt.status
FROM touring_tasks tt
LEFT JOIN campaign_geofences cg ON tt.geofence_id = cg.id
WHERE tt.status = 'active';

-- 7. Verify the function definition
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'get_all_geofences_wkt';