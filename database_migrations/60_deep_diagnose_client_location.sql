-- DEEP DIAGNOSIS: What is the client actually receiving from the database?
-- Different approach - simulate the exact Flutter queries

-- Step 1: Check if RLS is even working for client user
SELECT 'Testing RLS enforcement for client user:' as test_type;

-- Set the session to simulate client user context
SET LOCAL rls.active_agents_debug = true;

-- Step 2: Check current session context
SELECT 'Current session info:' as session_info;
SELECT 
    current_user as db_user,
    current_setting('request.jwt.claims', true) as jwt_claims,
    current_setting('request.headers', true) as headers;

-- Step 3: Simulate the exact client query that Flutter would make
-- This mimics what the Flutter app does in live_map_screen.dart
SELECT 'Simulating Flutter client query:' as flutter_simulation;

-- Query 1: Get agent profiles (this works)
SELECT 'Step 1 - Agent profiles query:' as step1;
SELECT id, full_name, email, status, role
FROM profiles 
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'  -- Ahmed Ali
AND role = 'agent';

-- Query 2: Get active agents data (this might be failing)
SELECT 'Step 2 - Active agents query (this might fail):' as step2;
SELECT user_id, latitude, longitude, updated_at, connection_status
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';  -- Ahmed Ali

-- Step 4: Check what happens when we try to JOIN (Flutter combines data)
SELECT 'Step 3 - Combined query (what Flutter tries to do):' as step3;
SELECT 
    p.id,
    p.full_name,
    p.email,
    p.status,
    p.role,
    aa.latitude,
    aa.longitude,
    aa.updated_at,
    aa.connection_status,
    CASE 
        WHEN aa.user_id IS NOT NULL THEN 'HAS_LOCATION'
        ELSE 'NO_LOCATION'
    END as location_debug
FROM profiles p
LEFT JOIN active_agents aa ON p.id = aa.user_id
WHERE p.id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND p.role = 'agent';

-- Step 5: Test if it's an RLS issue by checking policy evaluation
SELECT 'Step 4 - RLS Policy Evaluation Test:' as step4;

-- Check if the client should be able to see this specific agent
SELECT 
    'Policy check results:' as info,
    EXISTS (
        SELECT 1 FROM campaigns c
        JOIN tasks t ON c.id = t.campaign_id
        JOIN task_assignments ta ON t.id = ta.task_id
        WHERE c.client_id = '116ad586-6d44-46f9-abec-a20e262882a9'  -- Client test ID
        AND ta.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'   -- Ahmed Ali ID
    ) as task_assignments_path,
    EXISTS (
        SELECT 1 FROM campaign_agents ca
        JOIN campaigns c ON ca.campaign_id = c.id
        WHERE c.client_id = '116ad586-6d44-46f9-abec-a20e262882a9'  -- Client test ID
        AND ca.agent_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'   -- Ahmed Ali ID
    ) as campaign_agents_path;

-- Step 6: Try direct access without RLS to see if data exists
SELECT 'Step 5 - Bypass RLS test (admin view):' as step5;
-- This shows what an admin would see
WITH admin_view AS (
    SELECT user_id, latitude, longitude, updated_at
    FROM active_agents 
    WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
)
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM admin_view) THEN 'DATA_EXISTS_IN_TABLE'
        ELSE 'NO_DATA_IN_TABLE'
    END as data_status,
    (SELECT COUNT(*) FROM admin_view) as location_records;

-- Step 7: Check all current RLS policies on active_agents
SELECT 'Step 6 - All current active_agents policies:' as step6;
SELECT 
    schemaname,
    tablename, 
    policyname, 
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'active_agents'
ORDER BY policyname;

-- Step 8: Final diagnosis summary
SELECT 'DIAGNOSIS SUMMARY:' as summary;
SELECT 'Check the results above to identify the exact failure point' as instruction;