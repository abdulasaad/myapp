-- Drop and recreate the function with proper SRID handling
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
    
    -- Create point with SRID 4326 (WGS84)
    RETURN ST_Contains(geofence_area, ST_SetSRID(ST_Point(p_lng, p_lat), 4326));
END;
$$ LANGUAGE plpgsql;

-- Test the fixed function
SELECT check_point_in_geofence(
    33.333, 
    44.4, 
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS is_inside_geofence;

-- Test with a point that should be outside
SELECT check_point_in_geofence(
    0, 
    0, 
    'e555bb87-5dc1-43db-908d-765a9a992354'
) AS is_outside_geofence;