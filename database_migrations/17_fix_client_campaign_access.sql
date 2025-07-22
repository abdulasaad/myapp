-- Fix client access to campaigns table
-- The issue is that clients can't see their assigned campaigns

-- 1. Check current campaigns policies
SELECT 'Current campaigns policies:' as info;
SELECT policyname, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 2. Check if client can see campaigns at all
SELECT 'Client campaign access test:' as info;
SELECT COUNT(*) as total_campaigns FROM campaigns;
SELECT COUNT(*) as my_campaigns FROM campaigns WHERE client_id = auth.uid();

-- 3. Drop and recreate the client policy with proper access
DROP POLICY IF EXISTS "Client campaign access" ON campaigns;
DROP POLICY IF EXISTS "Client campaign read access" ON campaigns;

-- Create a simple, working client policy
CREATE POLICY "Clients can view assigned campaigns" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
);

-- 4. Test the fix
SELECT 'After policy fix:' as info;
SELECT id, name, client_id FROM campaigns WHERE client_id = auth.uid();

-- 5. Verify the new policy
SELECT 'New campaigns policies:' as info;
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;