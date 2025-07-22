-- Force clean problematic RLS policies that are preventing agent access

-- 1. Force drop ALL conflicting policies on tasks table
DROP POLICY IF EXISTS "Allow all authenticated to manage tasks" ON tasks;
DROP POLICY IF EXISTS "Allow all authenticated to view tasks" ON tasks;

-- Double check they're gone
SELECT 'Tasks policies after forced cleanup:' as info;
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'tasks' ORDER BY policyname;

-- 2. Force drop ALL conflicting policies on task_assignments table  
DROP POLICY IF EXISTS "Allow all authenticated to manage task assignments" ON task_assignments;
DROP POLICY IF EXISTS "Allow all authenticated to view task assignments" ON task_assignments;

-- Double check they're gone
SELECT 'Task assignments policies after forced cleanup:' as info;
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'task_assignments' ORDER BY policyname;

-- 3. Now test agent access (run as agent user)
SELECT 'Agent can access task assignments:' as info;
SELECT ta.id, ta.task_id, ta.agent_id 
FROM task_assignments ta 
WHERE ta.agent_id = auth.uid() 
LIMIT 3;

-- 4. Test agent access to tasks through assignments
SELECT 'Agent can access tasks:' as info;
SELECT DISTINCT t.id, t.title, t.campaign_id
FROM tasks t
JOIN task_assignments ta ON ta.task_id = t.id
WHERE ta.agent_id = auth.uid()
LIMIT 3;

-- 5. If above works, test full campaign data access
SELECT 'Agent full campaign access test:' as info;
SELECT 
    c.name as campaign_name,
    COUNT(DISTINCT t.id) as task_count,
    COUNT(DISTINCT ta.id) as assignment_count
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
LEFT JOIN tasks t ON t.campaign_id = c.id  
LEFT JOIN task_assignments ta ON ta.task_id = t.id AND ta.agent_id = auth.uid()
WHERE ca.agent_id = auth.uid()
GROUP BY c.id, c.name;