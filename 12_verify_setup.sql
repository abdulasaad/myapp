SELECT 'Setup complete - checking tables...' as status;

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

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'create_touring_task') 
        THEN 'create_touring_task: EXISTS'
        ELSE 'create_touring_task: MISSING'
    END as function_check
UNION ALL
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'check_point_in_geofence') 
        THEN 'check_point_in_geofence: EXISTS'
        ELSE 'check_point_in_geofence: MISSING'
    END;