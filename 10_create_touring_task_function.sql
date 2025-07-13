CREATE OR REPLACE FUNCTION create_touring_task(
    p_campaign_id UUID,
    p_geofence_id UUID,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_required_time_minutes INTEGER DEFAULT 30,
    p_movement_timeout_seconds INTEGER DEFAULT 60,
    p_min_movement_threshold DECIMAL DEFAULT 5.0,
    p_points INTEGER DEFAULT 10
) RETURNS JSON AS $$
DECLARE
    task_id UUID;
    result JSON;
BEGIN
    INSERT INTO touring_tasks (
        campaign_id,
        geofence_id,
        title,
        description,
        required_time_minutes,
        movement_timeout_seconds,
        min_movement_threshold,
        points,
        created_by
    ) VALUES (
        p_campaign_id,
        p_geofence_id,
        p_title,
        p_description,
        p_required_time_minutes,
        p_movement_timeout_seconds,
        p_min_movement_threshold,
        p_points,
        current_setting('request.jwt.claim.sub', true)::uuid
    ) RETURNING id INTO task_id;

    SELECT json_build_object(
        'id', id,
        'campaign_id', campaign_id,
        'geofence_id', geofence_id,
        'title', title,
        'description', description,
        'required_time_minutes', required_time_minutes,
        'movement_timeout_seconds', movement_timeout_seconds,
        'min_movement_threshold', min_movement_threshold,
        'points', points,
        'status', status,
        'created_at', created_at,
        'created_by', created_by
    ) INTO result
    FROM touring_tasks
    WHERE id = task_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql;