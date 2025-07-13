-- Drop and recreate the function with correct coordinate order
CREATE OR REPLACE FUNCTION check_point_in_geofence(
    p_lat numeric,
    p_lng numeric,
    p_geofence_id uuid
) RETURNS boolean AS $$
DECLARE
    geofence_area geometry;
BEGIN
    SELECT geometry INTO geofence_area
    FROM campaign_geofences
    WHERE id = p_geofence_id;
    
    IF geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- IMPORTANT: The polygon is stored as (lat, lng) but ST_Point expects (lng, lat)
    -- So we need to create the point as ST_Point(lat, lng) to match the polygon format
    RETURN ST_Contains(geofence_area, ST_SetSRID(ST_Point(p_lat, p_lng), 4326));
END;
$$ LANGUAGE plpgsql;

-- Test with a point that should be inside Baghdad area
-- Using coordinates that are within the polygon bounds
SELECT check_point_in_geofence(
    33.35,  -- latitude (within 33.19 to 33.47)
    44.35,  -- longitude (within 44.13 to 44.50)
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS should_be_inside;

-- Test the center point
SELECT check_point_in_geofence(
    33.333,
    44.317,
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS center_test;