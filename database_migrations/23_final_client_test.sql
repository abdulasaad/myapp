-- Final test as CLIENT user
-- Run this AS THE CLIENT USER to verify everything works

-- 1. My identity
SELECT 'My identity:' as info;
SELECT id, full_name, role FROM profiles WHERE id = auth.uid();

-- 2. My campaigns
SELECT 'My campaigns:' as info;
SELECT id, name FROM campaigns WHERE client_id = auth.uid();

-- 3. Agents assigned to my campaigns
SELECT 'Agents in my campaigns:' as info;
SELECT 
    c.name as campaign_name,
    p.full_name as agent_name,
    p.id as agent_id
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
JOIN profiles p ON p.id = ca.agent_id
WHERE c.client_id = auth.uid();

-- 4. Agent locations for my campaigns
SELECT 'Agent locations:' as info;
SELECT 
    p.full_name as agent_name,
    aa.latitude,
    aa.longitude,
    aa.last_seen,
    aa.connection_status
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
JOIN profiles p ON p.id = ca.agent_id
LEFT JOIN active_agents aa ON aa.user_id = p.id
WHERE c.client_id = auth.uid();

-- 5. Exact live map query simulation
SELECT 'Live map data:' as info;
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
    p.email,
    p.status,
    p.role,
    aa.latitude,
    aa.longitude,
    aa.accuracy,
    aa.last_heartbeat,
    aa.battery_level,
    aa.connection_status
FROM profiles p
LEFT JOIN active_agents aa ON aa.user_id = p.id
WHERE p.id IN (SELECT agent_id FROM assigned_agents)
AND p.role = 'agent';