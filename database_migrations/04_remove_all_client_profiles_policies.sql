-- Emergency Fix: Remove all client-related policies on profiles table
-- This will restore normal agent functionality while we debug the recursion

-- 1. Remove our client policy completely
DROP POLICY IF EXISTS "Clients can read campaign-related profiles" ON profiles;
DROP POLICY IF EXISTS "Clients can read relevant profiles for their campaigns" ON profiles;

-- 2. Verify all remaining policies on profiles
SELECT 'Remaining profiles policies after cleanup' as status,
       policyname,
       cmd
FROM pg_policies 
WHERE tablename = 'profiles'
AND schemaname = 'public'
ORDER BY policyname;

-- 3. Check if there are any other policies that might reference campaigns table
SELECT 'Policies that might cause recursion' as status,
       policyname,
       cmd,
       qual
FROM pg_policies 
WHERE tablename = 'profiles'
AND schemaname = 'public'
AND (qual ILIKE '%campaigns%' OR qual ILIKE '%client%');