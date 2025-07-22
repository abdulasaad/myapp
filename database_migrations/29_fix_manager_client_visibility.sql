-- Fix manager ability to see client users for assignment
-- Managers need to see clients to assign them to campaigns

-- 1. Check current profiles policies
SELECT 'Current profiles policies:' as info;
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- 2. Add policy to allow managers to see client users
CREATE POLICY "Managers can view clients for assignment" ON profiles
FOR SELECT
TO authenticated
USING (
    -- Allow managers to see client users for campaign assignment
    EXISTS (
        SELECT 1 FROM profiles manager_profile
        WHERE manager_profile.id = auth.uid()
        AND manager_profile.role = 'manager'
    ) AND profiles.role = 'client'
);

-- 3. Verify the new policy
SELECT 'Updated profiles policies:' as info;
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- 4. Test manager can see clients
SELECT 'Test query - all clients:' as info;
SELECT id, full_name, role, email
FROM profiles 
WHERE role = 'client';