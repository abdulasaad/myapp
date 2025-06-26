-- Check the status constraint on profiles table
-- Run this in your Supabase SQL editor to see what status values are allowed

-- Check existing check constraints on profiles table
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'profiles' 
  AND n.nspname = 'public'
  AND c.contype = 'c';

-- Check what status values currently exist in the database
SELECT DISTINCT status, COUNT(*) as count
FROM public.profiles 
WHERE status IS NOT NULL
GROUP BY status
ORDER BY status;

-- Check the table definition
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'status';

SELECT 'Status constraint check completed' as result;