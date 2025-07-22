-- Create a function to test client access
-- This can be called from Flutter to debug authentication

CREATE OR REPLACE FUNCTION test_client_access()
RETURNS TABLE (
    test_name text,
    result text
) AS $$
DECLARE
    user_id uuid;
    user_role text;
    campaign_count int;
    agent_count int;
BEGIN
    -- Get current user info
    user_id := auth.uid();
    
    IF user_id IS NULL THEN
        RETURN QUERY SELECT 'Authentication Status'::text, 'NOT AUTHENTICATED - auth.uid() is null'::text;
        RETURN;
    END IF;
    
    -- Get user role
    SELECT role INTO user_role FROM profiles WHERE id = user_id;
    
    RETURN QUERY SELECT 'User ID'::text, user_id::text;
    RETURN QUERY SELECT 'User Role'::text, COALESCE(user_role, 'No role found')::text;
    
    -- Count campaigns
    SELECT COUNT(*) INTO campaign_count 
    FROM campaigns 
    WHERE client_id = user_id;
    
    RETURN QUERY SELECT 'Campaigns Assigned'::text, campaign_count::text;
    
    -- Count agents
    SELECT COUNT(DISTINCT ca.agent_id) INTO agent_count
    FROM campaigns c
    JOIN campaign_agents ca ON ca.campaign_id = c.id
    WHERE c.client_id = user_id;
    
    RETURN QUERY SELECT 'Agents Visible'::text, agent_count::text;
    
    -- Test RLS access
    RETURN QUERY SELECT 'Can Access Campaigns Table'::text, 
        CASE WHEN EXISTS(SELECT 1 FROM campaigns LIMIT 1) 
        THEN 'Yes' ELSE 'No' END::text;
        
    RETURN QUERY SELECT 'Can See My Campaigns'::text,
        CASE WHEN EXISTS(SELECT 1 FROM campaigns WHERE client_id = user_id) 
        THEN 'Yes' ELSE 'No' END::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION test_client_access() TO authenticated;