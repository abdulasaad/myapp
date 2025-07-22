-- EMERGENCY FIX: Restore admin functionality immediately
-- Remove policies that are breaking existing admin/agent features

-- 1. Remove client policies that are causing recursion in tasks table
DROP POLICY IF EXISTS "Simple client task access" ON tasks;

-- 2. Remove client policies that are breaking task_assignments table  
DROP POLICY IF EXISTS "Simple client task assignment access" ON task_assignments;

-- 3. Remove client policies that might affect active_agents
DROP POLICY IF EXISTS "Simple client agent location access" ON active_agents;

-- 4. Keep ONLY the campaigns policy which is safe and essential
-- This is the minimal client access - they can see their campaigns only
-- DROP POLICY IF EXISTS "Simple client campaign access" ON campaigns; -- KEEP THIS ONE

-- 5. Verify what policies remain
SELECT 'Remaining client policies' as status,
       tablename,
       policyname,
       cmd
FROM pg_policies 
WHERE policyname ILIKE '%client%'
AND schemaname = 'public';

-- 6. Verify admin functionality should work now
SELECT 'Admin should be able to access these tables now' as status,
       tablename,
       COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename IN ('tasks', 'task_assignments', 'active_agents')
AND schemaname = 'public'
GROUP BY tablename;

-- NOTE: With this fix:
-- - Admins/Agents: Full functionality restored
-- - Clients: Can see their campaigns only (limited access)
-- - We can add more client access later CAREFULLY without breaking existing features