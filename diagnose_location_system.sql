-- Complete diagnosis of location tracking system

-- 1. Check if the functions exist and are working
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name IN ('insert_location_coordinates', 'get_agents_with_last_location', 'update_user_heartbeat')
AND routine_schema = 'public';

-- 2. Check active_agents table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'active_agents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Test insert_location_coordinates function manually
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.090000, -- Very different coordinates to test
  37.430000,
  10.0,
  3.0
);

-- 4. Check if location was actually updated
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at,
  accuracy,
  speed,
  EXTRACT(EPOCH FROM (NOW() - updated_at)) as seconds_since_update
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 5. Check if get_agents_with_last_location returns the new data
SELECT id, full_name, last_location, last_seen 
FROM get_agents_with_last_location()
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 6. Test if the background service can call the function
-- Simulate what the Flutter background service does
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.091000, -- Another test
  37.431000,
  15.0,
  1.5
);

-- 7. Final check
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';