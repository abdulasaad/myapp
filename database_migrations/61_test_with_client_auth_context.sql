-- TEST WITH ACTUAL CLIENT AUTH CONTEXT
-- The issue is we're testing as postgres user, not as authenticated client

-- This won't work in direct SQL, but let's check if there's another issue

SELECT 'REAL ISSUE IDENTIFIED: Authentication context mismatch' as issue;

-- Step 1: Check if there's actually a simpler issue with the Flutter query
-- The Flutter app does: .inFilter('user_id', agentIds)
-- Let's test this exact query pattern

SELECT 'Testing Flutter inFilter pattern:' as test;

-- This simulates: .inFilter('user_id', ['263e832c-f73c-48f3-bfd2-1b567cbff0b1'])
SELECT user_id, latitude, longitude, updated_at, connection_status
FROM active_agents 
WHERE user_id = ANY(ARRAY['263e832c-f73c-48f3-bfd2-1b567cbff0b1']);

-- Step 2: Check if there are multiple records causing issues
SELECT 'Check for duplicate records:' as duplicate_check;
SELECT 
    user_id, 
    COUNT(*) as record_count,
    MAX(updated_at) as latest_update
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
GROUP BY user_id;

-- Step 3: Create a test to bypass authentication entirely 
-- Temporarily disable RLS to see if that's the real issue
SELECT 'Testing without RLS (emergency diagnostic):' as emergency_test;

-- Disable RLS temporarily
ALTER TABLE active_agents DISABLE ROW LEVEL SECURITY;

-- Test the exact query Flutter would make
SELECT 'Query with RLS disabled:' as rls_disabled;
SELECT user_id, latitude, longitude, updated_at, connection_status
FROM active_agents 
WHERE user_id IN ('263e832c-f73c-48f3-bfd2-1b567cbff0b1');

-- Re-enable RLS
ALTER TABLE active_agents ENABLE ROW LEVEL SECURITY;

-- Step 4: Check if it's a permissions issue on the table itself
SELECT 'Table permissions check:' as permissions;
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasinsert,
    hasselect,
    hasupdate,
    hasdelete
FROM pg_tables 
WHERE tablename = 'active_agents';

-- Step 5: Create an alternative diagnosis - maybe the issue is in how lastLocation is set
SELECT 'Check how Flutter builds lastLocation:' as flutter_check;
SELECT 'Flutter expects: latitude, longitude keys to build lastLocation' as expectation;

-- This is what Flutter should receive to build lastLocation successfully:
SELECT 
    user_id,
    latitude,
    longitude,
    CASE 
        WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 'SHOULD_CREATE_lastLocation'
        ELSE 'NULL_VALUES_PREVENT_lastLocation'
    END as location_object_status
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

SELECT 'EMERGENCY DIAGNOSTIC COMPLETE' as status;
SELECT 'If RLS disabled query works, the issue is authentication context' as diagnosis;