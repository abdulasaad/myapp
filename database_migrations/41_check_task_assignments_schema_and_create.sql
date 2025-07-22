-- Check task_assignments table schema and create proper assignments

-- 1. Check the actual columns in task_assignments table
SELECT 'Task assignments table structure:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'task_assignments'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Create task assignments with correct columns
-- First, let's see what the table actually looks like with sample data
SELECT 'Sample task assignments (if any):' as info;
SELECT * FROM task_assignments LIMIT 3;

-- 3. Create task assignments for the agent using correct column structure
-- We'll insert with just the essential columns first
INSERT INTO task_assignments (task_id, agent_id)
SELECT 
    t.id as task_id,
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1' as agent_id
FROM tasks t
JOIN campaigns c ON c.id = t.campaign_id
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND NOT EXISTS (
    SELECT 1 FROM task_assignments ta 
    WHERE ta.task_id = t.id 
    AND ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
)
ON CONFLICT (task_id, agent_id) DO NOTHING
RETURNING id, task_id, agent_id;

-- 4. Verify task assignments were created
SELECT 'Task assignments after creation:' as info;
SELECT 
    ta.id,
    ta.task_id,
    ta.agent_id,
    t.title as task_title,
    c.name as campaign_name
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
JOIN campaigns c ON c.id = t.campaign_id
WHERE ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';