-- Check what location-related tables actually exist
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name LIKE '%location%'
ORDER BY table_name, ordinal_position;

-- Check if active_agents table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'active_agents';

-- Show all tables that might be location-related
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%location%' OR table_name LIKE '%agent%' OR table_name LIKE '%gps%')
ORDER BY table_name;
EOF < /dev/null