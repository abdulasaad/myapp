DROP FUNCTION IF EXISTS get_all_geofences_wkt();

CREATE OR REPLACE FUNCTION get_all_geofences_wkt()
RETURNS TABLE(
    geofence_id UUID,
    geofence_name TEXT,
    geofence_area_wkt TEXT,
    geofence_type TEXT,
    geofence_color TEXT,
    campaign_id UUID,
    campaign_name TEXT,
    touring_task_id UUID,
    touring_task_title TEXT,
    max_agents INTEGER,
    is_active BOOLEAN,
    touring_tasks_info TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cg.id as geofence_id,
        cg.name as geofence_name,
        cg.area_text as geofence_area_wkt,
        'campaign'::TEXT as geofence_type,
        COALESCE(cg.color, 'FFA500') as geofence_color,
        cg.campaign_id,
        c.name as campaign_name,
        NULL::UUID as touring_task_id,
        NULL::TEXT as touring_task_title,
        cg.max_agents,
        cg.is_active,
        (
            SELECT STRING_AGG(tt.title, ', ')
            FROM touring_tasks tt
            WHERE tt.geofence_id = cg.id AND tt.status = 'active'
        ) as touring_tasks_info
    FROM campaign_geofences cg
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE cg.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_all_geofences_wkt() TO authenticated;