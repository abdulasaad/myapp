-- Create function to get all geofences in WKT format for live map
-- This includes both campaign geofences and touring task geofences

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
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    -- Campaign geofences (regular geofences)
    SELECT 
        cg.id as geofence_id,
        cg.name as geofence_name,
        cg.area_text as geofence_area_wkt,
        'campaign'::TEXT as geofence_type,
        COALESCE(cg.color, 'FFA500') as geofence_color, -- Default to orange if no color
        cg.campaign_id,
        c.name as campaign_name,
        NULL::UUID as touring_task_id,
        NULL::TEXT as touring_task_title,
        cg.max_agents,
        cg.is_active
    FROM campaign_geofences cg
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE cg.is_active = true
    
    UNION ALL
    
    -- Touring task geofences (geofences that have touring tasks)
    SELECT 
        cg.id as geofence_id,
        CONCAT('Touring: ', tt.title) as geofence_name,
        cg.area_text as geofence_area_wkt,
        'touring_task'::TEXT as geofence_type,
        COALESCE(cg.color, '9C27B0') as geofence_color, -- Default to purple for touring tasks
        cg.campaign_id,
        c.name as campaign_name,
        tt.id as touring_task_id,
        tt.title as touring_task_title,
        cg.max_agents,
        cg.is_active AND tt.status = 'active' as is_active
    FROM touring_tasks tt
    JOIN campaign_geofences cg ON tt.geofence_id = cg.id
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE tt.status = 'active' AND cg.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_geofences_wkt() TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_all_geofences_wkt() IS 'Returns all active geofences in WKT format for live map display, including both campaign geofences and touring task geofences';