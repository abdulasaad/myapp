-- Check if the geofence function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'check_point_in_geofence';

-- Test the geofence check with the touring task geofence
-- Using coordinates inside Baghdad area
SELECT check_point_in_geofence(
    33.333::double precision, 
    44.4::double precision, 
    'e555bb87-5dc1-43db-908d-765a9a992354'::uuid
) AS is_inside_geofence;

-- Check the geofence data
SELECT 
    id,
    name,
    area_text,
    ST_AsText(area) as area_geometry
FROM campaign_geofences 
WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354';