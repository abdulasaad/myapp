CREATE OR REPLACE FUNCTION check_point_in_geofence(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_geofence_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN true;
END;
$$ LANGUAGE plpgsql;