-- Final cleanup of remaining duplicate evidence policies

BEGIN;

-- Drop the specific duplicates that are still there
DROP POLICY IF EXISTS "Users can insert
   their own evidence" ON evidence;
DROP POLICY IF EXISTS "Authenticated
  users can view evidence" ON evidence;

-- Verify final policy count after cleanup
SELECT 'FINAL EVIDENCE POLICIES AFTER CLEANUP' as section;
SELECT 
    cmd,
    COUNT(*) as policy_count,
    string_agg(policyname, '; ' ORDER BY policyname) as policies
FROM pg_policies
WHERE tablename = 'evidence'
GROUP BY cmd
ORDER BY cmd;

COMMIT;