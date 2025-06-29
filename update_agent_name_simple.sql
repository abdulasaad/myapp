-- Simple SQL function for Supabase SQL Editor without dollar quoting
-- Create a database function to update agent names securely

CREATE OR REPLACE FUNCTION update_agent_name_secure(
    target_user_id UUID,
    new_full_name TEXT
)
RETURNS JSON 
LANGUAGE plpgsql 
SECURITY DEFINER
AS '
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    has_shared_group BOOLEAN := FALSE;
    rows_updated INTEGER;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- Validate inputs
    IF current_user_id IS NULL THEN
        RETURN json_build_object(
            ''success'', false,
            ''error'', ''User not authenticated''
        );
    END IF;
    
    IF target_user_id IS NULL OR new_full_name IS NULL OR LENGTH(TRIM(new_full_name)) < 2 THEN
        RETURN json_build_object(
            ''success'', false,
            ''error'', ''Invalid input parameters''
        );
    END IF;
    
    -- Get current user role
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id;
    
    IF current_user_role IS NULL THEN
        RETURN json_build_object(
            ''success'', false,
            ''error'', ''Current user profile not found''
        );
    END IF;
    
    -- Check if user can update (self, or admin, or manager for agent in same group)
    IF current_user_id = target_user_id THEN
        -- User updating their own profile
        has_shared_group := TRUE;
    ELSIF current_user_role = ''admin'' THEN
        -- Admin can update anyone
        has_shared_group := TRUE;
    ELSIF current_user_role = ''manager'' THEN
        -- Manager updating agent in their group
        
        -- First check if target is an agent
        SELECT role INTO target_user_role
        FROM profiles
        WHERE id = target_user_id;
        
        IF target_user_role != ''agent'' THEN
            RETURN json_build_object(
                ''success'', false,
                ''error'', ''Managers can only update agent profiles''
            );
        END IF;
        
        -- Check if they share a group
        SELECT EXISTS (
            SELECT 1 
            FROM user_groups ug_manager
            INNER JOIN user_groups ug_agent 
            ON ug_manager.group_id = ug_agent.group_id
            WHERE ug_manager.user_id = current_user_id
            AND ug_agent.user_id = target_user_id
        ) INTO has_shared_group;
        
        IF NOT has_shared_group THEN
            RETURN json_build_object(
                ''success'', false,
                ''error'', ''Cannot update agent outside your groups''
            );
        END IF;
    ELSE
        RETURN json_build_object(
            ''success'', false,
            ''error'', ''Insufficient permissions''
        );
    END IF;
    
    -- Perform the update (this bypasses RLS since function is SECURITY DEFINER)
    UPDATE profiles 
    SET 
        full_name = TRIM(new_full_name),
        updated_at = NOW()
    WHERE id = target_user_id;
    
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    
    IF rows_updated = 0 THEN
        RETURN json_build_object(
            ''success'', false,
            ''error'', ''User not found or no changes made''
        );
    END IF;
    
    RETURN json_build_object(
        ''success'', true,
        ''message'', ''Profile updated successfully''
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            ''success'', false,
            ''error'', SQLERRM
        );
END;
';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_agent_name_secure TO authenticated;