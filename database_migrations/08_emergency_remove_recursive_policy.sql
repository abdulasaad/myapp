-- EMERGENCY: Remove the recursive policy immediately

-- 1. Drop the problematic policy
DROP POLICY IF EXISTS "Managers can see client profiles for assignment" ON profiles;

-- 2. Verify it's removed
SELECT 'Policies after cleanup' as status,
       policyname,
       cmd
FROM pg_policies 
WHERE tablename = 'profiles'
AND schemaname = 'public'
ORDER BY policyname;

-- 3. Alternative approach: Instead of adding profiles policies, 
-- let's modify the existing policies to be more permissive for managers
-- But first, let's see what the existing policies look like:

SELECT 'Current profiles policies detail' as status,
       policyname,
       cmd,
       qual
FROM pg_policies 
WHERE tablename = 'profiles'
AND schemaname = 'public'
AND policyname = 'profiles_select_policy';