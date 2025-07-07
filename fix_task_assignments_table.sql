-- Fix task_assignments table by adding missing created_at column

-- 1. Check current structure of task_assignments table
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'task_assignments'
ORDER BY ordinal_position;

-- 2. Add created_at column if it doesn't exist
ALTER TABLE task_assignments 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Update any existing rows that might have NULL created_at
UPDATE task_assignments 
SET created_at = COALESCE(created_at, NOW())
WHERE created_at IS NULL;

-- 4. Verify the column was added
SELECT 
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'task_assignments'
AND column_name = 'created_at';