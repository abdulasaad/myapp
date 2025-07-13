-- FINAL LOCATION TRACKING FIX - STANDALONE
-- Run this directly in Supabase Dashboard SQL Editor

-- 1. Clean up functions
DROP FUNCTION IF EXISTS get_agents_with_last_location();
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID);
DROP FUNCTION IF EXISTS insert_location_coordinates(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

-- 2. Recreate location insertion function
CREATE OR REPLACE FUNCTION insert_location_coordinates(
  p_user_id UUID,
  p_longitude DOUBLE PRECISION,
  p_latitude DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO active_agents (user_id, last_location, last_seen, accuracy, speed, updated_at)
  VALUES (p_user_id, POINT(p_longitude, p_latitude), NOW(), p_accuracy, p_speed, NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET
    last_location = EXCLUDED.last_location,
    last_seen = EXCLUDED.last_seen,
    accuracy = EXCLUDED.accuracy,
    speed = EXCLUDED.speed,
    updated_at = EXCLUDED.updated_at;
END;
$$;

GRANT EXECUTE ON FUNCTION insert_location_coordinates TO authenticated;

-- 3. Recreate heartbeat function
CREATE OR REPLACE FUNCTION update_user_heartbeat(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET last_heartbeat = NOW(), updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;

-- 4. Recreate live map function
CREATE OR REPLACE FUNCTION get_agents_with_last_location()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  username TEXT,
  role TEXT,
  status TEXT,
  connection_status TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location TEXT,
  last_seen TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.username,
    p.role,
    p.status,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'offline'
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
      ELSE 'offline'
    END as connection_status,
    p.last_heartbeat,
    CASE 
      WHEN aa.last_location IS NOT NULL THEN 
        'POINT(' || aa.last_location[0] || ' ' || aa.last_location[1] || ')'
      ELSE NULL
    END as last_location,
    aa.last_seen
  FROM profiles p
  LEFT JOIN active_agents aa ON aa.user_id = p.id
  WHERE p.status = 'active' 
    AND p.role IN ('agent', 'manager')
    AND p.last_heartbeat IS NOT NULL
    AND p.last_heartbeat > NOW() - INTERVAL '24 hours'
  ORDER BY 
    CASE 
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
      ELSE 3
    END,
    p.last_heartbeat DESC NULLS LAST,
    aa.last_seen DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_agents_with_last_location TO authenticated;

-- 5. Test the system
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.100000, -- NEW TEST COORDINATES
  37.440000,
  20.0,
  1.0
);

-- 6. Verify the fix
SELECT 
  user_id,
  last_location[0] as longitude,
  last_location[1] as latitude,
  last_seen,
  updated_at
FROM active_agents 
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

-- 7. Test live map function
SELECT id, full_name, last_location, last_seen 
FROM get_agents_with_last_location()
WHERE id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';