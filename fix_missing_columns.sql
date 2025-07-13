
-- Add missing updated_at column to task_assignments if it doesn't exist
ALTER TABLE task_assignments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add missing updated_at column to touring_task_assignments if it doesn't exist  
ALTER TABLE touring_task_assignments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have proper timestamps
UPDATE task_assignments 
SET updated_at = created_at 
WHERE updated_at IS NULL;

UPDATE touring_task_assignments 
SET updated_at = assigned_at 
WHERE updated_at IS NULL;

