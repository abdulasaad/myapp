SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%touring%';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'touring_tasks'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'touring_task_sessions'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'touring_task_assignments'
ORDER BY ordinal_position;