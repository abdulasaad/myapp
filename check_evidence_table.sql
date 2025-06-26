-- Check the structure of the evidence table
-- Run this to see what columns actually exist

SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'evidence' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Also check a sample row to see the structure
SELECT * FROM public.evidence LIMIT 1;