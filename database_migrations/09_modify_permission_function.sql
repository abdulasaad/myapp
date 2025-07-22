-- Safe Fix: Modify the existing permission function to allow managers to see clients
-- This avoids adding new policies and uses the existing safe structure

-- 1. First, let's see the current function
SELECT 'Current permission function' as status,
       routine_definition
FROM information_schema.routines 
WHERE routine_name = 'check_profile_update_permission'
AND routine_schema = 'public';

-- 2. We need to update this function to allow managers to VIEW clients
-- The function currently handles UPDATE permissions, but the SELECT policy uses it too
-- Let's create a new function specifically for SELECT permissions

CREATE OR REPLACE FUNCTION check_profile_select_permission(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    
    -- User can always view their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role (direct query, no recursion)
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id
    LIMIT 1;
    
    -- If we can't find the current user's role, deny access
    IF current_user_role IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Admins can view any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id
    LIMIT 1;
    
    -- Managers can view clients (this is the key addition)
    IF current_user_role = 'manager' AND target_user_role = 'client' THEN
        RETURN TRUE;
    END IF;
    
    -- For other cases, managers can only view agents in shared groups
    IF current_user_role = 'manager' AND target_user_role = 'agent' THEN
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
    END IF;
    
    -- For all other roles/combinations, deny access
    RETURN FALSE;
END;
$$;

-- 3. Update the profiles_select_policy to use the new function
DROP POLICY IF EXISTS "profiles_select_policy" ON profiles;

CREATE POLICY "profiles_select_policy" ON profiles
FOR SELECT
TO authenticated
USING (check_profile_select_permission(id));

-- 4. Verify the changes
SELECT 'Updated policy' as status,
       policyname,
       cmd,
       qual
FROM pg_policies 
WHERE tablename = 'profiles'
AND policyname = 'profiles_select_policy';