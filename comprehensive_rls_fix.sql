-- Comprehensive RLS fix for profiles table
-- This will completely reset and rebuild the RLS policies to avoid any recursion

-- Step 1: Disable RLS temporarily to clean up
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies on profiles table
DO $$ 
DECLARE 
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'profiles' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON profiles';
    END LOOP;
END $$;

-- Step 3: Create helper function for permission checks (with better error handling)
CREATE OR REPLACE FUNCTION check_profile_update_permission(target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    has_shared_group BOOLEAN := FALSE;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- If no authenticated user, deny access
    IF current_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- User can always update their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role (avoid recursion by using direct query)
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id
    LIMIT 1;
    
    -- If we can't find the current user's role, deny access
    IF current_user_role IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Admins can update any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Only managers can update other users' profiles
    IF current_user_role != 'manager' THEN
        RETURN FALSE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id
    LIMIT 1;
    
    -- Managers can only update agents
    IF target_user_role != 'agent' THEN
        RETURN FALSE;
    END IF;
    
    -- Check if manager and agent share at least one group
    SELECT EXISTS (
        SELECT 1 
        FROM user_groups ug_manager
        INNER JOIN user_groups ug_agent 
        ON ug_manager.group_id = ug_agent.group_id
        WHERE ug_manager.user_id = current_user_id
        AND ug_agent.user_id = target_user_id
    ) INTO has_shared_group;
    
    RETURN has_shared_group;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Step 4: Create separate, simple policies for each operation

-- SELECT policy (for viewing profiles)
CREATE POLICY "profiles_select_policy" ON profiles
FOR SELECT 
USING (
    -- Users can view their own profile
    auth.uid() = id
    OR
    -- Or check permission via function for viewing others
    check_profile_update_permission(id)
);

-- UPDATE policy (for updating profiles)
CREATE POLICY "profiles_update_policy" ON profiles
FOR UPDATE 
USING (check_profile_update_permission(id))
WITH CHECK (check_profile_update_permission(id));

-- INSERT policy (for creating profiles - typically done by admins only)
CREATE POLICY "profiles_insert_policy" ON profiles
FOR INSERT 
WITH CHECK (
    -- Only allow if user is admin or inserting their own profile
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
    )
    OR auth.uid() = id
);

-- DELETE policy (typically not used, but for completeness)
CREATE POLICY "profiles_delete_policy" ON profiles
FOR DELETE 
USING (
    -- Only admins can delete profiles
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
    )
);

-- Step 5: Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Step 6: Grant necessary permissions
GRANT EXECUTE ON FUNCTION check_profile_update_permission TO authenticated;
GRANT EXECUTE ON FUNCTION check_profile_update_permission TO service_role;

-- Step 7: Test the setup with a verification query
-- (This should return true/false without errors)
SELECT check_profile_update_permission('00000000-0000-0000-0000-000000000000'::UUID) as test_result;

-- Verification: Check that policies are properly created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles' 
ORDER BY policyname;