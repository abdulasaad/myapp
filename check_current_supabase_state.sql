-- Check current state of Supabase database for route management system
-- This will help understand what tables exist and their structure

-- 1. Check if places table exists and its structure
SELECT 'PLACES TABLE STRUCTURE:' as info;
\d places;

-- Show sample places data
SELECT 'SAMPLE PLACES DATA:' as info;
SELECT id, name, description, address, latitude, longitude, status, created_at 
FROM places 
LIMIT 5;

-- 2. Check if routes table exists and its structure  
SELECT 'ROUTES TABLE STRUCTURE:' as info;
\d routes;

-- Show sample routes data
SELECT 'SAMPLE ROUTES DATA:' as info;
SELECT id, name, description, status, created_by, created_at 
FROM routes 
LIMIT 5;

-- 3. Check if route_places table exists (route-place mapping)
SELECT 'ROUTE_PLACES TABLE STRUCTURE:' as info;
\d route_places;

-- Show sample route_places data
SELECT 'SAMPLE ROUTE_PLACES DATA:' as info;
SELECT rp.id, rp.route_id, rp.place_id, rp.visit_order, rp.estimated_duration_minutes, 
       r.name as route_name, p.name as place_name
FROM route_places rp 
LEFT JOIN routes r ON rp.route_id = r.id
LEFT JOIN places p ON rp.place_id = p.id
LIMIT 5;

-- 4. Check if route_assignments table exists (agent assignments)
SELECT 'ROUTE_ASSIGNMENTS TABLE STRUCTURE:' as info;
\d route_assignments;

-- Show sample route assignments
SELECT 'SAMPLE ROUTE_ASSIGNMENTS DATA:' as info;
SELECT ra.id, ra.route_id, ra.agent_id, ra.status, ra.assigned_at,
       r.name as route_name, pr.full_name as agent_name
FROM route_assignments ra
LEFT JOIN routes r ON ra.route_id = r.id  
LEFT JOIN profiles pr ON ra.agent_id = pr.id
LIMIT 5;

-- 5. Check if place_visits table exists (actual visits)
SELECT 'PLACE_VISITS TABLE STRUCTURE:' as info;
\d place_visits;

-- Show sample place visits
SELECT 'SAMPLE PLACE_VISITS DATA:' as info;
SELECT pv.id, pv.route_assignment_id, pv.place_id, pv.agent_id, 
       pv.checked_in_at, pv.checked_out_at, pv.status,
       p.name as place_name, pr.full_name as agent_name
FROM place_visits pv
LEFT JOIN places p ON pv.place_id = p.id
LEFT JOIN profiles pr ON pv.agent_id = pr.id
LIMIT 5;

-- 6. Check if evidence table exists (file uploads)
SELECT 'EVIDENCE TABLE STRUCTURE:' as info;
\d evidence;

-- Show sample evidence data
SELECT 'SAMPLE EVIDENCE DATA:' as info;
SELECT e.id, e.place_visit_id, e.route_assignment_id, e.title, e.file_url, e.status,
       e.uploader_id, e.created_at
FROM evidence e
LIMIT 5;

-- 7. Check user profiles and roles
SELECT 'USER PROFILES AND ROLES:' as info;
SELECT id, full_name, email, role, created_at
FROM profiles
WHERE role IN ('manager', 'agent')
LIMIT 10;

-- 8. Check table counts
SELECT 'TABLE COUNTS:' as info;
SELECT 
  (SELECT COUNT(*) FROM places) as places_count,
  (SELECT COUNT(*) FROM routes) as routes_count,
  (SELECT COUNT(*) FROM route_places) as route_places_count,
  (SELECT COUNT(*) FROM route_assignments) as route_assignments_count,
  (SELECT COUNT(*) FROM place_visits) as place_visits_count,
  (SELECT COUNT(*) FROM evidence) as evidence_count,
  (SELECT COUNT(*) FROM profiles WHERE role = 'manager') as managers_count,
  (SELECT COUNT(*) FROM profiles WHERE role = 'agent') as agents_count;

-- 9. Check if we have any active routes with assignments
SELECT 'ACTIVE ROUTES WITH ASSIGNMENTS:' as info;
SELECT r.id, r.name, r.status, 
       COUNT(ra.id) as assigned_agents,
       COUNT(CASE WHEN ra.status = 'completed' THEN 1 END) as completed_assignments
FROM routes r
LEFT JOIN route_assignments ra ON r.id = ra.route_id
WHERE r.status = 'active'
GROUP BY r.id, r.name, r.status
LIMIT 10;