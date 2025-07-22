-- Debug why client can't see assigned agents
-- Run this as the client user to diagnose the issue

-- 1. Current user info
SELECT 'Current user:' as info;
SELECT id, role, full_name FROM profiles WHERE id = auth.uid();

-- 2. Check campaigns assigned to current client
SELECT 'My campaigns as client:' as info;
SELECT id, name, client_id FROM campaigns WHERE client_id = auth.uid();

-- 3. Check campaign_agents table entries
SELECT 'Campaign agents for my campaigns:' as info;
SELECT 
    ca.campaign_id,
    c.name as campaign_name,
    ca.agent_id,
    p.full_name as agent_name,
    p.role as agent_role
FROM campaign_agents ca
JOIN campaigns c ON c.id = ca.campaign_id
LEFT JOIN profiles p ON p.id = ca.agent_id
WHERE c.client_id = auth.uid();

-- 4. Check if client can access campaign_agents table directly
SELECT 'Direct campaign_agents access test:' as info;
SELECT COUNT(*) as visible_campaign_agents
FROM campaign_agents ca
WHERE EXISTS (
    SELECT 1 FROM campaigns c 
    WHERE c.id = ca.campaign_id 
    AND c.client_id = auth.uid()
);

-- 5. Check active_agents table
SELECT 'Active agents visibility:' as info;
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    aa.last_seen
FROM active_agents aa
JOIN profiles p ON p.id = aa.user_id
WHERE aa.user_id IN (
    SELECT ca.agent_id 
    FROM campaign_agents ca
    JOIN campaigns c ON c.id = ca.campaign_id
    WHERE c.client_id = auth.uid()
);

-- 6. Check RLS policies on campaign_agents
SELECT 'Campaign_agents RLS policies:' as info;
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'campaign_agents'
ORDER BY policyname;

-- 7. Check RLS policies on active_agents
SELECT 'Active_agents RLS policies:' as info;
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'active_agents'
ORDER BY policyname;

-- 8. Check if RLS is enabled on these tables
SELECT 'RLS status for key tables:' as info;
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('campaign_agents', 'active_agents', 'profiles')
AND schemaname = 'public';

-- 9. Test query used in live map (simplified)
SELECT 'Live map query test:' as info;
WITH my_campaigns AS (
    SELECT id FROM campaigns WHERE client_id = auth.uid()
),
campaign_agent_ids AS (
    SELECT DISTINCT agent_id 
    FROM campaign_agents 
    WHERE campaign_id IN (SELECT id FROM my_campaigns)
)
SELECT 
    p.id,
    p.full_name,
    aa.last_seen
FROM profiles p
LEFT JOIN active_agents aa ON aa.user_id = p.id
WHERE p.id IN (SELECT agent_id FROM campaign_agent_ids)
AND p.role = 'agent';