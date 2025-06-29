-- Simplified RLS fix for profiles table to avoid infinite recursion
-- This approach uses a database function to check permissions

-- First, create a helper function to check if a user can update another user's profile
CREATE OR REPLACE FUNCTION can_update_profile(target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    shares_group BOOLEAN;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- User can always update their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id;
    
    -- Admins can update any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Only managers can update other profiles
    IF current_user_role != 'manager' THEN
        RETURN FALSE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id;
    
    -- Managers can only update agents
    IF target_user_role != 'agent' THEN
        RETURN FALSE;
    END IF;
    
    -- Check if manager and agent share at least one group
    SELECT EXISTS (
        SELECT 1 
        FROM user_groups ug1
        JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
        WHERE ug1.user_id = current_user_id
        AND ug2.user_id = target_user_id
    ) INTO shares_group;
    
    RETURN shares_group;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing UPDATE policies
DROP POLICY IF EXISTS "Enable profile updates based on role" ON profiles;
DROP POLICY IF EXISTS "Managers can update agent profiles in their groups" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

-- Create a simple UPDATE policy using the function
CREATE POLICY "Profile update policy" ON profiles
FOR UPDATE 
USING (can_update_profile(id))
WITH CHECK (can_update_profile(id));

-- Optional: Grant execute permission on the function to authenticated users
GRANT EXECUTE ON FUNCTION can_update_profile TO authenticated;

-- Test query to verify it works:
/*
-- As a manager, try to update an agent's name in your group
UPDATE profiles 
SET full_name = 'Updated Name', 
    updated_at = NOW()
WHERE id = 'AGENT_USER_ID';
*/