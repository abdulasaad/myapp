-- Create manager_template_access table for controlling which template categories managers can access

CREATE TABLE IF NOT EXISTS manager_template_access (
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

-- RLS Policies
-- Admins can manage all manager template access
CREATE POLICY "Admins can manage all manager template access" ON manager_template_access
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Managers can view their own template access
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

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_manager_template_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_manager_template_access_updated_at
    BEFORE UPDATE ON manager_template_access
    FOR EACH ROW
    EXECUTE FUNCTION update_manager_template_access_updated_at();

-- Insert default template access for existing managers (all categories by default)
INSERT INTO manager_template_access (manager_id, template_categories)
SELECT 
    id,
    ARRAY['Data Collection', 'Location Tasks', 'Inspections', 'Customer Service', 'Operations']
FROM profiles 
WHERE role = 'manager'
ON CONFLICT (manager_id) DO NOTHING;