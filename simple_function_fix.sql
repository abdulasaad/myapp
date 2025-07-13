-- Simple fix for the function overload conflict
-- Run this in your Supabase SQL Editor

-- 1. First, let's see what functions exist
SELECT 
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'get_agent_location_history';

-- 2. Drop the specific function variants manually
-- Try both possible signatures
DROP FUNCTION IF EXISTS public.get_agent_location_history(uuid, timestamp with time zone, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS public.get_agent_location_history(uuid, timestamp without time zone, timestamp without time zone, integer);

-- 3. Try without schema prefix
DROP FUNCTION IF EXISTS get_agent_location_history(uuid, timestamp with time zone, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS get_agent_location_history(uuid, timestamp without time zone, timestamp without time zone, integer);

-- 4. Create the clean function
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

-- 5. Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_location_history(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;

-- 6. Verify only one function exists now
SELECT 
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'get_agent_location_history';