-- Test client access after policy fix
-- Run this as the client user

-- 1. Test basic campaign access
SELECT 'My campaigns test:' as info;
SELECT id, name, client_id FROM campaigns WHERE client_id = auth.uid();

-- 2. Test campaign agents visibility
SELECT 'My campaign agents:' as info;
SELECT 
    ca.campaign_id,
    c.name as campaign_name,
    ca.agent_id,
    p.full_name as agent_name
FROM campaign_agents ca
JOIN campaigns c ON c.id = ca.campaign_id
LEFT JOIN profiles p ON p.id = ca.agent_id
WHERE c.client_id = auth.uid();

-- 3. Test active agents for my campaigns
SELECT 'Active agents for my campaigns:' as info;
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    aa.last_seen,
    aa.latitude,
    aa.longitude
FROM active_agents aa
JOIN profiles p ON p.id = aa.user_id
WHERE aa.user_id IN (
    SELECT ca.agent_id 
    FROM campaign_agents ca
    JOIN campaigns c ON c.id = ca.campaign_id
    WHERE c.client_id = auth.uid()
);

-- 4. Simulate the exact live map query
SELECT 'Live map simulation:' as info;
WITH client_campaigns AS (
    SELECT id FROM campaigns WHERE client_id = auth.uid()
),
assigned_agents AS (
    SELECT DISTINCT ca.agent_id
    FROM campaign_agents ca
    WHERE ca.campaign_id IN (SELECT id FROM client_campaigns)
)
SELECT 
    p.id,
    p.full_name,
    p.role,
    aa.last_seen,
    aa.latitude,
    aa.longitude
FROM profiles p
LEFT JOIN active_agents aa ON aa.user_id = p.id
WHERE p.id IN (SELECT agent_id FROM assigned_agents)
AND p.role = 'agent';