-- Enable PostGIS extension in Supabase
-- Run this in your Supabase SQL Editor

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verify PostGIS is enabled
SELECT postgis_version();

-- Update the geofences table to use proper GEOMETRY type
-- First, let's see what type the area column currently has
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'geofences' AND column_name = 'area';

-- If the area column is TEXT, we need to convert it to GEOMETRY
-- This will only work if PostGIS is enabled
-- ALTER TABLE geofences ALTER COLUMN area TYPE GEOMETRY USING ST_GeomFromText(area, 4326);

-- Add a spatial index for better performance
-- CREATE INDEX IF NOT EXISTS idx_geofences_area_gist ON geofences USING GIST (area);