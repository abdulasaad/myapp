-- Fix status constraint to allow proper user management
-- Run this in your Supabase SQL editor

-- First, check what the current constraint allows
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'profiles' 
  AND n.nspname = 'public'
  AND c.contype = 'c'
  AND conname LIKE '%status%';

-- Check current status values in use
SELECT DISTINCT status, COUNT(*) as count
FROM public.profiles 
WHERE status IS NOT NULL
GROUP BY status
ORDER BY status;

-- Drop the existing status constraint if it exists
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS status_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_check;

-- Create a new constraint that allows the correct status values
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_status_check 
CHECK (status IN ('active', 'offline'));

-- Update any invalid status values to 'offline'
UPDATE public.profiles 
SET status = 'offline' 
WHERE status IS NOT NULL 
  AND status NOT IN ('active', 'offline');

-- Set default status for any NULL values
UPDATE public.profiles 
SET status = 'active' 
WHERE status IS NULL;

-- Make status column NOT NULL with a default
ALTER TABLE public.profiles 
ALTER COLUMN status SET DEFAULT 'active';

ALTER TABLE public.profiles 
ALTER COLUMN status SET NOT NULL;

-- Verify the fix
SELECT DISTINCT status, COUNT(*) as count
FROM public.profiles 
GROUP BY status
ORDER BY status;

SELECT 'Status constraint fixed! Valid values are: active, offline' as result;