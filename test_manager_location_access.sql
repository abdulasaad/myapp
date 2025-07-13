-- Test manager access to location history
-- Run this in your Supabase SQL Editor after fixing the RPC function

-- 1. Find a manager and an agent in the same group
SELECT 
  m.id as manager_id,
  m.full_name as manager_name,
  a.id as agent_id, 
  a.full_name as agent_name,
  g.name as group_name
FROM profiles m
JOIN user_groups ug_m ON m.id = ug_m.user_id
JOIN user_groups ug_a ON ug_m.group_id = ug_a.group_id  
JOIN profiles a ON a.id = ug_a.user_id
JOIN groups g ON g.id = ug_m.group_id
WHERE m.role = 'manager' 
  AND a.role = 'agent'
  AND m.status = 'active'
  AND a.status = 'active'
LIMIT 5;

-- 2. Test the function (replace MANAGER_ID and AGENT_ID with values from above query)
-- SELECT set_config('request.jwt.claims', '{"sub": "MANAGER_ID_HERE"}', false);
-- SELECT COUNT(*) as location_records 
-- FROM get_agent_location_history('AGENT_ID_HERE', NOW() - INTERVAL '30 days', NOW(), 100);

-- 3. Check if there's any location data for the agent
-- SELECT COUNT(*) as total_location_records 
-- FROM location_history 
-- WHERE user_id = 'AGENT_ID_HERE';

-- 4. Reset context
-- SELECT set_config('request.jwt.claims', '', false);