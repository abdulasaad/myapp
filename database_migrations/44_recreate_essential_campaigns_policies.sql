-- Recreate essential campaigns policies after cleanup

-- 1. Check current policies (should be empty or minimal)
SELECT 'Current campaigns policies after cleanup:' as info;
SELECT 
    policyname,
    cmd
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 2. Create essential policies only (non-recursive, clean versions)

-- Admin full access
CREATE POLICY "Admin full access" ON campaigns
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
    )
);

-- Manager SELECT (can see campaigns they created or are assigned to manage)
CREATE POLICY "Manager campaign SELECT" ON campaigns
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'manager'
    ) AND (
        created_by = auth.uid() OR 
        assigned_manager_id = auth.uid()
    )
);

-- Manager INSERT (can create campaigns)
CREATE POLICY "Manager campaign INSERT" ON campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'manager')
    )
);

-- Manager UPDATE (can update their campaigns)
CREATE POLICY "Manager campaign UPDATE" ON campaigns
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'manager')
    ) AND (
        created_by = auth.uid() OR 
        assigned_manager_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'manager')
    )
);

-- Client SELECT (simple, direct check)
CREATE POLICY "Client campaign SELECT" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'client'
    )
);

-- Agent SELECT (through campaign_agents, non-recursive)
CREATE POLICY "Agent campaign SELECT" ON campaigns
FOR SELECT
TO authenticated
USING (
    campaigns.id IN (
        SELECT ca.campaign_id 
        FROM campaign_agents ca
        WHERE ca.agent_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'agent'
    )
);

-- 3. Verify new policies
SELECT 'New campaigns policies created:' as info;
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN length(qual) > 100 THEN left(qual, 100) || '...'
        ELSE qual
    END as qual_preview
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 4. Test basic access (should not cause recursion)
SELECT 'Testing basic campaigns access:' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;

-- 5. Test with auth context (will work when user is authenticated)
SELECT 'Ready for app testing' as status;