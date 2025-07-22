-- DIAGNOSE: Client location access issue
-- Client can see agents in list but gets "no location on record" when clicking

-- Step 1: Check current active_agents table policies
SELECT 'Current active_agents RLS policies:' as info;
SELECT 
    policyname,
    cmd,
    qual,
    CASE 
        WHEN policyname ILIKE '%client%' THEN 'Client-specific policy'
        ELSE 'General policy'
    END as policy_type
FROM pg_policies 
WHERE tablename = 'active_agents'
ORDER BY policyname;

-- Step 2: Check what location data exists for the client's agent
SELECT 'Location data check for client agents:' as info;
SELECT 
    aa.user_id,
    p.full_name as agent_name,
    aa.latitude,
    aa.longitude,
    aa.updated_at,
    'Location exists in DB' as status
FROM active_agents aa
JOIN profiles p ON aa.user_id = p.id
JOIN task_assignments ta ON p.id = ta.agent_id
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
WHERE c.client_id = '116ad586-6d44-46f9-abec-a20e262882a9'  -- Client test ID
AND p.role = 'agent'
ORDER BY p.full_name;

-- Step 3: Test if client can directly query active_agents
SELECT 'Direct active_agents access test:' as test_info;
SELECT 'Testing what client should be able to see in active_agents' as description;

-- This simulates the client query
WITH client_agents AS (
    SELECT DISTINCT ta.agent_id
    FROM campaigns c
    JOIN tasks t ON c.id = t.campaign_id
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE c.client_id = '116ad586-6d44-46f9-abec-a20e262882a9'
)
SELECT 
    ca.agent_id,
    p.full_name as agent_name,
    aa.latitude,
    aa.longitude,
    aa.updated_at,
    CASE 
        WHEN aa.user_id IS NOT NULL THEN 'Has location data'
        ELSE 'NO LOCATION DATA'
    END as location_status
FROM client_agents ca
JOIN profiles p ON ca.agent_id = p.id
LEFT JOIN active_agents aa ON p.id = aa.user_id
ORDER BY p.full_name;

-- Step 4: Check if the issue is with RLS policy logic
SELECT 'RLS Policy Logic Test:' as policy_test;
SELECT 'Checking if client policy logic is correct' as test_description;

-- Test the exact logic from client policy
SELECT EXISTS (
    SELECT 1 FROM campaigns c
    JOIN tasks t ON c.id = t.campaign_id
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE c.client_id = '116ad586-6d44-46f9-abec-a20e262882a9'
    AND ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali's ID
) as client_should_see_ahmed_location;

-- Step 5: Show what the Flutter app might be querying
SELECT 'What Flutter app queries:' as flutter_query;
SELECT 'active_agents query that might be failing' as query_type;

-- This is likely what the Flutter app is trying to do
SELECT 
    aa.user_id,
    aa.latitude,
    aa.longitude,
    aa.updated_at
FROM active_agents aa
WHERE aa.user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali
LIMIT 1;