-- Check active_agents table schema
SELECT 'Active agents table columns:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'active_agents'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Sample data from active_agents
SELECT 'Active agents sample data:' as info;
SELECT * FROM active_agents LIMIT 5;