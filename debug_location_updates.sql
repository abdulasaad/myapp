-- Debug why location updates aren't happening

-- 1. Check if the background service is calling insert_location_coordinates
-- Let's manually test with different coordinates to see if it works
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.085000, -- Different longitude
  37.423000,   -- Different latitude  
  20.0,        -- Different accuracy
  5.0          -- Different speed
);

-- 2. Check if the update worked
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

-- 3. Check location_history table to see if any location data is being stored there
SELECT 
  user_id,
  ST_X(location::geometry) as longitude,
  ST_Y(location::geometry) as latitude,
  recorded_at,
  accuracy,
  speed
FROM location_history 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
ORDER BY recorded_at DESC
LIMIT 5;

-- 4. Check if there are any errors in the insert_location_coordinates function
-- Let's see the function definition
SELECT routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'insert_location_coordinates';

-- 5. Test with exact coordinates that the background service might be sending
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.083922, -- Same coordinates as currently stored
  37.4220936,
  600.0,
  0.0
);