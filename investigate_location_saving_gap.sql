-- Investigate why location data stopped being saved after July 8th

-- ====================================================================
-- 1. Check the gap between live map and location history
-- ====================================================================
SELECT 
    'Live Map (active_agents)' as source,
    COUNT(*) as agent_count,
    user_id,
    last_seen,
    EXTRACT(EPOCH FROM (NOW() - last_seen))/3600 as hours_ago,
    connection_status
FROM active_agents
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
GROUP BY user_id, last_seen, connection_status

UNION ALL

SELECT 
    'Location History' as source,
    COUNT(*) as entry_count,
    user_id,
    MAX(recorded_at) as last_entry,
    EXTRACT(EPOCH FROM (NOW() - MAX(recorded_at)))/3600 as hours_ago,
    'N/A' as connection_status
FROM location_history
WHERE user_id = '263e832c-f73c-48f3-bfd2-1b567cbff0b1'
GROUP BY user_id;

-- ====================================================================
-- 2. Check if the insert_location_update RPC function exists
-- ====================================================================
SELECT 
    p.proname as function_name,
    p.proargnames as parameter_names,
    n.nspname as schema_name,
    'Function exists' as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'insert_location_update'
AND n.nspname = 'public';

-- ====================================================================
-- 3. Check for any location insertions in the last 24 hours
-- ====================================================================
SELECT 
    'Recent inserts (24h)' as check_type,
    COUNT(*) as insert_count,
    MAX(recorded_at) as latest_insert,
    MIN(recorded_at) as earliest_insert
FROM location_history
WHERE recorded_at >= NOW() - INTERVAL '24 hours';

-- ====================================================================
-- 4. Check for any location insertions today
-- ====================================================================
SELECT 
    'Today inserts' as check_type,
    COUNT(*) as insert_count,
    MAX(recorded_at) as latest_insert,
    array_agg(DISTINCT user_id) as user_ids
FROM location_history
WHERE DATE(recorded_at) = CURRENT_DATE;

-- ====================================================================
-- 5. Check all agents' last location entries
-- ====================================================================
SELECT 
    p.full_name,
    p.email,
    p.role,
    lh.max_recorded as last_location_entry,
    EXTRACT(EPOCH FROM (NOW() - lh.max_recorded))/24 as days_ago,
    aa.last_seen as live_map_entry,
    EXTRACT(EPOCH FROM (NOW() - aa.last_seen))/24 as live_days_ago
FROM profiles p
LEFT JOIN (
    SELECT 
        user_id, 
        MAX(recorded_at) as max_recorded
    FROM location_history 
    GROUP BY user_id
) lh ON lh.user_id = p.id
LEFT JOIN active_agents aa ON aa.user_id = p.id
WHERE p.role = 'agent'
ORDER BY lh.max_recorded DESC NULLS LAST;

-- ====================================================================
-- 6. Check if there are any errors in function execution
-- ====================================================================
-- Test the insert function manually
-- SELECT public.insert_location_update(
--     '263e832c-f73c-48f3-bfd2-1b567cbff0b1'::uuid,
--     'POINT(-122.083922 37.4220936)',
--     600.0,
--     0.0
-- );

-- ====================================================================
-- 7. Check for any table locks or permission issues
-- ====================================================================
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasinserts,
    hasselects,
    hasupdates,
    hasdeletes
FROM pg_tables
WHERE tablename = 'location_history';

-- ====================================================================
-- 8. Check table size and recent activity
-- ====================================================================
SELECT 
    schemaname,
    tablename,
    n_tup_ins as total_inserts,
    n_tup_upd as total_updates,
    n_tup_del as total_deletes,
    last_autovacuum,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE tablename = 'location_history';