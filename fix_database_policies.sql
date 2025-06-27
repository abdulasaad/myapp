-- Drop the problematic RLS policies that are causing infinite recursion
DROP POLICY IF EXISTS "tasks_assigned_manager_access" ON tasks;
DROP POLICY IF EXISTS "campaigns_assigned_manager_access" ON campaigns;

-- The columns and indexes are fine to keep, just removing the conflicting policies
-- Your existing RLS policies should handle access control properly