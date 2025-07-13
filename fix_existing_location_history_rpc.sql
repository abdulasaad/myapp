-- Fix the existing get_agent_location_history function to include group filtering
-- Run this in your Supabase SQL Editor

-- First, get the current function signature
-- \df get_agent_location_history

-- Drop and recreate the function with proper group filtering
DROP FUNCTION IF EXISTS get_agent_location_history(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER);

CREATE OR REPLACE FUNCTION get_agent_location_history(
  p_agent_id UUID,
  p_start_date TIMESTAMP WITH TIME ZONE,
  p_end_date TIMESTAMP WITH TIME ZONE,
  p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  accuracy REAL,
  speed REAL,
  recorded_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
  current_user_role TEXT;
  is_allowed BOOLEAN DEFAULT FALSE;
BEGIN
  -- Get current user ID
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get current user role using the existing get_my_role() function
  current_user_role := get_my_role();

  -- Check permissions based on role
  IF current_user_role = 'admin' THEN
    -- Admins can access any agent's location history
    is_allowed := TRUE;
  ELSIF current_user_role = 'manager' THEN
    -- Managers can only access location history of agents in their groups
    SELECT EXISTS(
      SELECT 1 
      FROM user_groups ug1
      JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
      JOIN profiles p ON p.id = ug1.user_id
      WHERE ug2.user_id = current_user_id  -- Current manager
        AND ug1.user_id = p_agent_id       -- Target agent
        AND p.role = 'agent'               -- Ensure target is an agent
        AND p.status = 'active'            -- Ensure agent is active
    ) INTO is_allowed;
  ELSIF current_user_role = 'agent' THEN
    -- Agents can only access their own location history
    is_allowed := (current_user_id = p_agent_id);
  ELSE
    -- Other roles cannot access location history
    is_allowed := FALSE;
  END IF;

  -- If not allowed, return empty result
  IF NOT is_allowed THEN
    RETURN;
  END IF;

  -- Return location history for the agent
  RETURN QUERY
  SELECT 
    lh.id,
    lh.user_id,
    ST_Y(lh.location::geometry) as latitude,
    ST_X(lh.location::geometry) as longitude,
    lh.accuracy,
    lh.speed,
    lh.recorded_at
  FROM location_history lh
  WHERE lh.user_id = p_agent_id
    AND (p_start_date IS NULL OR lh.recorded_at >= p_start_date)
    AND (p_end_date IS NULL OR lh.recorded_at <= p_end_date)
  ORDER BY lh.recorded_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_agent_location_history(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;

-- Test the function with a manager (replace MANAGER_USER_ID and AGENT_USER_ID with real UUIDs)
/*
-- Test as manager
SELECT set_config('request.jwt.claims', '{"sub": "MANAGER_USER_ID"}', false);
SELECT * FROM get_agent_location_history('AGENT_USER_ID', NOW() - INTERVAL '7 days', NOW(), 10);

-- Reset
SELECT set_config('request.jwt.claims', '', false);
*/