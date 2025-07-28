-- Debug why statistics show data but history list is empty

-- ====================================================================
-- 1. Compare raw table vs view for Ahmed Ali
-- ====================================================================
-- Raw location_history table (what statistics uses)
SELECT 
    'RAW TABLE' as source,
    COUNT(*) as total_count,
    MIN(recorded_at) as earliest,
    MAX(recorded_at) as latest
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'

UNION ALL

-- View (what history list uses)
SELECT 
    'VIEW' as source,
    COUNT(*) as total_count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- ====================================================================
-- 2. Check today's data specifically in both sources
-- ====================================================================
-- Today in raw table
SELECT 
    'RAW TABLE - TODAY' as source,
    COUNT(*) as today_count,
    MIN(recorded_at) as earliest_today,
    MAX(recorded_at) as latest_today
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND DATE(recorded_at) = CURRENT_DATE

UNION ALL

-- Today in view
SELECT 
    'VIEW - TODAY' as source,
    COUNT(*) as today_count,
    MIN(created_at) as earliest_today,
    MAX(created_at) as latest_today
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND DATE(created_at) = CURRENT_DATE;

-- ====================================================================
-- 3. Check if there's data in the time range the app is querying
-- ====================================================================
-- App is filtering: 27/7/2025 22:54 - 27/7/2025 22:54 (same time = today only)
SELECT 
    COUNT(*) as exact_timeframe_count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND created_at >= '2025-07-27 22:54:00'::timestamptz
AND created_at <= '2025-07-27 22:54:59'::timestamptz;

-- ====================================================================
-- 4. Check if agent has ANY data today at all
-- ====================================================================
SELECT 
    'Full day check' as test,
    COUNT(*) as locations_today,
    array_agg(DISTINCT EXTRACT(hour FROM created_at) ORDER BY EXTRACT(hour FROM created_at)) as hours_with_data
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
AND DATE(created_at) = '2025-07-27';

-- ====================================================================
-- 5. Show recent entries to see what's actually available
-- ====================================================================
SELECT 
    created_at,
    latitude,
    longitude,
    'Recent entry' as note
FROM location_history_app_format
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
ORDER BY created_at DESC
LIMIT 5;