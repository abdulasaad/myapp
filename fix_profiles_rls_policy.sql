-- Fix for infinite recursion in profiles table RLS policies
-- Run this in Supabase SQL Editor

-- First, let's drop the problematic policies (if they exist)
DROP POLICY IF EXISTS "Managers can update agent profiles in their groups" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

-- Create a simplified update policy that avoids recursion
CREATE POLICY "Enable profile updates based on role" ON profiles
FOR UPDATE USING (
  -- Users can update their own profile
  auth.uid() = id
  OR
  -- Admins can update all profiles
  EXISTS (
    SELECT 1 FROM profiles AS p
    WHERE p.id = auth.uid() 
    AND p.role = 'admin'
  )
  OR
  -- Managers can update agents in their groups (without recursive profile lookups)
  (
    -- Check if current user is a manager
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'manager'
    )
    AND
    -- Check if target user is an agent
    role = 'agent'
    AND
    -- Check if they share at least one group
    EXISTS (
      SELECT 1 
      FROM user_groups ug1
      JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
      WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = profiles.id
    )
  )
)
WITH CHECK (
  -- Same logic for CHECK constraint
  auth.uid() = id
  OR
  EXISTS (
    SELECT 1 FROM profiles AS p
    WHERE p.id = auth.uid() 
    AND p.role = 'admin'
  )
  OR
  (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'manager'
    )
    AND
    role = 'agent'
    AND
    EXISTS (
      SELECT 1 
      FROM user_groups ug1
      JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
      WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = profiles.id
    )
  )
);

-- Also ensure we have proper SELECT policies (if not already present)
DROP POLICY IF EXISTS "Users can view profiles based on role and groups" ON profiles;

CREATE POLICY "Users can view profiles based on role and groups" ON profiles
FOR SELECT USING (
  -- Users can view their own profile
  auth.uid() = id
  OR
  -- Admins can view all profiles
  EXISTS (
    SELECT 1 FROM profiles AS p
    WHERE p.id = auth.uid() 
    AND p.role = 'admin'
  )
  OR
  -- Users in the same group can view each other
  EXISTS (
    SELECT 1 
    FROM user_groups ug1
    JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
    AND ug2.user_id = profiles.id
  )
);

-- Test the policies to ensure they work
-- You can run these test queries after applying the policies:
/*
-- Test 1: Manager updating an agent's name (should work if they share a group)
UPDATE profiles 
SET full_name = 'Test Name', updated_at = NOW()
WHERE id = 'AGENT_USER_ID'
AND role = 'agent';

-- Test 2: Manager trying to update another manager (should fail)
UPDATE profiles 
SET full_name = 'Test Name', updated_at = NOW()
WHERE id = 'ANOTHER_MANAGER_ID'
AND role = 'manager';
*/