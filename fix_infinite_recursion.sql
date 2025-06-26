-- Fix Infinite Recursion in Profiles RLS Policies
-- The issue is policies that reference profiles table within profiles table policies

-- ================================
-- STEP 1: Remove all problematic policies
-- ================================

-- Drop all existing policies on profiles table to start fresh
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view users in shared groups" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update users in shared groups" ON public.profiles;

-- ================================
-- STEP 2: Create simple, non-recursive policies
-- ================================

-- Basic policy: Users can always view their own profile
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Basic policy: Users can update their own profile  
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ================================
-- STEP 3: Create a function to check user role (avoids recursion)
-- ================================

-- Create a function that safely gets the current user's role
CREATE OR REPLACE FUNCTION auth.get_user_role()
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Get the role directly without RLS policies interfering
    SELECT role INTO user_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    RETURN COALESCE(user_role, 'guest');
END;
$$;

-- ================================
-- STEP 4: Create admin policies using the function
-- ================================

-- Admin policy: Uses function instead of subquery
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.get_user_role() = 'admin');

CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.get_user_role() = 'admin')
WITH CHECK (auth.get_user_role() = 'admin');

CREATE POLICY "Admins can insert profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.get_user_role() = 'admin');

-- ================================
-- STEP 5: Create manager policies with group isolation
-- ================================

-- Manager policy: Can view users in shared groups
CREATE POLICY "Managers can view users in shared groups"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  auth.get_user_role() = 'manager'
  AND EXISTS (
    -- Check if the target user shares any group with the manager
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()  -- Manager's groups
      AND ug2.user_id = public.profiles.id  -- Target user's groups
  )
);

-- Manager policy: Can update users in shared groups (basic info only)
CREATE POLICY "Managers can update users in shared groups"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  auth.get_user_role() = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
)
WITH CHECK (
  auth.get_user_role() = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
);

-- ================================
-- STEP 6: Fix other tables that might have similar issues
-- ================================

-- Check and fix user_groups policies
DROP POLICY IF EXISTS "Managers can view group assignments for shared groups" ON public.user_groups;

CREATE POLICY "Managers can view group assignments for shared groups"
ON public.user_groups
FOR SELECT
TO authenticated
USING (
  -- Admins see all
  auth.get_user_role() = 'admin'
  OR
  -- Users see their own assignments
  auth.uid() = user_id
  OR
  -- Managers see assignments in groups they belong to
  (
    auth.get_user_role() = 'manager'
    AND EXISTS (
      SELECT 1
      FROM public.user_groups manager_groups
      WHERE manager_groups.user_id = auth.uid()
        AND manager_groups.group_id = public.user_groups.group_id
    )
  )
);

-- ================================
-- STEP 7: Grant execute permission on the function
-- ================================

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.get_user_role() TO authenticated;

-- ================================
-- VERIFICATION
-- ================================

-- Test the function
SELECT auth.get_user_role() as current_user_role;

-- Test a simple profile query
SELECT id, full_name, role FROM public.profiles WHERE id = auth.uid();

SELECT 'Infinite recursion fixed!' as result;
SELECT 'Profiles table should now work without recursion errors' as info;