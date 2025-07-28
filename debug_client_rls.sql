-- Check RLS policies that affect client access to task_assignments and location_heartbeats

-- 1. Check task_assignments policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'task_assignments' 
AND schemaname = 'public'
ORDER BY policyname;

-- 2. Check location_heartbeats policies  
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'location_heartbeats' 
AND schemaname = 'public'
ORDER BY policyname;

-- 3. Check tasks policies (needed for the join)
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'tasks' 
AND schemaname = 'public'
ORDER BY policyname;

-- 4. Test what the client can actually see
-- Check if current user can read task_assignments
SELECT 'Testing task_assignments access' as test;
SELECT COUNT(*) as task_assignments_count FROM task_assignments;

-- Check if current user can read location_heartbeats  
SELECT 'Testing location_heartbeats access' as test;
SELECT COUNT(*) as heartbeats_count FROM location_heartbeats;

-- Check if current user can read tasks
SELECT 'Testing tasks access' as test;  
SELECT COUNT(*) as tasks_count FROM tasks;