-- Fix: Remove recursive RLS policy on profiles table
-- The issue: Our client policy calls (SELECT role FROM profiles...) inside a profiles policy

-- 1. Drop the problematic client policy
DROP POLICY IF EXISTS "Clients can read relevant profiles for their campaigns" ON profiles;

-- 2. Create a non-recursive version
-- Instead of checking role inside the policy, we'll use a different approach
CREATE POLICY "Clients can read relevant profiles for their campaigns" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Check if the user has client_id in any campaigns (indicates they are a client)
  EXISTS (
    SELECT 1 FROM campaigns c
    WHERE c.client_id = auth.uid()
  )
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

-- 3. Alternative approach: Create a simpler policy that works with existing ones
-- Since you already have good profile policies, let's make a minimal addition
DROP POLICY IF EXISTS "Clients can read relevant profiles for their campaigns" ON profiles;

CREATE POLICY "Clients can read campaign-related profiles" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Only apply if user is assigned as client to any campaign
  -- This avoids recursion by not checking role directly
  EXISTS (
    SELECT 1 FROM campaigns c
    WHERE c.client_id = auth.uid()
    AND (
      -- They can see their own profile
      profiles.id = auth.uid()
      OR
      -- They can see campaign creators
      profiles.id = c.created_by
      OR  
      -- They can see campaign managers
      profiles.id = c.assigned_manager_id
      OR
      -- They can see agents in their campaigns
      EXISTS (
        SELECT 1 FROM tasks t
        JOIN task_assignments ta ON t.id = ta.task_id
        WHERE t.campaign_id = c.id 
        AND ta.agent_id = profiles.id
      )
    )
  )
);

-- 4. Verify the fix
SELECT 'Fixed profiles policy' as status,
       policyname,
       cmd
FROM pg_policies 
WHERE tablename = 'profiles'
AND policyname ILIKE '%client%';