-- Fix Evidence Table RLS Policies
-- Based on actual evidence table structure with uploader_id and task_assignment_id

-- ================================
-- EVIDENCE TABLE - Corrected Manager isolation
-- ================================

-- Enable RLS on evidence if not already enabled
ALTER TABLE public.evidence ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Managers can view group evidence" ON public.evidence;
DROP POLICY IF EXISTS "Agents can view own evidence" ON public.evidence;
DROP POLICY IF EXISTS "Admins can view all evidence" ON public.evidence;
DROP POLICY IF EXISTS "Managers can view evidence from their group agents" ON public.evidence;
DROP POLICY IF EXISTS "Agents can manage own evidence" ON public.evidence;
DROP POLICY IF EXISTS "Admins can manage all evidence" ON public.evidence;

-- Create corrected policies using actual column names

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
    -- Evidence submitted by agents in manager's groups
    -- Method 1: Check via uploader_id (if uploader is in manager's groups)
    SELECT 1
    FROM public.user_groups uploader_ug
    JOIN public.user_groups manager_ug ON uploader_ug.group_id = manager_ug.group_id
    WHERE uploader_ug.user_id = public.evidence.uploader_id
      AND manager_ug.user_id = auth.uid()
    
    UNION
    
    -- Method 2: Check via task assignment (if assigned agent is in manager's groups)
    SELECT 1
    FROM public.task_assignments ta
    JOIN public.user_groups agent_ug ON ta.agent_id = agent_ug.user_id
    JOIN public.user_groups manager_ug ON agent_ug.group_id = manager_ug.group_id
    WHERE ta.id = public.evidence.task_assignment_id
      AND manager_ug.user_id = auth.uid()
  )
);

CREATE POLICY "Agents can view evidence they uploaded"
ON public.evidence
FOR SELECT
TO authenticated
USING (
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

CREATE POLICY "Agents can upload evidence for their assigned tasks"
ON public.evidence
FOR INSERT
TO authenticated
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND EXISTS (
    SELECT 1
    FROM public.task_assignments ta
    WHERE ta.id = public.evidence.task_assignment_id
      AND ta.agent_id = auth.uid()
  )
);

CREATE POLICY "Agents can update their own evidence"
ON public.evidence
FOR UPDATE
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND auth.uid() = uploader_id
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  AND auth.uid() = uploader_id
);

-- ================================
-- VERIFICATION QUERY
-- ================================

-- Test what evidence a specific manager can see
-- Replace 'MANAGER_EMAIL' with actual manager email to test

/*
SELECT 
    e.id,
    e.title,
    e.status,
    e.created_at,
    uploader.full_name as uploader_name,
    agent.full_name as assigned_agent,
    t.title as task_title,
    string_agg(DISTINCT g.name, ', ') as shared_groups
FROM public.evidence e
JOIN public.profiles uploader ON e.uploader_id = uploader.id
LEFT JOIN public.task_assignments ta ON e.task_assignment_id = ta.id
LEFT JOIN public.profiles agent ON ta.agent_id = agent.id
LEFT JOIN public.tasks t ON ta.task_id = t.id
LEFT JOIN public.user_groups ug ON uploader.id = ug.user_id
LEFT JOIN public.groups g ON ug.group_id = g.id
WHERE EXISTS (
  -- Check if current manager shares groups with evidence uploader
  SELECT 1
  FROM public.profiles manager
  JOIN public.user_groups manager_ug ON manager.id = manager_ug.user_id
  JOIN public.user_groups uploader_ug ON manager_ug.group_id = uploader_ug.group_id
  WHERE manager.email = 'MANAGER_EMAIL'  -- Replace with actual email
    AND uploader_ug.user_id = e.uploader_id
)
GROUP BY e.id, e.title, e.status, e.created_at, uploader.full_name, agent.full_name, t.title
ORDER BY e.created_at DESC;
*/

SELECT 'Evidence table RLS policies fixed!' as result;
SELECT 'Policies now use uploader_id and task_assignment_id columns' as info;