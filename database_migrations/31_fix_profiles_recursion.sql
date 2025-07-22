-- Fix infinite recursion in profiles policies
-- The new manager-client policy is conflicting with existing ones

-- 1. Drop the problematic policy I just added
DROP POLICY IF EXISTS "Managers can view clients for assignment" ON profiles;

-- 2. Instead, modify the existing permission function to ensure it works
-- The function already has the logic, but let's make sure it's working correctly

-- 3. Check current policies
SELECT 'Current profiles policies after cleanup:' as info;
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- 4. Test if manager can see clients with the existing function
-- (This should be run as a manager user)
SELECT 'Test manager access to clients:' as info;
SELECT 
    id,
    full_name,
    role,
    email
FROM profiles
WHERE role = 'client';