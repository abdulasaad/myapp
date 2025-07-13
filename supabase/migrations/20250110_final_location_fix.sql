-- FINAL COMPREHENSIVE LOCATION TRACKING FIX
-- This migration completely rebuilds the location tracking system

-- 1. Clean up any existing conflicting functions
DROP FUNCTION IF EXISTS get_agents_with_last_location();
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID, TEXT);
DROP FUNCTION IF EXISTS update_user_heartbeat(UUID);
DROP FUNCTION IF EXISTS insert_location_coordinates(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS insert_location_update(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS debug_location_updates();

-- 2. Ensure active_agents table exists with correct structure
CREATE TABLE IF NOT EXISTS active_agents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  last_location POINT,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accuracy DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one record per user
  UNIQUE(user_id)
);

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_active_agents_user_id ON active_agents(user_id);
CREATE INDEX IF NOT EXISTS idx_active_agents_last_seen ON active_agents(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_active_agents_updated_at ON active_agents(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_heartbeat_active ON profiles(last_heartbeat DESC, status, role) WHERE status = 'active';

-- 4. Enable RLS and create policies
ALTER TABLE active_agents ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view active agents" ON active_agents;
DROP POLICY IF EXISTS "Users can update own location" ON active_agents;

CREATE POLICY "Users can view active agents" ON active_agents
  FOR SELECT
  USING (true); -- Allow all authenticated users to read location data

CREATE POLICY "Users can update own location" ON active_agents
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 5. Grant permissions
GRANT ALL ON active_agents TO authenticated;
GRANT ALL ON active_agents TO service_role;

-- 6. Create the location insertion function
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
  -- Insert or update location data
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

-- 7. Create the heartbeat function
CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET 
    last_heartbeat = NOW(),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_user_heartbeat TO authenticated;

-- 8. Create the main live map function
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
    -- Determine connection status based on heartbeat
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'offline'
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
      ELSE 'offline'
    END as connection_status,
    p.last_heartbeat,
    -- Format the location as POINT(lng lat)
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
    AND p.last_heartbeat IS NOT NULL  -- Only show agents who have logged in
    AND p.last_heartbeat > NOW() - INTERVAL '24 hours'  -- Active in last 24 hours
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

-- 9. Create debug function
CREATE OR REPLACE FUNCTION debug_location_updates()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  role TEXT,
  heartbeat_status TEXT,
  heartbeat_age_minutes NUMERIC,
  location_status TEXT,
  location_age_minutes NUMERIC,
  last_heartbeat TIMESTAMP WITH TIME ZONE,
  last_location_update TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.role,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'NEVER'
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as heartbeat_status,
    EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) / 60 as heartbeat_age_minutes,
    CASE 
      WHEN aa.last_seen IS NULL THEN 'NO LOCATION'
      WHEN NOW() - aa.last_seen < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - aa.last_seen < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - aa.last_seen < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as location_status,
    EXTRACT(EPOCH FROM (NOW() - aa.last_seen)) / 60 as location_age_minutes,
    p.last_heartbeat,
    aa.last_seen
  FROM profiles p
  LEFT JOIN active_agents aa ON p.id = aa.user_id
  WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
  ORDER BY 
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 3
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 0
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 1
      ELSE 2
    END,
    p.last_heartbeat DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_location_updates TO authenticated;

-- 10. Test the system with fresh data
SELECT insert_location_coordinates(
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::UUID,
  -122.095000, -- Fresh test coordinates
  37.435000,
  25.0,
  2.5
);