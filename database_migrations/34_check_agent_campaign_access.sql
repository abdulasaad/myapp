-- Check why agents can't see campaigns assigned to them

-- 1. Check current campaigns policies
SELECT 'Current campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 2. Check if there's a policy for agents to see campaigns
SELECT 'Looking for agent access policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
AND (qual ILIKE '%agent%' OR policyname ILIKE '%agent%');

-- 3. Check campaign_agents table to see how agents are linked to campaigns
SELECT 'Campaign agents assignments:' as info;
SELECT 
    c.name as campaign_name,
    c.id as campaign_id,
    ca.agent_id,
    p.full_name as agent_name,
    p.role as agent_role
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
JOIN profiles p ON p.id = ca.agent_id
ORDER BY c.name, p.full_name;

-- 4. Check if there are policies on campaign_agents table
SELECT 'Campaign_agents policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaign_agents'
ORDER BY policyname;

-- 5. Test query that agent should be able to run
-- (This should be run as an agent user)
SELECT 'Test agent campaign access:' as info;
SELECT 
    c.id,
    c.name,
    c.description
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE ca.agent_id = auth.uid()
LIMIT 5;