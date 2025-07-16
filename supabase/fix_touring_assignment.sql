-- Fix touring task assignment issue

-- 1. First, check what agents exist
SELECT id, full_name, role FROM profiles WHERE role = 'agent' ORDER BY created_at DESC;

-- 2. Check the touring task details
SELECT 
    id, 
    title, 
    points, 
    campaign_id,
    status
FROM touring_tasks 
WHERE title = 'test';

-- 3. Create assignment for current agent (replace AGENT_ID with actual agent ID from query 1)
-- INSERT INTO touring_task_assignments (touring_task_id, agent_id, status, assigned_at)
-- VALUES ('007374fc-e344-4e90-8257-09ab693d881a', 'AGENT_ID_HERE', 'completed', NOW());

-- 4. After creating assignment, test earnings calculation
-- SELECT * FROM get_agent_overall_earnings('AGENT_ID_HERE');