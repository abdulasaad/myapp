-- Make task_assignment_id nullable to support standalone evidence uploads
-- This allows agents to upload evidence without being tied to specific tasks

-- Step 1: Make task_assignment_id nullable
ALTER TABLE evidence 
ALTER COLUMN task_assignment_id DROP NOT NULL;

-- Step 2: Add description column for standalone uploads
ALTER TABLE evidence 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Step 3: Create index for efficient standalone evidence queries
CREATE INDEX IF NOT EXISTS idx_evidence_standalone 
ON evidence (uploader_id, created_at) 
WHERE task_assignment_id IS NULL;

-- Step 4: Create index for filtering standalone vs task-based evidence
CREATE INDEX IF NOT EXISTS idx_evidence_type 
ON evidence (task_assignment_id, status, created_at);

-- Step 5: Update RLS policies to handle standalone uploads
-- Update the existing policy to allow agents to insert standalone evidence

-- First drop the existing policy
DROP POLICY IF EXISTS "Users can insert evidence for their task assignments" ON evidence;

-- Create new policy that handles both task-based and standalone evidence
CREATE POLICY "Users can insert evidence for assignments and standalone uploads" ON evidence
FOR INSERT
WITH CHECK (
  -- For task-based evidence: user must be assigned to the task
  (task_assignment_id IS NOT NULL AND 
   EXISTS (
     SELECT 1 FROM task_assignments ta 
     WHERE ta.id = task_assignment_id 
     AND ta.agent_id = auth.uid()
   ))
  OR
  -- For standalone evidence: user must be the uploader
  (task_assignment_id IS NULL AND uploader_id = auth.uid())
);

-- Update the SELECT policy to handle standalone evidence
DROP POLICY IF EXISTS "Users can view evidence for their assignments" ON evidence;

CREATE POLICY "Users can view evidence for assignments and standalone uploads" ON evidence
FOR SELECT
USING (
  -- Agents can see their own evidence (both task-based and standalone)
  uploader_id = auth.uid()
  OR
  -- Agents can see evidence for tasks they're assigned to
  (task_assignment_id IS NOT NULL AND 
   EXISTS (
     SELECT 1 FROM task_assignments ta 
     WHERE ta.id = task_assignment_id 
     AND ta.agent_id = auth.uid()
   ))
  OR
  -- Managers/admins can see evidence from agents in their groups
  EXISTS (
    SELECT 1 FROM user_groups ug
    WHERE ug.user_id = auth.uid()
    AND ug.group_id IN (
      SELECT ug2.group_id 
      FROM user_groups ug2 
      WHERE ug2.user_id = evidence.uploader_id
    )
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  OR
  -- Admins can see all evidence
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
);

-- Update the UPDATE policy for evidence reviews
DROP POLICY IF EXISTS "Managers can update evidence status for their group agents" ON evidence;

CREATE POLICY "Managers can update evidence status for their group agents" ON evidence
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM user_groups ug
    WHERE ug.user_id = auth.uid()
    AND ug.group_id IN (
      SELECT ug2.group_id 
      FROM user_groups ug2 
      WHERE ug2.user_id = evidence.uploader_id
    )
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  OR
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
);

-- Add helpful comments
COMMENT ON COLUMN evidence.task_assignment_id IS 'NULL for standalone uploads, links to task_assignments for task-based evidence';
COMMENT ON COLUMN evidence.description IS 'Optional description for standalone uploads or additional context';
COMMENT ON INDEX idx_evidence_standalone IS 'Optimizes queries for standalone evidence uploads';

-- Verify the changes
SELECT 
  column_name, 
  is_nullable, 
  data_type 
FROM information_schema.columns 
WHERE table_name = 'evidence' 
  AND table_schema = 'public' 
  AND column_name IN ('task_assignment_id', 'description');