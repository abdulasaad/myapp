-- Add missing INSERT policy for managers to create campaigns

-- 1. Add INSERT policy for managers
CREATE POLICY "Managers can create campaigns" ON campaigns
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'manager')
    )
);

-- 2. Add UPDATE policy for managers to edit their campaigns
CREATE POLICY "Managers can update campaigns" ON campaigns
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

-- 3. Verify the new policies
SELECT 'Updated campaigns policies:' as info;
SELECT 
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies 
WHERE tablename = 'campaigns'
ORDER BY cmd, policyname;

-- 4. Clean up the test campaign
DELETE FROM campaigns 
WHERE name = 'Test Campaign INSERT';