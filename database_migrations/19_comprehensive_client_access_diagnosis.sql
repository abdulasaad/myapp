-- Comprehensive diagnosis of client access issues
-- Run this as ADMIN first to see the full picture

-- 1. Check if campaign_agents table has data
SELECT 'Campaign agents data check:' as info;
SELECT 
    ca.campaign_id,
    c.name as campaign_name,
    c.client_id,
    p1.full_name as client_name,
    ca.agent_id,
    p2.full_name as agent_name
FROM campaign_agents ca
JOIN campaigns c ON c.id = ca.campaign_id
LEFT JOIN profiles p1 ON p1.id = c.client_id
LEFT JOIN profiles p2 ON p2.id = ca.agent_id
WHERE c.client_id IS NOT NULL
ORDER BY c.name;

-- 2. Check active_agents table data
SELECT 'Active agents data:' as info;
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    p.role,
    aa.last_seen,
    aa.latitude,
    aa.longitude
FROM active_agents aa
JOIN profiles p ON p.id = aa.user_id
WHERE p.role = 'agent'
ORDER BY aa.last_seen DESC
LIMIT 10;

-- 3. Check ALL RLS policies
SELECT 'All RLS policies:' as info;
SELECT 
    tablename,
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies 
WHERE tablename IN ('campaigns', 'campaign_agents', 'active_agents', 'profiles')
ORDER BY tablename, policyname;

-- 4. Check RLS enabled status
SELECT 'RLS enabled status:' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename IN ('campaigns', 'campaign_agents', 'active_agents', 'profiles')
AND schemaname = 'public';

-- 5. Get a specific client user to test with
SELECT 'Client users:' as info;
SELECT 
    id,
    full_name,
    role,
    created_at
FROM profiles 
WHERE role = 'client'
ORDER BY created_at DESC;

-- 6. For each client, check what they SHOULD be able to see
SELECT 'Client campaign assignments:' as info;
SELECT 
    p.id as client_id,
    p.full_name as client_name,
    c.id as campaign_id,
    c.name as campaign_name,
    COUNT(ca.agent_id) as assigned_agents
FROM profiles p
LEFT JOIN campaigns c ON c.client_id = p.id
LEFT JOIN campaign_agents ca ON ca.campaign_id = c.id
WHERE p.role = 'client'
GROUP BY p.id, p.full_name, c.id, c.name
ORDER BY p.full_name, c.name;

-- 7. Test the exact query chain that should work
SELECT 'Full access chain test:' as info;
WITH test_client AS (
    SELECT id FROM profiles WHERE role = 'client' LIMIT 1
),
client_campaigns AS (
    SELECT c.* FROM campaigns c, test_client tc WHERE c.client_id = tc.id
),
campaign_agents_list AS (
    SELECT ca.* FROM campaign_agents ca 
    JOIN client_campaigns cc ON cc.id = ca.campaign_id
),
agent_profiles AS (
    SELECT p.* FROM profiles p
    JOIN campaign_agents_list cal ON cal.agent_id = p.id
    WHERE p.role = 'agent'
),
agent_locations AS (
    SELECT aa.* FROM active_agents aa
    JOIN agent_profiles ap ON ap.id = aa.user_id
)
SELECT 
    'Client' as step, COUNT(*) as count FROM test_client
UNION ALL
SELECT 'Campaigns', COUNT(*) FROM client_campaigns
UNION ALL  
SELECT 'Campaign Agents', COUNT(*) FROM campaign_agents_list
UNION ALL
SELECT 'Agent Profiles', COUNT(*) FROM agent_profiles
UNION ALL
SELECT 'Active Locations', COUNT(*) FROM agent_locations;