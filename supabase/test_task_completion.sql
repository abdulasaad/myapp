-- Test completing a task to verify earnings system
-- Run this in your Supabase SQL Editor

-- 1. First, let's see the current task assignments
SELECT 
    ta.id,
    ta.status,
    t.title as task_name,
    p.full_name as agent_name,
    t.points
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
WHERE t.title = 'test1';

-- 2. Complete the task for one agent (replace 'TASK_ASSIGNMENT_ID' with actual ID from above)
-- UPDATE task_assignments 
-- SET status = 'completed', completed_at = NOW()
-- WHERE id = 'TASK_ASSIGNMENT_ID';

-- 3. After completing the task, check earnings (replace 'AGENT_ID' with actual agent ID)
-- SELECT * FROM get_agent_overall_earnings('AGENT_ID');

-- 4. Check if standalone task points are calculated correctly
-- SELECT 
--     ta.id,
--     ta.status,
--     ta.completed_at,
--     t.title as task_name,
--     t.points,
--     p.full_name as agent_name
-- FROM task_assignments ta
-- JOIN tasks t ON ta.task_id = t.id
-- JOIN profiles p ON ta.agent_id = p.id
-- WHERE ta.status = 'completed'
-- AND t.title = 'test1';