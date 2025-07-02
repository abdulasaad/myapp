-- Step 7: Create spatial functions for place geofencing and route management
-- These functions enable geofence checking and route progression

-- Function 1: Check if agent is within a place's geofence
CREATE OR REPLACE FUNCTION check_agent_in_place_geofence(
    place_uuid UUID,
    agent_lat DOUBLE PRECISION,
    agent_lng DOUBLE PRECISION
) RETURNS BOOLEAN AS $$
DECLARE
    is_inside BOOLEAN := false;
BEGIN
    -- Check if the agent's location is within any geofence for this place
    SELECT EXISTS (
        SELECT 1 
        FROM geofences g
        WHERE g.place_id = place_uuid
        AND ST_Contains(
            g.area::geometry, 
            ST_SetSRID(ST_Point(agent_lng, agent_lat), 4326)
        )
    ) INTO is_inside;
    
    RETURN is_inside;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function 2: Get the next place to visit in a route
CREATE OR REPLACE FUNCTION get_next_place_in_route(
    route_assignment_uuid UUID
) RETURNS TABLE(
    place_id UUID,
    place_name TEXT,
    visit_order INTEGER,
    instructions TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    estimated_duration_minutes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rp.place_id,
        p.name,
        rp.visit_order,
        rp.instructions,
        p.latitude,
        p.longitude,
        rp.estimated_duration_minutes
    FROM route_places rp
    JOIN places p ON p.id = rp.place_id
    JOIN route_assignments ra ON ra.route_id = rp.route_id
    WHERE ra.id = route_assignment_uuid
    AND NOT EXISTS (
        -- Exclude places that have been completed
        SELECT 1 FROM place_visits pv 
        WHERE pv.route_assignment_id = route_assignment_uuid 
        AND pv.place_id = rp.place_id 
        AND pv.status = 'completed'
    )
    ORDER BY rp.visit_order
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function 3: Get route progress statistics
CREATE OR REPLACE FUNCTION get_route_progress(
    route_assignment_uuid UUID
) RETURNS TABLE(
    total_places INTEGER,
    completed_places INTEGER,
    in_progress_places INTEGER,
    pending_places INTEGER,
    total_duration_minutes INTEGER,
    progress_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH route_stats AS (
        SELECT 
            COUNT(DISTINCT rp.place_id) as total,
            COUNT(DISTINCT CASE WHEN pv.status = 'completed' THEN pv.place_id END) as completed,
            COUNT(DISTINCT CASE WHEN pv.status = 'checked_in' THEN pv.place_id END) as in_progress,
            COUNT(DISTINCT CASE WHEN pv.status = 'pending' OR pv.status IS NULL THEN rp.place_id END) as pending,
            SUM(CASE WHEN pv.duration_minutes IS NOT NULL THEN pv.duration_minutes ELSE 0 END)::INTEGER as total_duration
        FROM route_assignments ra
        JOIN route_places rp ON rp.route_id = ra.route_id
        LEFT JOIN place_visits pv ON pv.route_assignment_id = ra.id AND pv.place_id = rp.place_id
        WHERE ra.id = route_assignment_uuid
    )
    SELECT 
        total,
        completed,
        in_progress,
        pending,
        total_duration,
        CASE 
            WHEN total > 0 THEN ROUND((completed::NUMERIC / total::NUMERIC) * 100, 2)
            ELSE 0
        END as progress_percentage
    FROM route_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function 4: Auto check-out when agent is assigned to a new route or task
CREATE OR REPLACE FUNCTION auto_checkout_on_new_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto check-out from any active place visits
    UPDATE place_visits 
    SET 
        checked_out_at = NOW(),
        status = 'completed',
        visit_notes = COALESCE(visit_notes || E'\n', '') || 'Auto checked-out due to new assignment'
    WHERE agent_id = NEW.agent_id 
    AND status = 'checked_in';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-checkout on new route assignment
CREATE TRIGGER auto_checkout_on_route_assignment
    AFTER INSERT ON route_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_checkout_on_new_assignment();

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION check_agent_in_place_geofence TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_place_in_route TO authenticated;
GRANT EXECUTE ON FUNCTION get_route_progress TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION check_agent_in_place_geofence IS 'Checks if agent location is within a place geofence';
COMMENT ON FUNCTION get_next_place_in_route IS 'Returns the next place to visit in route order';
COMMENT ON FUNCTION get_route_progress IS 'Returns progress statistics for a route assignment';
COMMENT ON FUNCTION auto_checkout_on_new_assignment IS 'Automatically checks out agent from active visits when assigned new route';