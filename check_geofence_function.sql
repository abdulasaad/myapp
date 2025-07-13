-- Check the function definition
\df check_point_in_geofence

-- Check the campaign_geofences table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'campaign_geofences'
ORDER BY ordinal_position;

-- Check the geofence data
SELECT 
    id,
    name,
    area_text,
    ST_AsText(geometry) as geometry_wkt
FROM campaign_geofences 
WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354';

-- Test with proper parameter types
SELECT check_point_in_geofence(
    33.333, 
    44.4, 
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS is_inside_geofence;