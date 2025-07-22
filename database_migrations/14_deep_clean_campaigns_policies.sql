-- Deep clean ALL policies on campaigns table to fix infinite recursion

-- 1. List ALL policies on campaigns table (not just client ones)
SELECT 'ALL campaigns policies:' as info;
SELECT policyname, permissive, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 2. Drop ALL policies on campaigns table to completely reset
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

-- 3. Recreate ONLY the essential policies with simple conditions

-- Admin can see all campaigns
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

-- Manager can see campaigns they created or are assigned to
CREATE POLICY "Manager campaign access" ON campaigns
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

-- Client can ONLY see campaigns where they are the client
CREATE POLICY "Client campaign access" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
);

-- 4. Enable RLS on campaigns if not already enabled
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

-- 5. Verify the new policies
SELECT 'New campaigns policies:' as info;
SELECT policyname, permissive, cmd, qual
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 6. Test client access
SELECT 'Testing client access:' as info;
SELECT COUNT(*) as campaign_count
FROM campaigns 
WHERE client_id = auth.uid();