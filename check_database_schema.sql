-- Comprehensive database schema check for AL-Tijwal app
-- Run this first to understand the current setup before making any changes

-- 1. Check if location_history table exists and get its structure
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'location_history'
ORDER BY ordinal_position;

-- 2. Check what tables exist that might be related to location tracking
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE '%location%'
OR table_name LIKE '%agent%'
OR table_name LIKE '%active%'
ORDER BY table_name;

-- 3. Check existing RPC functions related to agents/location
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (routine_name LIKE '%agent%' OR routine_name LIKE '%location%')
ORDER BY routine_name;

-- 4. Check constraints on location_history table
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'location_history'::regclass;

-- 5. Check indexes on location_history table
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'location_history';

-- 6. Sample data from location_history to understand the structure
SELECT 
    user_id,
    location,
    accuracy,
    speed,
    recorded_at,
    EXTRACT(EPOCH FROM (NOW() - recorded_at)) as seconds_ago,
    CASE 
        WHEN recorded_at > NOW() THEN 'FUTURE TIMESTAMP!'
        ELSE 'OK'
    END as timestamp_check
FROM location_history
ORDER BY recorded_at DESC
LIMIT 10;

-- 7. Check how many rows have future timestamps
SELECT 
    COUNT(*) as total_rows,
    COUNT(CASE WHEN recorded_at > NOW() + INTERVAL '1 minute' THEN 1 END) as future_timestamps,
    MIN(recorded_at) as earliest_record,
    MAX(recorded_at) as latest_record
FROM location_history;

-- 8. Check if active_agents table exists and its structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'active_agents'
ORDER BY ordinal_position;

-- 9. Check profiles table structure (for role filtering)
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('id', 'full_name', 'role')
ORDER BY ordinal_position;