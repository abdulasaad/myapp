-- Create touring task assignment for the agent who completed it
-- Based on the screenshot, the current agent appears to be the first one in the list

-- 1. Create assignment for the touring task "test" and mark as completed for Ahmed Ali
INSERT INTO touring_task_assignments (touring_task_id, agent_id, status, assigned_at, completed_at)
VALUES ('007374fc-e344-4e90-8257-09ab693d881a', '263e832c-f73c-48f3-bfd2-1b567cbff0b1', 'completed', NOW() - INTERVAL '1 hour', NOW());

-- 2. Verify the assignment was created
SELECT 
    tta.id,
    tta.status,
    tta.assigned_at,
    tta.completed_at,
    tt.title as task_name,
    tt.points,
    p.full_name as agent_name
FROM touring_task_assignments tta
JOIN touring_tasks tt ON tta.touring_task_id = tt.id
JOIN profiles p ON tta.agent_id = p.id
WHERE tt.title = 'test';

-- 3. Test earnings calculation for Ahmed Ali
SELECT * FROM get_agent_overall_earnings('263e832c-f73c-48f3-bfd2-1b567cbff0b1');

-- 4. Check if Ahmed Ali is now properly enrolled in the campaign
SELECT 
    ca.*,
    p.full_name as agent_name,
    c.name as campaign_name
FROM campaign_agents ca
JOIN profiles p ON ca.agent_id = p.id
JOIN campaigns c ON ca.campaign_id = c.id
WHERE ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';