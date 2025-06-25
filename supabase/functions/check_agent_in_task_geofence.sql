-- Function to check if an agent is within a task's geofence
-- Used for evidence upload validation when geofence enforcement is enabled

CREATE OR REPLACE FUNCTION check_agent_in_task_geofence(
    p_agent_id UUID,
    p_task_id UUID,
    p_agent_lat DOUBLE PRECISION,
    p_agent_lng DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    task_enforce_geofence BOOLEAN;
    agent_point GEOMETRY;
    geofence_geometry GEOMETRY;
    is_inside BOOLEAN := FALSE;
BEGIN
    -- Check if task exists and has geofence enforcement enabled
    SELECT enforce_geofence INTO task_enforce_geofence
    FROM tasks
    WHERE id = p_task_id;
    
    -- If task doesn't exist or geofence is not enforced, return true (allow upload)
    IF task_enforce_geofence IS NULL OR task_enforce_geofence = FALSE THEN
        RETURN TRUE;
    END IF;
    
    -- Create point geometry from agent coordinates
    agent_point := ST_SetSRID(ST_MakePoint(p_agent_lng, p_agent_lat), 4326);
    
    -- Get the task's geofence geometry
    SELECT area INTO geofence_geometry
    FROM geofences
    WHERE task_id = p_task_id
    LIMIT 1;
    
    -- If no geofence exists, allow upload
    IF geofence_geometry IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Check if agent point is within the geofence
    SELECT ST_Within(agent_point, geofence_geometry) INTO is_inside;
    
    RETURN COALESCE(is_inside, FALSE);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_agent_in_task_geofence(UUID, UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

COMMENT ON FUNCTION check_agent_in_task_geofence IS 'Checks if an agent is within a task geofence for evidence upload validation';