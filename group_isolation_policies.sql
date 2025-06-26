-- Comprehensive Group-Based Isolation Policies
-- This ensures managers only see users, campaigns, and tasks within their assigned groups

-- ================================
-- PROFILES TABLE - Manager can only see users in shared groups
-- ================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view group members" ON public.profiles;

-- Create comprehensive profile policies
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can view users in shared groups"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    -- Check if the target user shares any group with the manager
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()  -- Manager's groups
      AND ug2.user_id = public.profiles.id  -- Target user's groups
  )
);

-- ================================
-- USER_GROUPS TABLE - Enhanced policies
-- ================================

DROP POLICY IF EXISTS "Managers can view users in their default group" ON public.user_groups;
DROP POLICY IF EXISTS "Managers can view group assignments" ON public.user_groups;

CREATE POLICY "Managers can view group assignments for shared groups"
ON public.user_groups
FOR SELECT
TO authenticated
USING (
  -- Admins see all
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  OR
  -- Users see their own assignments
  auth.uid() = user_id
  OR
  -- Managers see assignments in groups they belong to
  (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
    AND EXISTS (
      SELECT 1
      FROM public.user_groups manager_groups
      WHERE manager_groups.user_id = auth.uid()
        AND manager_groups.group_id = public.user_groups.group_id
    )
  )
);

-- ================================
-- CAMPAIGNS TABLE - Manager isolation
-- ================================

-- Enable RLS on campaigns if not already enabled
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Managers can view own campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "Managers can view group campaigns" ON public.campaigns;
DROP POLICY IF EXISTS "Admins can view all campaigns" ON public.campaigns;

CREATE POLICY "Admins can manage all campaigns"
ON public.campaigns
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can manage campaigns in their groups"
ON public.campaigns
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND (
    -- Manager created the campaign
    created_by = auth.uid()
    OR
    -- Campaign involves groups that the manager belongs to
    EXISTS (
      SELECT 1
      FROM public.user_groups ug
      WHERE ug.user_id = auth.uid()
        AND ug.group_id = ANY(
          -- Get groups involved in this campaign (need to define this based on your schema)
          SELECT DISTINCT ug2.group_id
          FROM public.task_assignments ta
          JOIN public.user_groups ug2 ON ta.agent_id = ug2.user_id
          WHERE ta.task_id IN (
            SELECT id FROM public.tasks WHERE campaign_id = public.campaigns.id
          )
        )
    )
  )
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
);

-- ================================
-- TASKS TABLE - Manager isolation
-- ================================

-- Enable RLS on tasks if not already enabled
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Managers can view own tasks" ON public.tasks;
DROP POLICY IF EXISTS "Managers can view group tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins can view all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Agents can view assigned tasks" ON public.tasks;

CREATE POLICY "Admins can manage all tasks"
ON public.tasks
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can manage tasks in their groups"
ON public.tasks
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND (
    -- Manager created the task
    created_by = auth.uid()
    OR
    -- Task is assigned to agents in manager's groups
    EXISTS (
      SELECT 1
      FROM public.task_assignments ta
      JOIN public.user_groups ug ON ta.agent_id = ug.user_id
      JOIN public.user_groups manager_ug ON ug.group_id = manager_ug.group_id
      WHERE ta.task_id = public.tasks.id
        AND manager_ug.user_id = auth.uid()
    )
  )
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
);

CREATE POLICY "Agents can view assigned tasks"
ON public.tasks
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND EXISTS (
    SELECT 1
    FROM public.task_assignments ta
    WHERE ta.task_id = public.tasks.id
      AND ta.agent_id = auth.uid()
  )
);

-- ================================
-- TASK_ASSIGNMENTS TABLE - Manager isolation
-- ================================

-- Enable RLS on task_assignments if not already enabled
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Managers can view group task assignments" ON public.task_assignments;
DROP POLICY IF EXISTS "Agents can view own assignments" ON public.task_assignments;
DROP POLICY IF EXISTS "Admins can view all assignments" ON public.task_assignments;

CREATE POLICY "Admins can manage all task assignments"
ON public.task_assignments
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can manage assignments in their groups"
ON public.task_assignments
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    -- Agent being assigned is in a group shared with the manager
    SELECT 1
    FROM public.user_groups agent_ug
    JOIN public.user_groups manager_ug ON agent_ug.group_id = manager_ug.group_id
    WHERE agent_ug.user_id = public.task_assignments.agent_id
      AND manager_ug.user_id = auth.uid()
  )
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    -- Can only assign to agents in shared groups
    SELECT 1
    FROM public.user_groups agent_ug
    JOIN public.user_groups manager_ug ON agent_ug.group_id = manager_ug.group_id
    WHERE agent_ug.user_id = public.task_assignments.agent_id
      AND manager_ug.user_id = auth.uid()
  )
);

CREATE POLICY "Agents can view own task assignments"
ON public.task_assignments
FOR SELECT
TO authenticated
USING (
  auth.uid() = agent_id
);

-- ================================
-- EVIDENCE TABLE - Manager isolation (FIXED)
-- ================================

-- Enable RLS on evidence if not already enabled
ALTER TABLE public.evidence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Managers can view group evidence" ON public.evidence;
DROP POLICY IF EXISTS "Agents can view own evidence" ON public.evidence;
DROP POLICY IF EXISTS "Admins can view all evidence" ON public.evidence;
DROP POLICY IF EXISTS "Managers can view evidence from their group agents" ON public.evidence;
DROP POLICY IF EXISTS "Agents can manage own evidence" ON public.evidence;
DROP POLICY IF EXISTS "Admins can manage all evidence" ON public.evidence;

CREATE POLICY "Admins can manage all evidence"
ON public.evidence
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can view evidence from their group agents"
ON public.evidence
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    -- Evidence submitted by agents in manager's groups via uploader_id
    SELECT 1
    FROM public.user_groups uploader_ug
    JOIN public.user_groups manager_ug ON uploader_ug.group_id = manager_ug.group_id
    WHERE uploader_ug.user_id = public.evidence.uploader_id
      AND manager_ug.user_id = auth.uid()
    
    UNION
    
    -- Evidence for tasks assigned to agents in manager's groups
    SELECT 1
    FROM public.task_assignments ta
    JOIN public.user_groups agent_ug ON ta.agent_id = agent_ug.user_id
    JOIN public.user_groups manager_ug ON agent_ug.group_id = manager_ug.group_id
    WHERE ta.id = public.evidence.task_assignment_id
      AND manager_ug.user_id = auth.uid()
  )
);

CREATE POLICY "Agents can manage evidence they uploaded"
ON public.evidence
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND auth.uid() = uploader_id
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND auth.uid() = uploader_id
);

CREATE POLICY "Agents can view evidence for their assigned tasks"
ON public.evidence
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND EXISTS (
    SELECT 1
    FROM public.task_assignments ta
    WHERE ta.id = public.evidence.task_assignment_id
      AND ta.agent_id = auth.uid()
  )
);

-- ================================
-- UPDATE USER MANAGEMENT SERVICE POLICIES
-- ================================

-- Update profiles policies for user management
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update group members" ON public.profiles;

CREATE POLICY "Admins can manage all profiles"
ON public.profiles
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Managers can update users in shared groups"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'manager'
  AND EXISTS (
    SELECT 1
    FROM public.user_groups ug1
    JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
    WHERE ug1.user_id = auth.uid()
      AND ug2.user_id = public.profiles.id
  )
);

-- ================================
-- VERIFICATION QUERIES
-- ================================

-- Test query: Show what users a manager can see
-- Replace 'MANAGER_ID' with actual manager UUID
/*
SELECT p.full_name, p.role, string_agg(g.name, ', ') as groups
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
WHERE EXISTS (
  SELECT 1
  FROM public.user_groups ug1
  JOIN public.user_groups ug2 ON ug1.group_id = ug2.group_id
  WHERE ug1.user_id = 'MANAGER_ID'  -- Replace with manager ID
    AND ug2.user_id = p.id
)
GROUP BY p.id, p.full_name, p.role
ORDER BY p.role, p.full_name;
*/

-- Test query: Show groups a manager belongs to
-- Replace 'MANAGER_ID' with actual manager UUID
/*
SELECT g.name, g.description
FROM public.groups g
JOIN public.user_groups ug ON g.id = ug.group_id
WHERE ug.user_id = 'MANAGER_ID'  -- Replace with manager ID
ORDER BY g.name;
*/

SELECT 'Group-based isolation policies created successfully!' as result;
SELECT 'Managers will now only see users, campaigns, and tasks within their assigned groups.' as info;