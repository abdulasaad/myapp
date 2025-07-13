CREATE INDEX IF NOT EXISTS idx_touring_tasks_campaign_id ON touring_tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_touring_tasks_geofence_id ON touring_tasks(geofence_id);
CREATE INDEX IF NOT EXISTS idx_touring_tasks_status ON touring_tasks(status);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_touring_task_id ON touring_task_sessions(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_agent_id ON touring_task_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_active ON touring_task_sessions(is_active, is_completed);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_touring_task_id ON touring_task_assignments(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_agent_id ON touring_task_assignments(agent_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_status ON touring_task_assignments(status);

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

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'touring_tasks') 
        THEN 'touring_tasks: EXISTS'
        ELSE 'touring_tasks: MISSING'
    END as table_check
UNION ALL
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'touring_task_sessions') 
        THEN 'touring_task_sessions: EXISTS'
        ELSE 'touring_task_sessions: MISSING'
    END
UNION ALL
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'touring_task_assignments') 
        THEN 'touring_task_assignments: EXISTS'
        ELSE 'touring_task_assignments: MISSING'
    END;

SELECT COUNT(*) as total_touring_tables 
FROM information_schema.tables 
WHERE table_name LIKE '%touring%';