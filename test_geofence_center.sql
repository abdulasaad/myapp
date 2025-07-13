-- Get the center point of the Baghdad geofence
SELECT 
    id,
    name,
    ST_X(ST_Centroid(geometry)) as center_lng,
    ST_Y(ST_Centroid(geometry)) as center_lat,
    ST_AsText(ST_Centroid(geometry)) as center_point
FROM campaign_geofences 
WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354';

-- Test with the center point (should definitely be inside)
SELECT check_point_in_geofence(
    (SELECT ST_Y(ST_Centroid(geometry)) FROM campaign_geofences WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354'),
    (SELECT ST_X(ST_Centroid(geometry)) FROM campaign_geofences WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354'),
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS center_is_inside;

-- Get the bounding box to understand the area
SELECT 
    ST_XMin(geometry) as min_lng,
    ST_XMax(geometry) as max_lng,
    ST_YMin(geometry) as min_lat,
    ST_YMax(geometry) as max_lat
FROM campaign_geofences 
WHERE id = 'e555bb87-5dc1-43db-908d-765a9a992354';