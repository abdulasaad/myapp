-- Debug queries to test location system
-- Run these in your Supabase Dashboard SQL Editor

-- 1. Test the insert_location_coordinates function
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID, -- Ahmed Ali's user ID
  -122.084000, -- longitude (slightly different to test update)
  37.422000,   -- latitude (slightly different to test update)
  50.0,        -- accuracy
  0.0          -- speed
);

-- 2. Check if the location was updated
SELECT 
  user_id, 
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  accuracy,
  speed
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 3. Test the get_agents_with_last_location function
SELECT id, full_name, last_location, last_seen 
FROM get_agents_with_last_location() 
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 4. Check all active_agents table data
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at
FROM active_agents
ORDER BY updated_at DESC;