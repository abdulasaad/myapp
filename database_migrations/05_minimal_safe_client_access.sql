-- Minimal Safe Client Implementation
-- Strategy: Don't add any policies to profiles table to avoid recursion
-- Instead, rely on existing policies and modify other table policies only

-- =================================================================
-- ANALYSIS: Current profiles table policies are working fine:
-- - profiles_select_policy: Uses check_profile_update_permission(id)
-- - This function already handles role-based access safely
-- - We should NOT add any client-specific policies to profiles table
-- =================================================================

-- 1. Verify that existing profiles policies will work for clients
-- The profiles_select_policy uses check_profile_update_permission() function
-- Let's check what this function does:
SELECT 'Existing profiles access function' as info,
       routine_name,
       routine_definition
FROM information_schema.routines 
WHERE routine_name = 'check_profile_update_permission'
AND routine_schema = 'public';

-- 2. Update only the campaigns table policies to be more explicit about client access
-- Remove our previous client policy and create a simpler one
DROP POLICY IF EXISTS "Clients can view their assigned campaigns" ON campaigns;

-- Create a very simple client policy for campaigns
CREATE POLICY "Simple client campaign access" ON campaigns
FOR SELECT
TO authenticated
USING (
  -- Simple check: if client_id matches current user, they can see it
  client_id = auth.uid()
);

-- 3. Update tasks table policy to be simpler
DROP POLICY IF EXISTS "Clients can view tasks in their campaigns" ON tasks;

CREATE POLICY "Simple client task access" ON tasks
FOR SELECT  
TO authenticated
USING (
  -- Client can see tasks if the campaign belongs to them
  EXISTS (
    SELECT 1 FROM campaigns c
    WHERE c.id = tasks.campaign_id
    AND c.client_id = auth.uid()
  )
);

-- 4. Update task_assignments table policy  
DROP POLICY IF EXISTS "Clients can view task assignments in their campaigns" ON task_assignments;

CREATE POLICY "Simple client task assignment access" ON task_assignments
FOR SELECT
TO authenticated  
USING (
  -- Client can see task assignments for their campaigns
  EXISTS (
    SELECT 1 FROM tasks t
    JOIN campaigns c ON t.campaign_id = c.id
    WHERE t.id = task_assignments.task_id
    AND c.client_id = auth.uid()
  )
);

-- 5. Update active_agents table policy
DROP POLICY IF EXISTS "Clients can view agent locations for their campaigns" ON active_agents;

CREATE POLICY "Simple client agent location access" ON active_agents
FOR SELECT
TO authenticated
USING (
  -- Client can see agent locations for agents in their campaigns
  EXISTS (
    SELECT 1 FROM campaigns c
    JOIN tasks t ON c.id = t.campaign_id  
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE c.client_id = auth.uid()
    AND ta.agent_id = active_agents.user_id
  )
);

-- 6. Verify our new policies
SELECT 'New client policies created' as status,
       tablename,
       policyname,
       cmd
FROM pg_policies 
WHERE policyname ILIKE '%client%'
AND schemaname = 'public'
ORDER BY tablename, policyname;

-- 7. Test if a client user can access data (this will work once you create a client)
-- This query should work for client users:
-- SELECT * FROM campaigns WHERE client_id = auth.uid();