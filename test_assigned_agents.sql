-- Test query to debug assigned agents display issue

-- 1. Get the latest route ID that has assigned agents
SELECT 
    r.id as route_id,
    r.name as route_name,
    r.status as route_status,
    COUNT(ra.id) as assignments_count
FROM routes r
LEFT JOIN route_assignments ra ON r.id = ra.route_id
WHERE ra.id IS NOT NULL
GROUP BY r.id, r.name, r.status
ORDER BY r.created_at DESC
LIMIT 1;

-- 2. Test the exact query structure used in Flutter for that route
-- Replace 'ROUTE_ID_HERE' with the route ID from query 1
WITH target_route AS (
    SELECT id FROM routes WHERE name = 'test route' LIMIT 1
)
SELECT 
    ra.id, 
    ra.status, 
    ra.assigned_at, 
    ra.started_at, 
    ra.completed_at,
    ra.agent_id
FROM route_assignments ra
WHERE ra.route_id = (SELECT id FROM target_route)
ORDER BY ra.assigned_at DESC;

-- 3. Test profile lookup for each agent
WITH target_route AS (
    SELECT id FROM routes WHERE name = 'test route' LIMIT 1
)
SELECT 
    ra.agent_id,
    p.id as profile_id,
    p.full_name,
    p.email,
    ra.status as assignment_status
FROM route_assignments ra
LEFT JOIN profiles p ON p.id = ra.agent_id
WHERE ra.route_id = (SELECT id FROM target_route);

-- 4. Check if there are any orphaned assignments
SELECT 
    ra.*,
    CASE 
        WHEN r.id IS NULL THEN 'ROUTE NOT FOUND'
        WHEN p.id IS NULL THEN 'PROFILE NOT FOUND'
        ELSE 'OK'
    END as data_status
FROM route_assignments ra
LEFT JOIN routes r ON ra.route_id = r.id
LEFT JOIN profiles p ON ra.agent_id = p.id
WHERE r.id IS NULL OR p.id IS NULL;