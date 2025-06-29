-- Step-by-step approach: Create the function in smaller parts

-- Step 1: Drop the function if it exists
DROP FUNCTION IF EXISTS update_agent_name_secure(UUID, TEXT);

-- Step 2: Create a simple test function first to verify syntax
CREATE OR REPLACE FUNCTION test_function()
RETURNS JSON 
LANGUAGE plpgsql 
AS '
BEGIN
    RETURN json_build_object(''test'', true);
END;
';

-- Step 3: Test the simple function
SELECT test_function();

-- Step 4: If the test works, create the actual function
CREATE OR REPLACE FUNCTION update_agent_name_secure(target_user_id UUID, new_full_name TEXT)
RETURNS JSON 
LANGUAGE plpgsql 
SECURITY DEFINER
AS '
BEGIN
    -- Simple validation
    IF auth.uid() IS NULL THEN
        RETURN json_build_object(''success'', false, ''error'', ''Not authenticated'');
    END IF;
    
    -- Update the profile (bypasses RLS due to SECURITY DEFINER)
    UPDATE profiles 
    SET full_name = TRIM(new_full_name), updated_at = NOW()
    WHERE id = target_user_id;
    
    RETURN json_build_object(''success'', true, ''message'', ''Updated'');
END;
';

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION update_agent_name_secure TO authenticated;

-- Step 6: Test the function
SELECT update_agent_name_secure('00000000-0000-0000-0000-000000000000'::UUID, 'Test Name');