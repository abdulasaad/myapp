-- Test if location updates are happening in real-time
-- Run this several times with a few seconds between each run to see if location changes

-- 1. Check the most recent location update timestamp
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at,
  -- Show how many seconds ago this was updated
  EXTRACT(EPOCH FROM (NOW() - updated_at)) as seconds_since_update
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 2. Check heartbeat status (should be updated every 30 seconds)
SELECT 
  id,
  full_name,
  last_heartbeat,
  EXTRACT(EPOCH FROM (NOW() - last_heartbeat)) as seconds_since_heartbeat,
  status,
  connection_status
FROM profiles 
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 3. Force insert a test location to verify the function works
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.084100, -- Slightly different longitude
  37.422100,   -- Slightly different latitude  
  25.0,        -- Different accuracy
  1.5          -- Different speed
);

-- 4. Check if the test location was inserted
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at,
  accuracy,
  speed
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';