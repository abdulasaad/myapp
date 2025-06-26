# Manager Template Access Control - Database Setup

## Step 1: Clean up existing conflicting items (run this first)

```sql
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can manage all manager template access" ON manager_template_access;
DROP POLICY IF EXISTS "Managers can view their own template access" ON manager_template_access;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_manager_template_access_updated_at ON manager_template_access;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS update_manager_template_access_updated_at();

-- Drop existing table if it exists (this will remove all data - be careful!)
DROP TABLE IF EXISTS manager_template_access;
```

## Step 2: Create fresh manager_template_access table

```sql
-- Create manager_template_access table for controlling which template categories managers can access
CREATE TABLE manager_template_access (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    manager_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    template_categories TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one record per manager
    CONSTRAINT unique_manager_access UNIQUE (manager_id)
);

-- Enable RLS
ALTER TABLE manager_template_access ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Admins can manage all manager template access" ON manager_template_access
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Managers can view their own template access" ON manager_template_access
    FOR SELECT USING (
        manager_id = auth.uid() AND 
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'manager'
        )
    );

-- Create indexes for performance
CREATE INDEX idx_manager_template_access_manager_id ON manager_template_access(manager_id);
CREATE INDEX idx_manager_template_access_categories ON manager_template_access USING GIN(template_categories);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_manager_template_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trigger_update_manager_template_access_updated_at
    BEFORE UPDATE ON manager_template_access
    FOR EACH ROW
    EXECUTE FUNCTION update_manager_template_access_updated_at();
```

## Step 3: Verify table creation

```sql
-- Check if table was created successfully
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'manager_template_access' 
ORDER BY ordinal_position;

-- Check if policies were created
SELECT policyname, tablename 
FROM pg_policies 
WHERE tablename = 'manager_template_access';

-- Check if indexes were created
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename = 'manager_template_access';
```

---

## Instructions

1. **Run Step 1 first** (cleanup) - this will remove any conflicting items
2. **Run Step 2** (create fresh table) - this creates everything cleanly
3. **Run Step 3** (verify) - this confirms everything was created properly

After running these steps, the Manager Template Access screen will work with your existing templates!