-- Create app_versions table for managing app updates
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  version_code INTEGER NOT NULL,
  version_name TEXT NOT NULL,
  minimum_version_code INTEGER NOT NULL,
  download_url TEXT NOT NULL,
  file_size_mb FLOAT,
  release_notes TEXT,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for faster queries
CREATE INDEX idx_app_versions_platform_active ON app_versions(platform, is_active);

-- Enable RLS
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all authenticated users to read app versions
CREATE POLICY "Anyone can read app versions" ON app_versions
  FOR SELECT
  USING (true);

-- Create policy to allow only admins to insert/update/delete app versions
CREATE POLICY "Only admins can manage app versions" ON app_versions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Insert sample data (replace with your actual values)
-- INSERT INTO app_versions (version_code, version_name, minimum_version_code, download_url, file_size_mb, release_notes, platform)
-- VALUES 
-- (2, '1.0.1', 2, 'https://your-supabase-url/storage/v1/object/public/app-releases/al-tijwal-v1.0.1.apk', 25.5, 
--  'Bug fixes and performance improvements', 'android');

-- Create storage bucket for app releases
-- This needs to be done via Supabase Dashboard:
-- 1. Go to Storage section
-- 2. Create new bucket named 'app-releases'
-- 3. Set it to public
-- 4. Upload your APK/IPA files there