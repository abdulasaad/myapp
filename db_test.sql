-- Quick database tests to verify status system is working
-- Execute these in Supabase Dashboard SQL Editor

-- Test 1: Check if new columns exist in profiles table
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('last_heartbeat', 'connection_status')
ORDER BY column_name;

-- Test 2: Check current user statuses
SELECT id, full_name, role, connection_status, last_heartbeat,
       CASE 
         WHEN last_heartbeat IS NULL THEN 'Never connected'
         WHEN NOW() - last_heartbeat < INTERVAL '1 minute' THEN 'Just now'
         WHEN NOW() - last_heartbeat < INTERVAL '1 hour' THEN 
           CONCAT(EXTRACT(MINUTE FROM NOW() - last_heartbeat)::INT, ' min ago')
         ELSE 'Long time ago'
       END as last_seen_text
FROM profiles 
WHERE status = 'active' 
ORDER BY connection_status, last_heartbeat DESC NULLS LAST;

-- Test 3: Check if functions exist
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN ('update_user_heartbeat', 'get_agents_with_last_location', 'get_users_by_status')
ORDER BY routine_name;

-- Test 4: Test the get_agents_with_last_location function
SELECT * FROM get_agents_with_last_location() LIMIT 5;

-- Test 5: Check active_agents table
SELECT COUNT(*) as agent_count FROM active_agents;
SELECT user_id, last_seen, accuracy 
FROM active_agents 
ORDER BY last_seen DESC NULLS LAST 
LIMIT 5;