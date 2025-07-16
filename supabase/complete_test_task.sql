-- Complete the task for Abood to test earnings system
-- Run these queries one by one in your Supabase SQL Editor

-- 1. Complete the task for Abood
UPDATE task_assignments 
SET status = 'completed', completed_at = NOW()
WHERE id = 'e021a655-7fc8-418c-82ff-3fbd184807b6';

-- 2. Check if the task is now completed
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
WHERE ta.status = 'completed'
AND t.title = 'test1';

-- 3. Get Abood's agent ID for earnings calculation
SELECT id, full_name FROM profiles WHERE full_name = 'Abood';

-- 4. Check Abood's earnings (replace with actual agent ID from query 3)
-- SELECT * FROM get_agent_overall_earnings('AGENT_ID_FROM_QUERY_3');

-- 5. Verify the earnings breakdown
SELECT 
    ta.agent_id,
    p.full_name as agent_name,
    SUM(CASE WHEN t.campaign_id IS NOT NULL THEN t.points ELSE 0 END) as campaign_points,
    SUM(CASE WHEN t.campaign_id IS NULL THEN t.points ELSE 0 END) as standalone_points
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
WHERE ta.status = 'completed'
GROUP BY ta.agent_id, p.full_name;