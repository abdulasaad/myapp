-- Test location insertion for جعفر طارق صبيح to see if there are permission issues

-- 1. Find جعفر's user ID
SELECT id, full_name, username, role, status 
FROM profiles 
WHERE full_name LIKE '%جعفر%' OR full_name LIKE '%طارق%';

-- 2. Test inserting location for جعفر (replace with actual user ID from step 1)
-- This will help identify if there are RLS policy issues
SELECT insert_location_coordinates(
  '6cd99aa8-b005-4958-a8ec-a1fb410686e7'::UUID, -- جعفر's ID from previous query
  44.3661,  -- Baghdad coordinates as test
  33.3152,
  50.0,
  0.0
);

-- 3. Check if the location was inserted
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at
FROM active_agents 
WHERE user_id = '6cd99aa8-b005-4958-a8ec-a1fb410686e7';

-- 4. Check RLS policies on active_agents table
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
WHERE tablename = 'active_agents';