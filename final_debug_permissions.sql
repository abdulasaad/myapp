-- Final debug: Check permissions and data accessibility

-- ====================================================================
-- 1. Check if RLS is blocking the view
-- ====================================================================
-- Disable RLS temporarily to test if it's the issue
ALTER TABLE location_history DISABLE ROW LEVEL SECURITY;

-- Test the view without RLS
SELECT 
    'WITHOUT RLS' as test_type,
    COUNT(*) as total_count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- Re-enable RLS
ALTER TABLE location_history ENABLE ROW LEVEL SECURITY;

-- ====================================================================
-- 2. Check what RLS policies exist
-- ====================================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as policy_condition
FROM pg_policies 
WHERE tablename IN ('location_history', 'location_history_app_format')
ORDER BY tablename, policyname;

-- ====================================================================
-- 3. Test as if we're the specific user (manager)
-- ====================================================================
-- Check manager user ID
SELECT 
    'Manager user info' as info,
    id,
    email,
    role
FROM profiles
WHERE email = 'user.a@test.com';

-- ====================================================================
-- 4. Test direct table access vs view access
-- ====================================================================
-- Direct table (what works)
SELECT 
    'DIRECT TABLE ACCESS' as method,
    COUNT(*) as count,
    MIN(recorded_at) as earliest,
    MAX(recorded_at) as latest
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'

UNION ALL

-- View access (what might be broken)
SELECT 
    'VIEW ACCESS' as method,
    COUNT(*) as count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- ====================================================================
-- 5. Check if there are any index issues
-- ====================================================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'location_history'
ORDER BY indexname;

-- ====================================================================
-- 6. Show exactly what the Flutter app should see
-- ====================================================================
-- This mimics the exact query the app makes
SELECT 
    id,
    user_id,
    latitude,
    longitude,
    accuracy,
    speed,
    recorded_at,
    created_at,
    timestamp_field,
    'Flutter app data' as source
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND created_at >= '2025-06-27 00:00:00'::timestamptz
AND created_at <= '2025-07-27 23:59:59'::timestamptz
ORDER BY created_at DESC
LIMIT 10;