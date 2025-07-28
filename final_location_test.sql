-- Final test to confirm location history fix works
-- This simulates exactly what the Flutter app will now do

-- ====================================================================
-- 1. Test the 30-day default range (new behavior)
-- ====================================================================
SELECT 
    'App will now show these locations' as test_result,
    COUNT(*) as total_locations,
    MIN(DATE(created_at)) as earliest_date,
    MAX(DATE(created_at)) as latest_date,
    COUNT(CASE WHEN DATE(created_at) BETWEEN '2025-07-04' AND '2025-07-08' THEN 1 END) as july_4_to_8_count
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND created_at >= NOW() - INTERVAL '30 days'  -- NEW: 30-day range
AND created_at <= NOW();

-- ====================================================================
-- 2. Compare with old 7-day behavior 
-- ====================================================================
SELECT 
    'Old app behavior (7 days)' as test_result,
    COUNT(*) as total_locations,
    MIN(DATE(created_at)) as earliest_date,
    MAX(DATE(created_at)) as latest_date,
    COUNT(CASE WHEN DATE(created_at) BETWEEN '2025-07-04' AND '2025-07-08' THEN 1 END) as july_4_to_8_count
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND created_at >= NOW() - INTERVAL '7 days'   -- OLD: 7-day range
AND created_at <= NOW();

-- ====================================================================
-- 3. Show the most recent locations that will appear in the app
-- ====================================================================
SELECT 
    latitude,
    longitude,
    accuracy,
    created_at,
    DATE(created_at) as date,
    ROW_NUMBER() OVER (ORDER BY created_at DESC) as display_order
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
LIMIT 15;  -- Show first 15 entries the manager will see