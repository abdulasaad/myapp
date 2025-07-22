-- Debug campaign agent assignments for client visibility issue

-- 1. Show all campaigns with basic info
SELECT 'All Campaigns:' as info;
SELECT 
    id,
    name,
    status,
    created_by,
    client_id,
    CASE WHEN client_id IS NOT NULL THEN 'Has Client' ELSE 'No Client' END as client_status
FROM campaigns
ORDER BY name;

-- 2. Check campaign_agents table for all campaigns  
SELECT 'Campaign Agent Assignments:' as info;
SELECT 
    ca.campaign_id,
    c.name as campaign_name,
    ca.agent_id,
    p.full_name as agent_name,
    p.role as agent_role,
    p.status as agent_status
FROM campaign_agents ca
JOIN campaigns c ON c.id = ca.campaign_id
JOIN profiles p ON p.id = ca.agent_id
ORDER BY c.name, p.full_name;

-- 3. Check specifically for campaign "1" (from screenshot)
SELECT 'Campaign "1" Details:' as info;
SELECT 
    id as campaign_id,
    name,
    client_id,
    (SELECT full_name FROM profiles WHERE id = campaigns.client_id) as client_name,
    (SELECT role FROM profiles WHERE id = campaigns.client_id) as client_role
FROM campaigns 
WHERE name = '1';

-- 4. Check agents assigned to campaign "1"
SELECT 'Agents for Campaign "1":' as info;
SELECT 
    ca.agent_id,
    p.full_name as agent_name,
    p.role,
    p.status,
    p.email
FROM campaign_agents ca
JOIN profiles p ON p.id = ca.agent_id
JOIN campaigns c ON c.id = ca.campaign_id
WHERE c.name = '1';

-- 5. Count agents per campaign
SELECT 'Agent Count Per Campaign:' as info;
SELECT 
    c.name as campaign_name,
    c.client_id,
    COUNT(ca.agent_id) as agent_count
FROM campaigns c
LEFT JOIN campaign_agents ca ON ca.campaign_id = c.id
GROUP BY c.id, c.name, c.client_id
ORDER BY c.name;

-- 6. Check if there are any agents at all
SELECT 'Total Agents in System:' as info;
SELECT COUNT(*) as total_agents FROM profiles WHERE role = 'agent';