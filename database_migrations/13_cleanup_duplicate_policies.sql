-- Cleanup duplicate and conflicting policies

-- 1. Show all policies on campaigns table
SELECT 'All campaigns policies before cleanup:' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 2. Drop ALL client-related policies on campaigns to start fresh
DROP POLICY IF EXISTS "Clients can view their assigned campaigns" ON campaigns;
DROP POLICY IF EXISTS "Simple client campaign access" ON campaigns;
DROP POLICY IF EXISTS "Enable read access for clients on campaigns" ON campaigns;
DROP POLICY IF EXISTS "Clients can view campaigns assigned to them" ON campaigns;

-- 3. Create ONE simple policy for clients
CREATE POLICY "Client campaign read access" ON campaigns
FOR SELECT
TO authenticated
USING (
    client_id = auth.uid()
);

-- 4. Verify only one client policy exists now
SELECT 'Campaigns policies after cleanup:' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'campaigns' 
ORDER BY policyname;

-- 5. Test the access (run this as a client user to verify)
-- This should return the campaigns assigned to the client
SELECT 'Testing client access to campaigns:' as info;
SELECT id, name, client_id 
FROM campaigns 
WHERE client_id = auth.uid()
LIMIT 5;