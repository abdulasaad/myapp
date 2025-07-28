-- SQL Commands to Check Location History Setup in Supabase
-- Run these commands in your Supabase SQL Editor

-- ====================================================================
-- 1. Check if location_history table exists
-- ====================================================================
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_name LIKE '%location%' OR table_name LIKE '%history%'
ORDER BY table_name;

-- ====================================================================
-- 2. Check the exact schema of location_history table
-- ====================================================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'location_history'
ORDER BY ordinal_position;

-- ====================================================================
-- 3. Check for related location tracking tables
-- ====================================================================
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_name IN (
    'location_history',
    'agent_locations',
    'user_locations',
    'active_agents',
    'agent_location_tracking'
)
ORDER BY table_name;

-- ====================================================================
-- 4. Check indexes on location_history table
-- ====================================================================
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'location_history';

-- ====================================================================
-- 5. Check constraints and foreign keys
-- ====================================================================
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'location_history';

-- ====================================================================
-- 6. Sample data check (first 5 records)
-- ====================================================================
SELECT * FROM location_history 
ORDER BY created_at DESC 
LIMIT 5;

-- ====================================================================
-- 7. Count total records and check date range
-- ====================================================================
SELECT 
    COUNT(*) as total_records,
    MIN(created_at) as oldest_record,
    MAX(created_at) as newest_record
FROM location_history;

-- ====================================================================
-- 8. Check if there are any RLS (Row Level Security) policies
-- ====================================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'location_history';

-- ====================================================================
-- 9. Check for triggers on location_history table
-- ====================================================================
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'location_history';

-- ====================================================================
-- 10. Alternative: If location_history doesn't exist, check what exists
-- ====================================================================
-- Run this if location_history table is not found
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%location%'
ORDER BY table_name;

-- ====================================================================
-- 11. Check profiles table for location-related columns
-- ====================================================================
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND (column_name LIKE '%location%' OR column_name LIKE '%lat%' OR column_name LIKE '%lng%' OR column_name LIKE '%coord%')
ORDER BY ordinal_position;

-- ====================================================================
-- 12. Check active_agents table (if it exists)
-- ====================================================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'active_agents'
ORDER BY ordinal_position;

-- ====================================================================
-- 13. Check for any functions related to location
-- ====================================================================
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND (routine_name LIKE '%location%' OR routine_name LIKE '%agent%')
ORDER BY routine_name;

-- ====================================================================
-- 14. If using PostGIS, check for geometry columns
-- ====================================================================
-- Uncomment if you're using PostGIS for location data
/*
SELECT 
    f_table_name,
    f_geometry_column,
    coord_dimension,
    srid,
    type
FROM geometry_columns 
WHERE f_table_name IN ('location_history', 'active_agents', 'profiles');
*/

-- ====================================================================
-- 15. Check recent location entries by user
-- ====================================================================
-- Replace 'user_id' with actual column name if different
SELECT 
    user_id,
    COUNT(*) as location_count,
    MAX(created_at) as last_location_update
FROM location_history 
GROUP BY user_id 
ORDER BY last_location_update DESC 
LIMIT 10;