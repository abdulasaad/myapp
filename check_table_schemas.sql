
-- Check the current schema of task_assignments table
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'task_assignments' 
ORDER BY ordinal_position;

-- Check the current schema of touring_task_assignments table  
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'touring_task_assignments' 
ORDER BY ordinal_position;

