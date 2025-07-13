CREATE OR REPLACE FUNCTION check_point_in_geofence(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_geofence_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    geofence_area geometry;
BEGIN
    SELECT geometry INTO geofence_area
    FROM campaign_geofences
    WHERE id = p_geofence_id;
    
    IF geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN ST_Contains(geofence_area, ST_Point(p_lng, p_lat));
END;
$$ LANGUAGE plpgsql;