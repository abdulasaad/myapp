-- SAFE Migration: Add client-specific RLS policies
-- These policies work alongside existing ones without conflicts

-- IMPORTANT NOTE: Your campaigns table has multiple overlapping policies:
-- - "Allow all authenticated to manage campaigns" (permissive for ALL commands)
-- - "Allow all authenticated to view campaigns" (permissive for SELECT)
-- - Several consolidated policies for specific roles
--
-- Our client policies will be ADDITIVE and more specific

-- =================================================================
-- 1. CLIENT ACCESS TO PROFILES TABLE
-- =================================================================

-- Allow clients to read profiles of users involved in their campaigns
-- This is additive to existing policies
CREATE POLICY "Clients can read relevant profiles for their campaigns" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Only apply if the current user is a client
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
  AND
  (
    -- Clients can always read their own profile
    auth.uid() = profiles.id 
    OR
    -- Clients can read profiles of users involved in their campaigns
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.client_id = auth.uid()
      AND (
        -- Campaign creators (admins/managers who created the campaign)
        c.created_by = profiles.id
        OR
        -- Campaign managers
        c.assigned_manager_id = profiles.id
        OR
        -- Agents assigned to tasks in their campaigns
        EXISTS (
          SELECT 1 FROM tasks t
          JOIN task_assignments ta ON t.id = ta.task_id
          WHERE t.campaign_id = c.id 
          AND ta.agent_id = profiles.id
        )
      )
    )
  )
);

-- =================================================================
-- 2. CLIENT ACCESS TO CAMPAIGNS TABLE  
-- =================================================================

-- Since you have "Allow all authenticated to view campaigns" policy,
-- clients can already view campaigns. But let's add a specific policy
-- that ensures clients only see their assigned campaigns when used
-- alongside more restrictive policies in the future.

CREATE POLICY "Clients can view their assigned campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
  -- Only apply to clients
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
  AND
  -- They can see campaigns assigned to them
  client_id = auth.uid()
);

-- =================================================================
-- 3. CLIENT ACCESS TO TASKS TABLE
-- =================================================================

-- Clients can read tasks in their assigned campaigns
CREATE POLICY "Clients can view tasks in their campaigns" ON tasks
FOR SELECT
TO authenticated
USING (
  -- Only apply to clients
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
  AND
  -- Tasks must belong to campaigns assigned to this client
  EXISTS (
    SELECT 1 FROM campaigns c
    WHERE c.id = tasks.campaign_id
    AND c.client_id = auth.uid()
  )
);

-- =================================================================
-- 4. CLIENT ACCESS TO TASK_ASSIGNMENTS TABLE
-- =================================================================

-- Clients can read task assignments in their campaigns
CREATE POLICY "Clients can view task assignments in their campaigns" ON task_assignments
FOR SELECT
TO authenticated
USING (
  -- Only apply to clients
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
  AND
  -- Task assignments must be for tasks in campaigns assigned to this client
  EXISTS (
    SELECT 1 FROM tasks t
    JOIN campaigns c ON t.campaign_id = c.id
    WHERE t.id = task_assignments.task_id
    AND c.client_id = auth.uid()
  )
);

-- =================================================================
-- 5. CLIENT ACCESS TO ACTIVE_AGENTS TABLE (for live tracking)
-- =================================================================

-- Clients can read agent locations for agents working on their campaigns
CREATE POLICY "Clients can view agent locations for their campaigns" ON active_agents
FOR SELECT
TO authenticated
USING (
  -- Only apply to clients
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
  AND
  -- Agent must be assigned to tasks in campaigns assigned to this client
  EXISTS (
    SELECT 1 FROM campaigns c
    JOIN tasks t ON c.id = t.campaign_id
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE c.client_id = auth.uid()
    AND ta.agent_id = active_agents.user_id
  )
);

-- =================================================================
-- VERIFICATION QUERIES
-- =================================================================

-- Check that our new policies were created
SELECT 
    'New client policies created' as status,
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE policyname ILIKE '%client%'
AND schemaname = 'public'
ORDER BY tablename, policyname;

-- Show all policies on campaigns table to ensure no conflicts
SELECT 
    'All campaigns policies' as status,
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
AND schemaname = 'public'
ORDER BY policyname;