-- Check all evidence in the database to verify what should show in evidence review

-- 1. Count all evidence by type
SELECT 
    CASE 
        WHEN task_assignment_id IS NOT NULL THEN 'Task Evidence'
        WHEN place_visit_id IS NOT NULL THEN 'Route Evidence' 
        ELSE 'Other Evidence'
    END as evidence_type,
    COUNT(*) as count,
    status
FROM evidence 
GROUP BY 
    CASE 
        WHEN task_assignment_id IS NOT NULL THEN 'Task Evidence'
        WHEN place_visit_id IS NOT NULL THEN 'Route Evidence' 
        ELSE 'Other Evidence'
    END,
    status
ORDER BY evidence_type, status;

-- 2. Show recent evidence with details
SELECT 
    e.id,
    e.title,
    e.status,
    e.created_at,
    e.task_assignment_id,
    e.place_visit_id,
    p.full_name as uploader_name
FROM evidence e
LEFT JOIN profiles p ON e.uploader_id = p.id
ORDER BY e.created_at DESC
LIMIT 10;

-- 3. Check route evidence specifically
SELECT 
    e.id,
    e.title,
    e.created_at,
    pv.place_id,
    pl.name as place_name,
    ra.route_id,
    r.name as route_name,
    prof.full_name as agent_name
FROM evidence e
JOIN place_visits pv ON e.place_visit_id = pv.id
LEFT JOIN places pl ON pv.place_id = pl.id
LEFT JOIN route_assignments ra ON pv.route_assignment_id = ra.id
LEFT JOIN routes r ON ra.route_id = r.id
LEFT JOIN profiles prof ON pv.agent_id = prof.id
ORDER BY e.created_at DESC;