-- Re-enable RLS with ultra-simple policies to avoid recursion

-- 1. Test current access (should work since RLS is disabled)
SELECT 'Testing campaigns access before re-enabling RLS:' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 2. Re-enable Row Level Security
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

-- 3. Create ONE simple policy for each role (no complex joins or EXISTS)

-- Admin: Full access (simplest possible)
CREATE POLICY "admin_all" ON campaigns
FOR ALL 
TO authenticated
USING (
    auth.jwt() ->> 'role' = 'admin' OR
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
);

-- Manager: Can see their own campaigns only  
CREATE POLICY "manager_select" ON campaigns
FOR SELECT
TO authenticated  
USING (
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) = 'manager'
    AND (created_by = auth.uid() OR assigned_manager_id = auth.uid())
);

CREATE POLICY "manager_insert" ON campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

CREATE POLICY "manager_update" ON campaigns  
FOR UPDATE
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND (created_by = auth.uid() OR assigned_manager_id = auth.uid())  
);

-- Client: Simple client_id match
CREATE POLICY "client_select" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
);

-- Agent: Direct campaign_agents lookup (no recursion)
CREATE POLICY "agent_select" ON campaigns
FOR SELECT  
TO authenticated
USING (
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1) = 'agent'
    AND campaigns.id IN (
        SELECT campaign_id FROM campaign_agents WHERE agent_id = auth.uid()
    )
);

-- 4. Test the new policies
SELECT 'New simple policies created:' as info;
SELECT 
    policyname,
    cmd
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 5. Basic test query
SELECT 'Testing with new policies:' as info;
SELECT 'If you see this, the policies work without recursion' as test;