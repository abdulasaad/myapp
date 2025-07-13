-- Check location history table and permissions setup
-- Run this in your Supabase SQL editor

-- 1. Check if location_history table exists
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_name = 'location_history';

-- 2. Check table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'location_history'
ORDER BY ordinal_position;

-- 3. Check RLS policies on location_history table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'location_history';

-- 4. Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity, forcerowsecurity
FROM pg_tables 
WHERE tablename = 'location_history';

-- 5. Check if the RPC function exists
SELECT routine_name, routine_type, routine_definition
FROM information_schema.routines 
WHERE routine_name = 'get_agent_location_history';

-- 6. Test manager access to location_history (replace 'MANAGER_USER_ID' with actual manager ID)
-- SELECT COUNT(*) FROM location_history WHERE user_id IN (
--   SELECT ug1.user_id 
--   FROM user_groups ug1
--   WHERE ug1.group_id IN (
--     SELECT ug2.group_id 
--     FROM user_groups ug2 
--     WHERE ug2.user_id = 'MANAGER_USER_ID'
--   )
-- );

-- 7. Show sample location_history data (limit 5 rows)
SELECT user_id, recorded_at, latitude, longitude, accuracy 
FROM location_history 
ORDER BY recorded_at DESC 
LIMIT 5;