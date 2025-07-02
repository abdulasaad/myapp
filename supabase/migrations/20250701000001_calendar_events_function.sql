-- Create calendar events function that includes campaigns, tasks, and route visits
-- This function supports the calendar screen in the app

CREATE OR REPLACE FUNCTION get_calendar_events(
    month_start TEXT,
    month_end TEXT
) RETURNS TABLE(
    id UUID,
    title TEXT,
    type TEXT,
    start_date DATE,
    end_date DATE,
    description TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Get campaigns
    SELECT 
        c.id,
        c.name as title,
        'campaign' as type,
        c.start_date::DATE,
        COALESCE(c.end_date::DATE, c.start_date::DATE) as end_date,
        c.description,
        c.status
    FROM campaigns c
    WHERE c.start_date::DATE <= month_end::DATE
    AND COALESCE(c.end_date::DATE, c.start_date::DATE) >= month_start::DATE
    AND c.status IN ('active', 'draft', 'completed')
    
    UNION ALL
    
    -- Get standalone tasks
    SELECT 
        t.id,
        t.title as title,
        'task' as type,
        t.created_at::DATE as start_date,
        t.created_at::DATE as end_date,
        t.description,
        t.status
    FROM tasks t
    WHERE t.campaign_id IS NULL -- Only standalone tasks
    AND t.created_at::DATE <= month_end::DATE
    AND t.created_at::DATE >= month_start::DATE
    AND t.status IN ('active', 'draft', 'completed')
    
    UNION ALL
    
    -- Get route visits (place visits)
    SELECT 
        pv.id,
        COALESCE(p.name || ' Visit', 'Place Visit') as title,
        'route_visit' as type,
        COALESCE(pv.checked_in_at::DATE, pv.created_at::DATE) as start_date,
        COALESCE(pv.checked_out_at::DATE, pv.checked_in_at::DATE, pv.created_at::DATE) as end_date,
        COALESCE(pv.visit_notes, 'Route place visit') as description,
        pv.status
    FROM place_visits pv
    JOIN places p ON p.id = pv.place_id
    WHERE COALESCE(pv.checked_in_at::DATE, pv.created_at::DATE) <= month_end::DATE
    AND COALESCE(pv.checked_in_at::DATE, pv.created_at::DATE) >= month_start::DATE
    AND pv.status IN ('pending', 'checked_in', 'completed')
    
    ORDER BY start_date, title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_calendar_events TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_calendar_events IS 'Returns calendar events including campaigns, tasks, and route visits for a given month range';