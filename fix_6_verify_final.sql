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