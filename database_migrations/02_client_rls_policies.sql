-- Migration: RLS policies for client role
-- This file contains Row Level Security policies for client access

-- 1. Client access to profiles table
-- Clients can read their own profile and profiles of agents in their campaigns
CREATE POLICY "Clients can read relevant profiles" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Clients can read their own profile
  auth.uid() = id 
  OR 
  -- Clients can read profiles of users involved in their campaigns
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
    AND
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.client_id = auth.uid()
      AND (
        -- Can see campaign creators (admins/managers)
        c.created_by = profiles.id
        OR
        -- Can see agents assigned to tasks in their campaigns
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

-- 2. Client access to campaigns table
-- Clients can read campaigns they own
CREATE POLICY "Clients can read their campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
  client_id = auth.uid()
  OR
  -- Keep existing access for other roles
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
  OR
  -- Agents can see campaigns they're assigned to
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND EXISTS (
      SELECT 1 FROM tasks t
      JOIN task_assignments ta ON t.id = ta.task_id
      WHERE t.campaign_id = campaigns.id 
      AND ta.agent_id = auth.uid()
    )
  )
);

-- 3. Client access to tasks table
-- Clients can read tasks in their campaigns
CREATE POLICY "Clients can read tasks in their campaigns" ON tasks
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM campaigns c
    WHERE c.id = tasks.campaign_id
    AND (
      c.client_id = auth.uid()
      OR
      -- Keep existing access for other roles
      (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
      OR
      -- Agents can see their assigned tasks
      (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
        AND EXISTS (
          SELECT 1 FROM task_assignments ta
          WHERE ta.task_id = tasks.id 
          AND ta.agent_id = auth.uid()
        )
      )
    )
  )
);

-- 4. Client access to task_assignments table
-- Clients can read task assignments in their campaigns
CREATE POLICY "Clients can read task assignments in their campaigns" ON task_assignments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tasks t
    JOIN campaigns c ON t.campaign_id = c.id
    WHERE t.id = task_assignments.task_id
    AND (
      c.client_id = auth.uid()
      OR
      -- Keep existing access for other roles
      (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
      OR
      -- Agents can see their own assignments
      (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
        AND task_assignments.agent_id = auth.uid()
      )
    )
  )
);

-- 5. Client access to active_agents table (for real-time tracking)
-- Clients can read agent locations for their campaigns
CREATE POLICY "Clients can read agent locations for their campaigns" ON active_agents
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM campaigns c
    JOIN tasks t ON c.id = t.campaign_id
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE c.client_id = auth.uid()
    AND ta.agent_id = active_agents.agent_id
  )
  OR
  -- Keep existing access for other roles
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
  OR
  -- Agents can see their own location
  (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND active_agents.agent_id = auth.uid()
  )
);

-- 6. Client access to evidence/submissions (if they exist)
-- Note: Add similar policies for evidence tables based on your schema