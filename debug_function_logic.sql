-- Check the current function definition
SELECT pg_get_functiondef('check_point_in_geofence'::regproc);

-- Let's manually test the ST_Contains logic
WITH geofence AS (
    SELECT 
        id,
        name,
        geometry,
        ST_AsText(geometry) as geom_text
    FROM campaign_geofences 
    WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354'
)
SELECT 
    -- Test with center point
    ST_Contains(
        geometry, 
        ST_SetSRID(ST_Point(44.317, 33.333), 4326)
    ) as test_point_1,
    -- Test with another point
    ST_Contains(
        geometry, 
        ST_SetSRID(ST_Point(44.4, 33.3), 4326)
    ) as test_point_2,
    -- Show the geometry for debugging
    geom_text
FROM geofence;

-- Check if the geometry has proper SRID
SELECT 
    ST_SRID(geometry) as geometry_srid,
    ST_IsValid(geometry) as is_valid,
    ST_GeometryType(geometry) as geom_type
FROM campaign_geofences 
WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354';