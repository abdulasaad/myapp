-- Test queries to verify earnings fix is working
-- Run these in your Supabase SQL Editor

-- 1. Check if agent who completed 'test2' is now in campaign_agents
SELECT 
    t.title as task_name,
    ta.agent_id,
    p.full_name as agent_name,
    t.campaign_id,
    c.name as campaign_name,
    CASE 
        WHEN ca.agent_id IS NOT NULL THEN 'YES' 
        ELSE 'NO' 
    END as in_campaign_agents
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
JOIN campaigns c ON t.campaign_id = c.id
LEFT JOIN campaign_agents ca ON (ca.campaign_id = t.campaign_id AND ca.agent_id = ta.agent_id)
WHERE ta.status = 'completed'
AND t.title = 'test2';

-- 2. Test earnings calculation for the agent who completed test2
-- Replace 'AGENT_ID_HERE' with the actual agent ID from query above
SELECT * FROM get_agent_overall_earnings('AGENT_ID_HERE');

-- 3. Check all completed tasks and their campaign enrollment status
SELECT 
    t.title as task_name,
    p.full_name as agent_name,
    c.name as campaign_name,
    ta.completed_at,
    CASE 
        WHEN ca.agent_id IS NOT NULL THEN 'ENROLLED' 
        ELSE 'NOT ENROLLED' 
    END as enrollment_status
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN profiles p ON ta.agent_id = p.id
JOIN campaigns c ON t.campaign_id = c.id
LEFT JOIN campaign_agents ca ON (ca.campaign_id = t.campaign_id AND ca.agent_id = ta.agent_id)
WHERE ta.status = 'completed'
ORDER BY ta.completed_at DESC;

-- 4. Check daily participation records
SELECT 
    cdp.*,
    p.full_name as agent_name,
    c.name as campaign_name
FROM campaign_daily_participation cdp
JOIN profiles p ON cdp.agent_id = p.id
JOIN campaigns c ON cdp.campaign_id = c.id
ORDER BY cdp.participation_date DESC;