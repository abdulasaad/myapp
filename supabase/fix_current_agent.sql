-- Let's create a task completion for the current agent
-- First, let's complete the regular task "test1" for the current agent

-- Complete test1 for Ahmed Ali (who we know exists and should be the current agent)
UPDATE task_assignments 
SET status = 'completed', completed_at = NOW()
WHERE task_id = (SELECT id FROM tasks WHERE title = 'test1')
AND agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND status = 'assigned';

-- Check if the update worked
SELECT 
    ta.id,
    ta.status,
    ta.completed_at,
    t.title as task_name,
    t.points,
    p.full_name as agent_name
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
WHERE ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND ta.status = 'completed';

-- Check Ahmed Ali's total earnings now (should be 20 points: 10 from touring + 10 from regular task)
SELECT * FROM get_agent_overall_earnings('263e832c-f73c-48f3-bfd2-1b567cbff0b1');