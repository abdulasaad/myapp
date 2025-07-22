-- Check current RLS policies and client assignments
-- Run AS ADMIN USER

-- 1. Current campaigns policies
SELECT 'Current campaigns RLS policies:' as info;
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 2. Check if any campaign has a client assigned
SELECT 'Campaigns with client assignments:' as info;
SELECT 
    c.id,
    c.name,
    c.client_id,
    p.full_name as client_name,
    p.role as client_role,
    p.id as profile_id
FROM campaigns c
LEFT JOIN profiles p ON p.id = c.client_id
WHERE c.client_id IS NOT NULL;

-- 3. Verify the specific client exists
SELECT 'Client user details:' as info;
SELECT 
    id,
    full_name,
    role,
    email,
    status
FROM profiles 
WHERE role = 'client'
ORDER BY created_at DESC;

-- 4. Check campaign_agents for campaigns with clients
SELECT 'Campaign agents for client campaigns:' as info;
SELECT 
    c.name as campaign_name,
    c.client_id,
    ca.agent_id,
    p.full_name as agent_name
FROM campaigns c
JOIN campaign_agents ca ON ca.campaign_id = c.id
LEFT JOIN profiles p ON p.id = ca.agent_id
WHERE c.client_id IS NOT NULL;

-- 5. Test the exact RLS condition
SELECT 'Testing RLS condition for each client:' as info;
SELECT 
    p.id as client_id,
    p.full_name as client_name,
    c.id as campaign_id,
    c.name as campaign_name,
    c.client_id = p.id as should_see_campaign
FROM profiles p
CROSS JOIN campaigns c
WHERE p.role = 'client' 
AND c.client_id IS NOT NULL;