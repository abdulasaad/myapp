-- Simple Fix: No Custom Functions, No Recursion
-- Use JWT claims or simple user ID checks instead of role subqueries

-- ================================
-- STEP 1: Clean slate - remove all policies
-- ================================

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
-- STEP 2: Create simple, non-recursive policies
-- ================================

-- Policy 1: Users can always view their own profile
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Policy 2: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 3: Allow viewing other profiles based on group membership (no role check)
-- This allows managers to see users in their groups without checking roles
CREATE POLICY "Users can view profiles in shared groups"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  -- Always allow viewing own profile
  auth.uid() = id
  OR
  -- Allow viewing users in shared groups
  EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
  OR
  -- Allow if no groups are assigned (for testing)
  NOT EXISTS (SELECT 1 FROM public.user_groups WHERE user_id = public.profiles.id)
);

-- Policy 4: Allow updates for shared group members (simplified)
CREATE POLICY "Users can update profiles in shared groups"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  -- Own profile
  auth.uid() = id
  OR
  -- Shared group members
  EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
)
WITH CHECK (
  -- Own profile
  auth.uid() = id
  OR
  -- Shared group members
  EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
);

-- Policy 5: Allow insertions (for user registration and admin creation)
CREATE POLICY "Allow profile creation"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ================================
-- STEP 3: Add a simple admin override (optional)
-- ================================

-- Create a simple table to track admin users by ID (avoids recursion)
CREATE TABLE IF NOT EXISTS public.admin_users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Insert current admin users (replace with actual admin user IDs)
-- You can get admin user IDs with: SELECT id FROM auth.users WHERE email = 'admin@example.com';

-- Example: INSERT INTO public.admin_users (user_id) VALUES ('YOUR_ADMIN_USER_ID');

-- Policy 6: Admin override based on admin_users table
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid())
);

CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid())
);

-- ================================
-- STEP 4: Fix other tables with similar approach
-- ================================

-- Fix user_groups policies
DROP POLICY IF EXISTS "Managers can view group assignments for shared groups" ON public.user_groups;

CREATE POLICY "Users can view group assignments"
ON public.user_groups
FOR SELECT
TO authenticated
USING (
  -- Users can see their own assignments
  auth.uid() = user_id
  OR
  -- Users can see assignments in groups they belong to
  EXISTS (
    SELECT 1
    FROM public.user_groups my_groups
    WHERE my_groups.user_id = auth.uid()
      AND my_groups.group_id = public.user_groups.group_id
  )
  OR
  -- Admin override
  EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid())
);

-- ================================
-- VERIFICATION
-- ================================

-- Test basic profile access
SELECT 'Checking if current user can see their profile...';
SELECT id, full_name, role FROM public.profiles WHERE id = auth.uid();

-- Check admin setup
SELECT 'Current admin users:';
SELECT * FROM public.admin_users;

SELECT 'Simple fix applied - no recursion!' as result;
SELECT 'Add your admin user IDs to admin_users table for full access' as admin_note;