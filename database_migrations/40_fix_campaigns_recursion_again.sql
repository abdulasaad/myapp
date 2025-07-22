-- Fix infinite recursion in campaigns policies again

-- 1. Check current campaigns policies
SELECT 'Current campaigns policies causing recursion:' as info;
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;

-- 2. Drop ALL campaigns policies to start clean
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

-- 3. Recreate ONLY essential, non-recursive policies
-- Admin access
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

-- Manager SELECT (can see campaigns they created or are assigned to)
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

-- Agent SELECT (through campaign_agents, but avoid recursion)
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

-- 4. Verify new policies
SELECT 'New campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY policyname;