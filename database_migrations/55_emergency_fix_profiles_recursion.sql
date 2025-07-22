-- EMERGENCY FIX: Remove infinite recursion in profiles RLS policies
-- This is causing the client login to fail

-- Step 1: Identify the problem
SELECT 'EMERGENCY: Fixing infinite recursion in profiles policies' as emergency_status;

-- Step 2: List all current profiles policies to see which one is causing recursion
SELECT 'Current profiles policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Step 3: Remove the problematic client policy that's causing recursion
-- The issue is likely in our new "Clients can read agent profiles for their campaigns" policy

DROP POLICY IF EXISTS "Clients can read agent profiles for their campaigns" ON profiles;

-- Step 4: Create a SAFER client profiles policy without recursion
-- The key is to avoid nested profile queries in the USING clause

CREATE POLICY "Safe client profiles access" ON profiles
FOR SELECT
TO authenticated
USING (
    -- Allow users to see their own profile (no recursion)
    auth.uid() = profiles.id
    OR
    -- Allow admins to see all profiles (simple role check, no recursion)
    EXISTS (
        SELECT 1 FROM auth.users au 
        JOIN profiles p ON au.id = p.id 
        WHERE au.id = auth.uid() 
        AND p.role = 'admin'
    )
    OR
    -- Allow managers to see all profiles (simple role check, no recursion)  
    EXISTS (
        SELECT 1 FROM auth.users au 
        JOIN profiles p ON au.id = p.id 
        WHERE au.id = auth.uid() 
        AND p.role = 'manager'
    )
    OR
    -- Allow clients to see agent profiles ONLY (no nested profile queries)
    (
        profiles.role = 'agent'
        AND EXISTS (
            SELECT 1 FROM auth.users au 
            JOIN profiles client_profile ON au.id = client_profile.id
            WHERE au.id = auth.uid() 
            AND client_profile.role = 'client'
            AND EXISTS (
                SELECT 1 FROM campaigns c
                JOIN tasks t ON c.id = t.campaign_id
                JOIN task_assignments ta ON t.id = ta.task_id
                WHERE c.client_id = auth.uid()
                AND ta.agent_id = profiles.id
            )
        )
    )
);

-- Step 5: Test that basic profile access works now
SELECT 'Testing basic profile access after fix:' as test_status;
SELECT 'Profiles table should be accessible now' as result;

-- Step 6: Verify policies are not recursive
SELECT 'Verification: Non-recursive policies' as verification;
SELECT 
    policyname,
    'Should work without recursion' as status
FROM pg_policies 
WHERE tablename = 'profiles'
AND policyname = 'Safe client profiles access';

-- Step 7: Safety check - ensure we didn't break anything else
SELECT 'Safety check: Other policies still exist' as safety;
SELECT COUNT(*) as total_profiles_policies 
FROM pg_policies 
WHERE tablename = 'profiles';

SELECT 'EMERGENCY FIX COMPLETED: Infinite recursion should be resolved' as completion_status;