-- Test the comprehensive location tracking fix

-- 1. Test the updated get_agents_with_last_location function
SELECT 
  id, 
  full_name, 
  connection_status, 
  last_location,
  last_seen
FROM get_agents_with_last_location()
ORDER BY connection_status, last_heartbeat DESC;

-- 2. Use the debug function to monitor all agents
SELECT * FROM debug_location_updates()
ORDER BY heartbeat_status, heartbeat_age_minutes;

-- 3. Insert a fresh location for Ahmed Ali to test real-time updates
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.084200, -- Slightly different coordinates
  37.422200,
  30.0,
  2.0
);

-- 4. Verify the fresh location appears in the live map function
SELECT 
  id, 
  full_name, 
  last_location,
  last_seen
FROM get_agents_with_last_location()
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 5. Check that agents who never logged in are filtered out
SELECT 
  'Agents in profiles' as source,
  COUNT(*) as count
FROM profiles 
WHERE status = 'active' AND role IN ('agent', 'manager')

UNION ALL

SELECT 
  'Agents in live map' as source,
  COUNT(*) as count
FROM get_agents_with_last_location();