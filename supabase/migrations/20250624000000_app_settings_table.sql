-- Create app_settings table for admin-configurable application settings
CREATE TABLE public.app_settings (
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
COMMENT ON COLUMN public.app_settings.setting_key IS 'Unique identifier for the setting';
COMMENT ON COLUMN public.app_settings.setting_value IS 'The actual setting value stored as text';
COMMENT ON COLUMN public.app_settings.setting_type IS 'Data type of the setting for validation';
COMMENT ON COLUMN public.app_settings.min_value IS 'Minimum allowed value for numeric settings';
COMMENT ON COLUMN public.app_settings.max_value IS 'Maximum allowed value for numeric settings';

-- Enable RLS for the app_settings table
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only admins can manage app settings
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
CREATE TRIGGER app_settings_update_trigger
    BEFORE UPDATE ON public.app_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_app_settings_updated_at();

-- Insert default GPS tracking settings
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description, min_value, max_value) VALUES
('gps_ping_interval', '30', 'number', 'GPS location ping interval in seconds', 10, 300),
('gps_accuracy_threshold', '75', 'number', 'Maximum acceptable GPS accuracy in meters', 10, 200),
('gps_distance_filter', '10', 'number', 'Minimum distance in meters before location update', 5, 100),
('gps_timeout', '30', 'number', 'GPS request timeout in seconds', 10, 60),
('gps_accuracy_level', 'medium', 'string', 'GPS accuracy level: low, medium, high, best', NULL, NULL),
('gps_speed_threshold', '1.0', 'number', 'Minimum speed in m/s to consider as movement', 0.1, 5.0),
('gps_angle_threshold', '15', 'number', 'Minimum angle change in degrees to update direction', 5, 45),
('background_accuracy_threshold', '100', 'number', 'Background service GPS accuracy threshold in meters', 10, 200);

-- Create index for faster lookups
CREATE INDEX idx_app_settings_key ON public.app_settings(setting_key);
CREATE INDEX idx_app_settings_updated_at ON public.app_settings(updated_at);