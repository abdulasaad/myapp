-- Add assigned_manager_id column to tasks table
ALTER TABLE tasks 
ADD COLUMN assigned_manager_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Add assigned_manager_id column to campaigns table  
ALTER TABLE campaigns
ADD COLUMN assigned_manager_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Create index for better query performance
CREATE INDEX idx_tasks_assigned_manager ON tasks(assigned_manager_id);
CREATE INDEX idx_campaigns_assigned_manager ON campaigns(assigned_manager_id);

-- Add RLS policies to ensure proper access control
-- Policy for tasks: Admin can see all, managers can see tasks assigned to them or created by users in their groups
CREATE POLICY "tasks_assigned_manager_access" ON tasks
FOR SELECT USING (
  auth.uid() IN (
    SELECT id FROM profiles WHERE role = 'admin'
  ) OR
  assigned_manager_id = auth.uid() OR
  created_by = auth.uid() OR
  id IN (
    SELECT t.id FROM tasks t
    JOIN task_assignments ta ON t.id = ta.task_id
    WHERE ta.agent_id = auth.uid()
  )
);

-- Policy for campaigns: Admin can see all, managers can see campaigns assigned to them or created by users in their groups
CREATE POLICY "campaigns_assigned_manager_access" ON campaigns
FOR SELECT USING (
  auth.uid() IN (
    SELECT id FROM profiles WHERE role = 'admin'
  ) OR
  assigned_manager_id = auth.uid() OR
  created_by = auth.uid() OR
  id IN (
    SELECT c.id FROM campaigns c
    JOIN campaign_agents ca ON c.id = ca.campaign_id
    WHERE ca.agent_id = auth.uid()
  )
);