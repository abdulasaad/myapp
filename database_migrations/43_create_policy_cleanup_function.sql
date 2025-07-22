-- Create a function to clean up campaigns policies and fix infinite recursion

-- 1. Create the cleanup function
CREATE OR REPLACE FUNCTION clean_campaigns_policies()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Drop all potentially conflicting policies by exact name
    DROP POLICY IF EXISTS "Agents can view assigned campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Clients can view their campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign access" ON campaigns;
    DROP POLICY IF EXISTS "Managers can create campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Managers can update campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Agent campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Client campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign INSERT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign UPDATE" ON campaigns;
    DROP POLICY IF EXISTS "Admin full access" ON campaigns;
    
    -- Return success message
    RETURN 'Campaigns policies cleaned successfully';
END;
$$;

-- 2. Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION clean_campaigns_policies() TO authenticated;

-- 3. Test the function
SELECT clean_campaigns_policies();

-- 4. Check what policies remain (should only be the good ones from migration #40)
SELECT 'Remaining campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;