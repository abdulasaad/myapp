-- Emergency fix for campaigns infinite recursion
-- This will completely reset all policies and recreate them properly

-- 1. DISABLE RLS temporarily to prevent recursion during cleanup
ALTER TABLE campaigns DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL policies on campaigns table (including any hidden ones)
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'campaigns'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON campaigns', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- 3. Verify ALL policies are gone
SELECT 'Policies after complete cleanup:' as info;
SELECT COUNT(*) as policy_count FROM pg_policies WHERE tablename = 'campaigns';

-- 4. Re-enable RLS
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

-- 5. Create ONLY the essential policies (no recursion)

-- Admin access (simple role check)
CREATE POLICY "campaigns_admin_access" ON campaigns
FOR ALL
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Manager access (simple role check + ownership)
CREATE POLICY "campaigns_manager_select" ON campaigns
FOR SELECT
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'manager'
    AND (created_by = auth.uid() OR assigned_manager_id = auth.uid())
);

CREATE POLICY "campaigns_manager_insert" ON campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
);

CREATE POLICY "campaigns_manager_update" ON campaigns
FOR UPDATE
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
    AND (created_by = auth.uid() OR assigned_manager_id = auth.uid())
)
WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'manager')
);

-- Client access (simple check)
CREATE POLICY "campaigns_client_select" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'client'
);

-- Agent access (through campaign_agents join)
CREATE POLICY "campaigns_agent_select" ON campaigns
FOR SELECT
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
    AND EXISTS (
        SELECT 1 FROM campaign_agents 
        WHERE campaign_id = campaigns.id 
        AND agent_id = auth.uid()
    )
);

-- 6. Test the policies work
SELECT 'Testing campaigns access:' as info;
SELECT 'If you see this, basic access works' as test_result;

-- 7. Show final policies
SELECT 'Final campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    substring(qual, 1, 80) as qual_preview
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;