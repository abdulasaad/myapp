-- Fix RLS policies for location_history table
-- Run this in your Supabase SQL editor

-- Enable RLS on location_history table (if not already enabled)
ALTER TABLE location_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (if any) to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own location history" ON location_history;
DROP POLICY IF EXISTS "Admins can view all location history" ON location_history;
DROP POLICY IF EXISTS "Managers can view agents in their groups location history" ON location_history;
DROP POLICY IF EXISTS "Allow agents to insert their own location" ON location_history;
DROP POLICY IF EXISTS "Allow agents to update their own location" ON location_history;

-- Policy 1: Allow agents to insert/update their own location history
CREATE POLICY "agents_can_manage_own_location" ON location_history
  FOR ALL 
  TO authenticated
  USING (
    auth.uid() = user_id 
    AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'agent'
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'agent'
    )
  );

-- Policy 2: Allow admins to view all location history
CREATE POLICY "admins_can_view_all_location_history" ON location_history
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

-- Policy 3: Allow managers to view location history of agents in their groups
CREATE POLICY "managers_can_view_agents_in_groups_location_history" ON location_history
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'manager'
    )
    AND EXISTS (
      -- Check if the location's user_id (agent) is in the same group as the manager
      SELECT 1 
      FROM user_groups ug1
      JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
      JOIN profiles p ON p.id = ug1.user_id
      WHERE ug2.user_id = auth.uid()    -- Current manager
        AND ug1.user_id = location_history.user_id  -- Location owner (agent)
        AND p.role = 'agent'            -- Ensure it's an agent
        AND p.status = 'active'         -- Ensure agent is active
    )
  );

-- Test the policies by checking what a manager can see
-- (Replace 'MANAGER_USER_ID' with actual manager UUID to test)
/*
SET role authenticated;
SET request.jwt.claims TO '{"sub": "MANAGER_USER_ID"}';

SELECT COUNT(*) as accessible_location_records
FROM location_history;

RESET role;
*/