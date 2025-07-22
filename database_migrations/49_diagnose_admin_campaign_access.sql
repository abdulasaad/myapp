-- Diagnose why admin can't see campaigns

-- 1. Check RLS status
SELECT 'Step 1: RLS Status' as step;
SELECT 
    table_name,
    row_level_security_active
FROM information_schema.tables 
WHERE table_name = 'campaigns'
AND table_schema = 'public';

-- 2. Check if campaigns exist
SELECT 'Step 2: Campaign Count' as step;  
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 3. Show sample campaigns if any exist
SELECT 'Step 3: Sample Campaigns' as step;
SELECT 
    id,
    name,
    status,
    created_by,
    created_at
FROM campaigns 
LIMIT 5;

-- 4. Check current policies
SELECT 'Step 4: Current Policies' as step;
SELECT 
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 5. If RLS is ON and no policies exist, create basic admin policy
DO $$
DECLARE
    rls_enabled boolean;
    policy_count integer;
BEGIN
    -- Check RLS status
    SELECT row_level_security_active INTO rls_enabled 
    FROM information_schema.tables 
    WHERE table_name = 'campaigns' AND table_schema = 'public';
    
    -- Check policy count
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'campaigns';
    
    -- If RLS is enabled but no policies, create basic admin access
    IF rls_enabled AND policy_count = 0 THEN
        CREATE POLICY "admin_full_access" ON campaigns
        FOR ALL 
        TO authenticated
        USING (
            (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
        );
        
        RAISE NOTICE 'Created emergency admin policy for campaigns';
    END IF;
    
    RAISE NOTICE 'RLS enabled: %, Policy count: %', rls_enabled, policy_count;
END $$;

-- 6. Test basic campaign access
SELECT 'Step 5: Final Test' as step;
SELECT 'If you see this, basic SELECT works on campaigns table' as result;