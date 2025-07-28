-- Debug Date Filtering Issues in Location History
-- Your app shows 180 entries but "no data found" - likely a date range problem

-- ====================================================================
-- 1. Check what dates exist for "Abood" user
-- ====================================================================
-- First, let's find Abood's user ID
SELECT id, full_name, role 
FROM profiles 
WHERE full_name ILIKE '%abood%';

-- ====================================================================
-- 2. Check Abood's location data date range
-- ====================================================================
-- Replace 'USER_ID_HERE' with Abood's actual user ID from query above
SELECT 
    COUNT(*) as total_entries,
    MIN(created_at) as earliest_date,
    MAX(created_at) as latest_date,
    DATE(created_at) as date,
    COUNT(*) as entries_per_day
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c' -- Replace with actual user ID
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- ====================================================================
-- 3. Check entries for specific date ranges
-- ====================================================================
-- Today's data
SELECT COUNT(*) as today_count
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND DATE(created_at) = CURRENT_DATE;

-- Last 7 days
SELECT COUNT(*) as last_7_days_count
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND created_at >= CURRENT_DATE - INTERVAL '7 days';

-- Last 30 days
SELECT COUNT(*) as last_30_days_count
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND created_at >= CURRENT_DATE - INTERVAL '30 days';

-- Last 90 days
SELECT COUNT(*) as last_90_days_count
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND created_at >= CURRENT_DATE - INTERVAL '90 days';

-- ====================================================================
-- 4. Check the exact date range shown in the app (19/7/2025 - 26/7/2025)
-- ====================================================================
SELECT 
    COUNT(*) as count_in_app_range,
    MIN(created_at) as min_date,
    MAX(created_at) as max_date
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND created_at >= '2025-07-19 18:39:00'::timestamptz
AND created_at <= '2025-07-26 18:39:00'::timestamptz;

-- ====================================================================
-- 5. Get sample data for the app's date range
-- ====================================================================
SELECT 
    id,
    latitude,
    longitude,
    accuracy,
    created_at,
    timestamp
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
AND created_at >= '2025-07-19 18:39:00'::timestamptz
AND created_at <= '2025-07-26 18:39:00'::timestamptz
ORDER BY created_at DESC
LIMIT 10;

-- ====================================================================
-- 6. Check timezone issues
-- ====================================================================
SELECT 
    created_at,
    created_at AT TIME ZONE 'UTC' as utc_time,
    created_at AT TIME ZONE 'Asia/Baghdad' as baghdad_time,
    EXTRACT(TIMEZONE FROM created_at) as timezone_offset
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
ORDER BY created_at DESC
LIMIT 5;

-- ====================================================================
-- 7. Check if the view is actually being used by your app
-- ====================================================================
-- Get all data without any date filtering
SELECT COUNT(*) as total_without_filters
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c';

-- ====================================================================
-- 8. Compare original table vs view data counts
-- ====================================================================
SELECT 
    'location_history_original' as source,
    COUNT(*) as count
FROM location_history 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c'
UNION ALL
SELECT 
    'location_history_app_format_view' as source,
    COUNT(*) as count
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c';

-- ====================================================================
-- 9. Check for NULL values that might cause issues
-- ====================================================================
SELECT 
    COUNT(*) as total_rows,
    COUNT(latitude) as non_null_latitude,
    COUNT(longitude) as non_null_longitude,
    COUNT(created_at) as non_null_created_at,
    COUNT(CASE WHEN latitude IS NULL OR longitude IS NULL THEN 1 END) as rows_with_null_coords
FROM location_history_app_format 
WHERE user_id = 'b5b6a078-8c4a-4961-83a6-5d727668b27c';