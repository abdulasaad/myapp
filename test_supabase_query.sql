-- Test if the foreign key relationship is properly set up
SELECT 
    constraint_name,
    table_name,
    column_name,
    foreign_table_name,
    foreign_column_name
FROM information_schema.key_column_usage
WHERE table_name IN ('touring_tasks', 'touring_task_assignments', 'campaign_geofences')
AND constraint_name LIKE '%fkey%';

-- Check if RLS policies might be blocking the query
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename IN ('touring_tasks', 'touring_task_assignments', 'campaign_geofences');