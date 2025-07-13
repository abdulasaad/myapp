-- Fix the function overloading conflict for get_agent_location_history
-- Run this in your Supabase SQL Editor

-- 1. Drop ALL versions of the function (both timestamp variants)
DROP FUNCTION IF EXISTS get_agent_location_history(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER);
DROP FUNCTION IF EXISTS get_agent_location_history(UUID, TIMESTAMP WITHOUT TIME ZONE, TIMESTAMP WITHOUT TIME ZONE, INTEGER);

-- 2. Check if there are any other variants and drop them
-- List all functions with this name to make sure we get them all
SELECT routine_name, routine_type, specific_name, 
       array_to_string(
         array(
           SELECT parameter_mode || ' ' || parameter_name || ' ' || data_type
           FROM information_schema.parameters 
           WHERE specific_name = r.specific_name
           ORDER BY ordinal_position
         ), 
         ', '
       ) as parameters
FROM information_schema.routines r
WHERE routine_name = 'get_agent_location_history';

-- 3. Drop any remaining functions (adjust as needed based on the query above)
DO $$
BEGIN
    -- Drop all functions with this name regardless of signature
    EXECUTE 'DROP FUNCTION IF EXISTS ' || quote_ident(n.nspname) || '.' || quote_ident(p.proname) || '(' || pg_get_function_identity_arguments(p.oid) || ')'
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'get_agent_location_history';
END $$;

-- 4. Create the clean function with proper group filtering
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

-- 5. Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_agent_location_history(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;

-- 6. Verify the function was created correctly
SELECT routine_name, routine_type, specific_name,
       array_to_string(
         array(
           SELECT parameter_mode || ' ' || parameter_name || ' ' || data_type
           FROM information_schema.parameters 
           WHERE specific_name = r.specific_name
           ORDER BY ordinal_position
         ), 
         ', '
       ) as parameters
FROM information_schema.routines r
WHERE routine_name = 'get_agent_location_history';