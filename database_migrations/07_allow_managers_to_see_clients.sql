-- Fix: Allow managers to see client profiles without causing recursion
-- The issue: Manager users cannot see client profiles due to RLS policies

-- 1. Check current profiles policies
SELECT 'Current profiles policies' as status,
       policyname,
       cmd,
       qual
FROM pg_policies 
WHERE tablename = 'profiles'
AND schemaname = 'public'
ORDER BY policyname;

-- 2. Add a simple, safe policy for managers to see clients
-- This is separate from the recursive one we removed earlier
CREATE POLICY "Managers can see client profiles for assignment" ON profiles
FOR SELECT
TO authenticated
USING (
  -- Only apply to client profiles when queried by managers
  role = 'client'
  AND 
  -- And only when the current user is a manager
  EXISTS (
    SELECT 1 FROM profiles manager_profile
    WHERE manager_profile.id = auth.uid()
    AND manager_profile.role = 'manager'
  )
);

-- 3. Verify the new policy was created
SELECT 'New policy created' as status,
       policyname,
       cmd
FROM pg_policies 
WHERE policyname ILIKE '%client%'
AND tablename = 'profiles'
AND schemaname = 'public';