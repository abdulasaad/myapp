# SQL Migration Commands

## Evidence Task System Enhancements

### 1. Update Evidence Table Structure

```sql
-- Add new columns to evidence table for approval workflow and metadata
ALTER TABLE public.evidence 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS captured_at TIMESTAMPTZ DEFAULT now(),
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS accuracy DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS mime_type TEXT,
ADD COLUMN IF NOT EXISTS file_size INTEGER;

-- Add check constraint for status
ALTER TABLE public.evidence 
ADD CONSTRAINT evidence_status_check 
CHECK (status IN ('pending', 'approved', 'rejected'));

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_evidence_status ON public.evidence(status);
CREATE INDEX IF NOT EXISTS idx_evidence_reviewed_at ON public.evidence(reviewed_at);
```

### 2. Create Task Geofence Validation Function

```sql
-- Function to check if an agent is within a task's geofence
-- Note: Execute this function creation in multiple steps if needed
CREATE OR REPLACE FUNCTION check_agent_in_task_geofence(
    p_agent_id UUID,
    p_task_id UUID,
    p_agent_lat DOUBLE PRECISION,
    p_agent_lng DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE
    task_enforce_geofence BOOLEAN;
    agent_point GEOMETRY;
    geofence_geometry GEOMETRY;
    is_inside BOOLEAN := FALSE;
BEGIN
    SELECT enforce_geofence INTO task_enforce_geofence
    FROM tasks
    WHERE id = p_task_id;
    
    IF task_enforce_geofence IS NULL OR task_enforce_geofence = FALSE THEN
        RETURN TRUE;
    END IF;
    
    agent_point := ST_SetSRID(ST_MakePoint(p_agent_lng, p_agent_lat), 4326);
    
    SELECT area INTO geofence_geometry
    FROM geofences
    WHERE task_id = p_task_id
    LIMIT 1;
    
    IF geofence_geometry IS NULL THEN
        RETURN TRUE;
    END IF;
    
    SELECT ST_Within(agent_point, geofence_geometry) INTO is_inside;
    
    RETURN COALESCE(is_inside, FALSE);
END
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_agent_in_task_geofence(UUID, UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
```

### 3. Create Batch Progress Query Function

```sql
-- Batch function to get all agent progress for a specific task
CREATE OR REPLACE FUNCTION get_task_agent_progress_batch(p_task_id UUID)
RETURNS TABLE (
    agent_id UUID,
    agent_name TEXT,
    assignment_status TEXT,
    evidence_required INTEGER,
    evidence_uploaded INTEGER,
    points_total INTEGER,
    points_paid INTEGER,
    outstanding_balance INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS '
BEGIN
    RETURN QUERY
    SELECT 
        ta.agent_id,
        p.full_name as agent_name,
        ta.status as assignment_status,
        COALESCE(t.required_evidence_count, 1) as evidence_required,
        (
            SELECT COUNT(*)::INTEGER 
            FROM evidence e 
            WHERE e.task_assignment_id = ta.id
            AND e.status = ''approved''
        ) as evidence_uploaded,
        COALESCE(t.points, 0) as points_total,
        COALESCE(
            (
                SELECT SUM(amount)::INTEGER 
                FROM payments pay 
                WHERE pay.agent_id = ta.agent_id 
                AND pay.task_id = p_task_id
            ), 
            0
        ) as points_paid,
        CASE 
            WHEN ta.status = ''completed'' THEN 
                GREATEST(
                    0, 
                    COALESCE(t.points, 0) - COALESCE(
                        (
                            SELECT SUM(amount)::INTEGER 
                            FROM payments pay 
                            WHERE pay.agent_id = ta.agent_id 
                            AND pay.task_id = p_task_id
                        ), 
                        0
                    )
                )
            ELSE 0
        END as outstanding_balance
    FROM task_assignments ta
    JOIN profiles p ON ta.agent_id = p.id
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.task_id = p_task_id
    ORDER BY p.full_name;
END;
';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_task_agent_progress_batch(UUID) TO authenticated;
```

### 4. Add Missing Geofences Table Column

```sql
-- Add task_id column to geofences table if it doesn't exist
ALTER TABLE public.geofences 
ADD COLUMN IF NOT EXISTS task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE;

-- Add area_text column to store WKT as plain text (workaround for PostGIS issues)
ALTER TABLE public.geofences 
ADD COLUMN IF NOT EXISTS area_text TEXT;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_geofences_task_id ON public.geofences(task_id);
```

### 5. Update Payments Table

```sql
-- Add task_id column to payments table for task-specific payments
ALTER TABLE public.payments 
ADD COLUMN IF NOT EXISTS task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS paid_by_manager_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'task_completion',
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_payments_task_id ON public.payments(task_id);
```

## GPS Tracking Settings Table Migration (Previous)

```sql
-- Create app_settings table for admin-configurable application settings
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    setting_key TEXT NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    setting_type TEXT NOT NULL DEFAULT 'string', -- string, number, boolean, json
    description TEXT,
    min_value NUMERIC, -- For numeric settings validation
    max_value NUMERIC, -- For numeric settings validation
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.app_settings IS 'Application settings configurable by admin users only';

-- Enable RLS for the app_settings table
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only admins can manage app settings
DROP POLICY IF EXISTS "Admins only can manage app settings" ON public.app_settings;
CREATE POLICY "Admins only can manage app settings"
ON public.app_settings
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

-- RLS Policy: All authenticated users can read settings (needed for app functionality)
DROP POLICY IF EXISTS "Authenticated users can read app settings" ON public.app_settings;
CREATE POLICY "Authenticated users can read app settings"
ON public.app_settings
FOR SELECT
TO authenticated
USING (true);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_app_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    NEW.updated_by = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically update timestamp and user
DROP TRIGGER IF EXISTS app_settings_update_trigger ON public.app_settings;
CREATE TRIGGER app_settings_update_trigger
    BEFORE UPDATE ON public.app_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_app_settings_updated_at();

-- Insert default GPS tracking settings (only if they don't exist)
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description, min_value, max_value) 
SELECT setting_key, setting_value, setting_type, description, min_value, max_value
FROM (VALUES
('gps_ping_interval', '30', 'number', 'GPS location ping interval in seconds', 10, 300),
('gps_accuracy_threshold', '75', 'number', 'Maximum acceptable GPS accuracy in meters', 10, 200),
('gps_distance_filter', '10', 'number', 'Minimum distance in meters before location update', 5, 100),
('gps_timeout', '30', 'number', 'GPS request timeout in seconds', 10, 60),
('gps_accuracy_level', 'medium', 'string', 'GPS accuracy level: low, medium, high, best', NULL, NULL),
('gps_speed_threshold', '1.0', 'number', 'Minimum speed in m/s to consider as movement', 0.1, 5.0),
('gps_angle_threshold', '15', 'number', 'Minimum angle change in degrees to update direction', 5, 45),
('background_accuracy_threshold', '100', 'number', 'Background service GPS accuracy threshold in meters', 10, 200)
) AS v(setting_key, setting_value, setting_type, description, min_value, max_value)
WHERE NOT EXISTS (
    SELECT 1 FROM public.app_settings WHERE app_settings.setting_key = v.setting_key
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_settings_key ON public.app_settings(setting_key);
CREATE INDEX IF NOT EXISTS idx_app_settings_updated_at ON public.app_settings(updated_at);
```