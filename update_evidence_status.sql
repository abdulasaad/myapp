-- Update all existing evidence to approved status
-- This removes the approval workflow and makes all evidence automatically available

UPDATE evidence 
SET status = 'approved'
WHERE status IN ('pending', 'rejected');

-- Check the update results
SELECT 
    status,
    COUNT(*) as count
FROM evidence 
GROUP BY status;