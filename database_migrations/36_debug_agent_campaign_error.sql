-- Debug what's causing the agent campaign error

-- 1. Check if agent can access tasks for their campaigns
SELECT 'Agent access to tasks:' as info;
SELECT 
    t.id,
    t.title,
    t.campaign_id,
    c.name as campaign_name
FROM tasks t
JOIN campaigns c ON c.id = t.campaign_id
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = auth.uid()
LIMIT 5;

-- 2. Check if agent can access task_assignments
SELECT 'Agent access to task assignments:' as info;
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    t.title as task_title
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
WHERE ta.agent_id = auth.uid()
LIMIT 5;

-- 3. Check RLS policies on tasks table
SELECT 'Tasks table policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'tasks'
ORDER BY policyname;

-- 4. Check RLS policies on task_assignments table  
SELECT 'Task assignments policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'task_assignments'
ORDER BY policyname;

-- 5. Test if agent needs access to other related tables
SELECT 'Related tables that might need policies:' as info;
SELECT DISTINCT tablename 
FROM pg_policies 
WHERE tablename LIKE '%task%' OR tablename LIKE '%campaign%'
ORDER BY tablename;