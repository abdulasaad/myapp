-- Fix agent access to tasks and task assignments by cleaning up conflicting policies

-- 1. First, let's see all policies on tasks table more clearly
SELECT 'All tasks policies:' as info;
SELECT 
    policyname,
    cmd,
    permissive,
    qual
FROM pg_policies 
WHERE tablename = 'tasks'
ORDER BY cmd, policyname;

-- 2. Drop conflicting/duplicate policies on tasks
DROP POLICY IF EXISTS "Allow all authenticated to manage tasks" ON tasks;
DROP POLICY IF EXISTS "Allow all authenticated to view tasks" ON tasks;

-- 3. Keep only the essential policies for tasks
-- The "Tasks: Consolidated SELECT for authenticated" policy should work for agents
-- Let's verify it's correct

-- 4. Check task_assignments policies  
SELECT 'All task_assignments policies:' as info;
SELECT 
    policyname,
    cmd,
    permissive,
    qual
FROM pg_policies 
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- 5. Drop conflicting policies on task_assignments
DROP POLICY IF EXISTS "Allow all authenticated to manage task assignments" ON task_assignments;
DROP POLICY IF EXISTS "Allow all authenticated to view task assignments" ON task_assignments;

-- 6. Test if agent can now access their tasks
SELECT 'Agent task access test after cleanup:' as info;
SELECT 
    t.id,
    t.title,
    t.campaign_id
FROM tasks t
JOIN task_assignments ta ON ta.task_id = t.id
WHERE ta.agent_id = auth.uid()
LIMIT 5;

-- 7. Test task assignments access
SELECT 'Agent task assignments test:' as info;
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id
FROM task_assignments ta
WHERE ta.agent_id = auth.uid()
LIMIT 5;

-- 8. Show remaining policies after cleanup
SELECT 'Remaining tasks policies:' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'tasks';

SELECT 'Remaining task_assignments policies:' as info;  
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'task_assignments';