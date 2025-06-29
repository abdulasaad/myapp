-- Check the location_history table schema and defaults

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'location_history'
ORDER BY ordinal_position;