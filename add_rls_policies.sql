-- Enable RLS on touring tables if not already enabled
ALTER TABLE touring_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE touring_task_assignments ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for touring_tasks
CREATE POLICY "Touring tasks viewable by authenticated users" ON touring_tasks
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Touring tasks manageable by admin/manager" ON touring_tasks
    FOR ALL USING (get_my_role() = ANY (ARRAY['admin', 'manager']));

-- Add RLS policies for touring_task_assignments  
CREATE POLICY "Touring task assignments viewable by authenticated users" ON touring_task_assignments
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Touring task assignments manageable by admin/manager" ON touring_task_assignments
    FOR ALL USING (get_my_role() = ANY (ARRAY['admin', 'manager']));

-- Check all policies after adding them
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename IN ('touring_tasks', 'touring_task_assignments', 'campaign_geofences')
ORDER BY tablename, policyname;