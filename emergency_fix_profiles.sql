-- EMERGENCY FIX: Remove problematic policies immediately
-- Run this first to restore basic functionality

-- Disable RLS temporarily to fix the issue
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Drop all problematic policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view users in shared groups" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update users in shared groups" ON public.profiles;

-- Re-enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create only basic, safe policies for now
CREATE POLICY "Allow all authenticated users to view profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can update own profile"
ON public.profiles  
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow authenticated users to insert profiles"
ON public.profiles
FOR INSERT  
TO authenticated
WITH CHECK (true);

SELECT 'Emergency fix applied - app should work now!' as result;
SELECT 'Run fix_infinite_recursion.sql next to implement proper group isolation' as next_step;