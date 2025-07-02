-- Check evidence status and counts
-- This will help diagnose why evidence count shows 0/1

-- 1. Check all evidence records with their status
SELECT 
    e.id,
    e.title,
    e.status,
    e.place_visit_id,
    e.created_at,
    e.file_url,
    pv.place_id,
    p.name as place_name,
    pv.agent_id,
    pr.full_name as agent_name
FROM evidence e
LEFT JOIN place_visits pv ON e.place_visit_id = pv.id
LEFT JOIN places p ON pv.place_id = p.id
LEFT JOIN profiles pr ON pv.agent_id = pr.id
ORDER BY e.created_at DESC
LIMIT 20;

-- 2. Check evidence status distribution
SELECT 
    status, 
    COUNT(*) as count
FROM evidence
GROUP BY status;

-- 3. Check place visits with evidence counts
SELECT 
    pv.id as visit_id,
    p.name as place_name,
    pv.status as visit_status,
    pv.checked_in_at,
    pr.full_name as agent_name,
    COUNT(e.id) as total_evidence_count,
    COUNT(CASE WHEN e.status = 'approved' THEN 1 END) as approved_evidence_count,
    COUNT(CASE WHEN e.status = 'pending' THEN 1 END) as pending_evidence_count,
    COUNT(CASE WHEN e.status = 'rejected' THEN 1 END) as rejected_evidence_count
FROM place_visits pv
LEFT JOIN places p ON pv.place_id = p.id
LEFT JOIN profiles pr ON pv.agent_id = pr.id
LEFT JOIN evidence e ON e.place_visit_id = pv.id
WHERE pv.status IN ('checked_in', 'completed')
GROUP BY pv.id, p.name, pv.status, pv.checked_in_at, pr.full_name
ORDER BY pv.checked_in_at DESC;

-- 4. Check if evidence has place_visit_id properly linked
SELECT 
    COUNT(*) as evidence_without_visit_id
FROM evidence
WHERE place_visit_id IS NULL;

-- 5. Check latest evidence records to see their data
SELECT 
    id,
    title,
    description,
    status,
    file_url,
    file_type,
    place_visit_id,
    task_id,
    campaign_id,
    created_at,
    created_by
FROM evidence
ORDER BY created_at DESC
LIMIT 10;

-- 6. Check active place visits without evidence
SELECT 
    pv.id as visit_id,
    p.name as place_name,
    pr.full_name as agent_name,
    pv.checked_in_at,
    rp.required_evidence_count
FROM place_visits pv
JOIN places p ON pv.place_id = p.id
JOIN profiles pr ON pv.agent_id = pr.id
JOIN route_assignments ra ON pv.route_assignment_id = ra.id
JOIN route_places rp ON rp.route_id = ra.route_id AND rp.place_id = pv.place_id
WHERE pv.status = 'checked_in'
AND NOT EXISTS (
    SELECT 1 FROM evidence e WHERE e.place_visit_id = pv.id
);