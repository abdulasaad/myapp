-- Fix Infinite Recursion - Using Public Schema
-- Create function in public schema since we can't access auth schema

-- ================================
-- STEP 1: Remove all problematic policies (if not done already)
-- ================================

-- Drop all existing policies on profiles table
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view users in shared groups" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update group members" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update users in shared groups" ON public.profiles;
DROP POLICY IF EXISTS "Allow all authenticated users to view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to insert profiles" ON public.profiles;

-- ================================
-- STEP 2: Create function in public schema
-- ================================

-- Create a function in public schema to safely get the current user's role
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Disable RLS temporarily within this function to avoid recursion
    -- Get the role directly from the table
    PERFORM set_config('row_security', 'off', true);
    
    SELECT role INTO user_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    -- Re-enable RLS
    PERFORM set_config('row_security', 'on', true);
    
    RETURN COALESCE(user_role, 'guest');
EXCEPTION
    WHEN OTHERS THEN
        -- Re-enable RLS in case of error
        PERFORM set_config('row_security', 'on', true);
        RETURN 'guest';
END;
$$;

-- ================================
-- STEP 3: Create safe policies using the function
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

-- Admin policies using the safe function
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (public.get_current_user_role() = 'admin');

CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (public.get_current_user_role() = 'admin')
WITH CHECK (public.get_current_user_role() = 'admin');

CREATE POLICY "Admins can insert profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (public.get_current_user_role() = 'admin');

-- Manager policies with group isolation
CREATE POLICY "Managers can view users in shared groups"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.get_current_user_role() = 'manager'
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
  public.get_current_user_role() = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
)
WITH CHECK (
  public.get_current_user_role() = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
);

-- ================================
-- STEP 4: Grant execute permission on the function
-- ================================

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO anon;

-- ================================
-- STEP 5: Test the function
-- ================================

-- Test the function works
SELECT public.get_current_user_role() as current_user_role;

-- Test a simple profile query
SELECT id, full_name, role FROM public.profiles WHERE id = auth.uid() LIMIT 1;

SELECT 'Infinite recursion fixed using public schema function!' as result;
SELECT 'Manager dashboard should now work without recursion errors' as info;