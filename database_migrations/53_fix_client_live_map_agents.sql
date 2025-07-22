-- Fix: Client live map agent visibility issue
-- Ensure clients can see agent locations through active_agents table

-- 1. Check if active_agents table exists and its structure
SELECT 'Active agents table info:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'active_agents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check current RLS policies on active_agents
SELECT 'Current active_agents policies:' as info;
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'active_agents'
ORDER BY policyname;

-- 3. Test current agent locations for client campaigns
SELECT 'Current active agents for client campaigns:' as info;
SELECT DISTINCT
    aa.user_id,
    p.full_name as agent_name,
    aa.latitude,
    aa.longitude,
    aa.updated_at,
    c.name as campaign_name,
    c.client_id
FROM active_agents aa
JOIN profiles p ON aa.user_id = p.id
JOIN task_assignments ta ON p.id = ta.agent_id
JOIN tasks t ON ta.task_id = t.id
JOIN campaigns c ON t.campaign_id = c.id
WHERE c.client_id IS NOT NULL
AND p.role = 'agent'
ORDER BY c.name, p.full_name;

-- 4. Make sure the client RLS policy on active_agents is properly configured
-- Drop existing policy if it exists and recreate it
DROP POLICY IF EXISTS "Clients can view agent locations for their campaigns" ON active_agents;

CREATE POLICY "Clients can view agent locations for their campaigns" ON active_agents
FOR SELECT
TO authenticated
USING (
  -- Allow admins and managers to see all
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
  OR
  -- Allow agents to see their own location
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND auth.uid() = user_id
  )
  OR
  -- Allow clients to see locations of agents assigned to their campaigns
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
    AND EXISTS (
      SELECT 1 FROM campaigns c
      JOIN tasks t ON c.id = t.campaign_id
      JOIN task_assignments ta ON t.id = ta.task_id
      WHERE c.client_id = auth.uid()
      AND ta.agent_id = active_agents.user_id
    )
  )
);

-- 5. Also ensure there's a policy that allows reading agent profiles for clients
-- This might be needed for the live map to show agent names
DROP POLICY IF EXISTS "Enhanced client profile access for agent data" ON profiles;

CREATE POLICY "Enhanced client profile access for agent data" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Always allow reading own profile
  auth.uid() = profiles.id
  OR
  -- Allow admins/managers to read all profiles
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
  OR
  -- Allow agents to read other agent profiles (existing behavior)
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND profiles.role = 'agent'
  )
  OR
  -- ENHANCED: Allow clients to read profiles of agents in their campaigns
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
    AND (
      -- Direct agent assignments through task_assignments
      EXISTS (
        SELECT 1 FROM campaigns c
        JOIN tasks t ON c.id = t.campaign_id
        JOIN task_assignments ta ON t.id = ta.task_id
        WHERE c.client_id = auth.uid()
        AND ta.agent_id = profiles.id
        AND profiles.role = 'agent'
      )
      OR
      -- Campaign creators and managers for client campaigns
      EXISTS (
        SELECT 1 FROM campaigns c
        WHERE c.client_id = auth.uid()
        AND (c.created_by = profiles.id OR c.assigned_manager_id = profiles.id)
      )
    )
  )
);

-- 6. Test the policies by simulating a client query
SELECT 'Testing client access to agent data:' as info;
SELECT 'This query simulates what a client should see' as note;

-- This is what the client should be able to query:
WITH client_campaigns AS (
  SELECT id as campaign_id
  FROM campaigns 
  WHERE client_id = '116ad586-6d44-46f9-abec-a20e262882a9'  -- Replace with actual client ID
),
client_agents AS (
  SELECT DISTINCT ta.agent_id
  FROM client_campaigns cc
  JOIN tasks t ON cc.campaign_id = t.campaign_id
  JOIN task_assignments ta ON t.id = ta.task_id
)
SELECT 
  'Client should see these agents:' as info,
  p.id as agent_id,
  p.full_name as agent_name,
  aa.latitude,
  aa.longitude,
  aa.updated_at as last_location_update
FROM client_agents ca
JOIN profiles p ON ca.agent_id = p.id
LEFT JOIN active_agents aa ON p.id = aa.user_id
ORDER BY p.full_name;

-- 7. Final verification
SELECT 'Final verification summary:' as info;
SELECT 
  COUNT(DISTINCT c.id) as client_campaigns,
  COUNT(DISTINCT ta.agent_id) as unique_agents_assigned,
  COUNT(DISTINCT aa.user_id) as agents_with_location_data
FROM campaigns c
LEFT JOIN tasks t ON c.id = t.campaign_id
LEFT JOIN task_assignments ta ON t.id = ta.task_id
LEFT JOIN active_agents aa ON ta.agent_id = aa.user_id
WHERE c.client_id IS NOT NULL;